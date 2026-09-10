"""Unit tests for the package catalog resolver.

Run from ansible/: python -m unittest tests.test_catalog
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "filter_plugins"))

from catalog import (  # noqa: E402
    CatalogError,
    mise_install_tools,
    mise_use_specs,
    resolve_catalog,
)


def resolve(apps, catalog, target_os="arch", default_provider="pacman"):
    return resolve_catalog(apps, catalog, target_os, default_provider)


class ResolveCatalogTests(unittest.TestCase):
    def test_all_key_installs_on_every_os(self):
        catalog = {
            "bat": {"all": {"provider": "mise", "packages": ["bat@0.26.1"]}},
        }
        for os_name, default in (("arch", "pacman"), ("darwin", "brew")):
            resolved = resolve(["bat"], catalog, os_name, default)
            self.assertEqual(resolved["packages"], {"mise": ["bat@0.26.1"]})

    def test_all_unions_with_os_specific_block(self):
        catalog = {
            "python": {
                "all": {
                    "provider": "mise",
                    "packages": ["python@3.14.7", "uv@0.12.3"],
                },
                "arch": {"provider": "pacman", "packages": ["python", "python-gpgme"]},
                "darwin": {"provider": "brew", "packages": ["python"]},
            }
        }
        arch = resolve(["python"], catalog, "arch", "pacman")
        self.assertEqual(
            arch["packages"],
            {
                "mise": ["python@3.14.7", "uv@0.12.3"],
                "pacman": ["python", "python-gpgme"],
            },
        )
        darwin = resolve(["python"], catalog, "darwin", "brew")
        self.assertEqual(
            darwin["packages"],
            {
                "mise": ["python@3.14.7", "uv@0.12.3"],
                "brew": ["python"],
            },
        )

    def test_os_only_entry_skipped_on_other_os(self):
        catalog = {
            "pacseek": {"arch": {"provider": "aur", "packages": ["pacseek"]}},
        }
        self.assertEqual(resolve(["pacseek"], catalog, "darwin", "brew")["packages"], {})
        self.assertEqual(
            resolve(["pacseek"], catalog, "arch", "pacman")["packages"],
            {"aur": ["pacseek"]},
        )

    def test_mise_requires_pinned_version(self):
        catalog = {"bat": {"all": {"provider": "mise", "packages": ["bat"]}}}
        with self.assertRaises(CatalogError) as ctx:
            resolve(["bat"], catalog)
        self.assertIn("tool@version", str(ctx.exception))

    def test_mise_accepts_latest(self):
        catalog = {
            "claude-code": {
                "all": {"provider": "mise", "packages": ["claude-code@latest"]}
            }
        }
        resolved = resolve(["claude-code"], catalog)
        self.assertEqual(resolved["packages"], {"mise": ["claude-code@latest"]})

    def test_mise_accepts_backend_prefix_and_exe(self):
        catalog = {
            "beads": {
                "all": {
                    "provider": "mise",
                    "packages": ["ubi:steveyegge/beads[exe=bd]@1.2.3"],
                }
            }
        }
        resolved = resolve(["beads"], catalog)
        self.assertEqual(
            resolved["packages"],
            {"mise": ["ubi:steveyegge/beads[exe=bd]@1.2.3"]},
        )

    def test_duplicate_mise_blocks_after_union_fail(self):
        catalog = {
            "bat": {
                "all": {"provider": "mise", "packages": ["bat@0.26.1"]},
                "arch": {"provider": "mise", "packages": ["bat@0.25.0"]},
            }
        }
        with self.assertRaises(CatalogError) as ctx:
            resolve(["bat"], catalog, "arch", "pacman")
        self.assertIn("more than once", str(ctx.exception))

    def test_unknown_app_fails(self):
        with self.assertRaises(CatalogError) as ctx:
            resolve(["nope"], {})
        self.assertIn("no entry in package_catalog", str(ctx.exception))

    def test_invalid_provider_fails(self):
        catalog = {"foo": {"arch": {"provider": "flatpak", "packages": ["foo"]}}}
        with self.assertRaises(CatalogError) as ctx:
            resolve(["foo"], catalog)
        self.assertIn("invalid provider", str(ctx.exception))

    def test_taps_still_collected_for_brew(self):
        catalog = {
            "fresh-editor": {
                "darwin": {
                    "provider": "brew",
                    "packages": ["fresh-editor"],
                    "taps": ["sinelaw/fresh"],
                }
            }
        }
        resolved = resolve(["fresh-editor"], catalog, "darwin", "brew")
        self.assertEqual(resolved["packages"], {"brew": ["fresh-editor"]})
        self.assertEqual(resolved["taps"], {"brew": ["sinelaw/fresh"]})

    def test_mise_default_provider_is_valid(self):
        # default_provider is still validated against VALID_PROVIDERS even
        # though it is not used for fall-through.
        catalog = {"bat": {"all": {"provider": "mise", "packages": ["bat@0.26.1"]}}}
        resolved = resolve(["bat"], catalog, "arch", "mise")
        self.assertEqual(resolved["packages"], {"mise": ["bat@0.26.1"]})

    def test_all_key_uv_installs_on_every_os(self):
        catalog = {
            "linecast": {"all": {"provider": "uv", "packages": ["linecast"]}},
        }
        for os_name, default in (("arch", "pacman"), ("darwin", "brew")):
            resolved = resolve(["linecast"], catalog, os_name, default)
            self.assertEqual(resolved["packages"], {"uv": ["linecast"]})

    def test_uv_allows_unpinned_and_versioned_specs(self):
        catalog = {
            "linecast": {"all": {"provider": "uv", "packages": ["linecast"]}},
            "ruff": {"all": {"provider": "uv", "packages": ["ruff==0.6.0"]}},
        }
        resolved = resolve(["linecast", "ruff"], catalog)
        self.assertEqual(
            resolved["packages"],
            {"uv": ["linecast", "ruff==0.6.0"]},
        )

    def test_uv_default_provider_is_valid(self):
        catalog = {"linecast": {"all": {"provider": "uv", "packages": ["linecast"]}}}
        resolved = resolve(["linecast"], catalog, "arch", "uv")
        self.assertEqual(resolved["packages"], {"uv": ["linecast"]})

    def test_empty_all_list_fails(self):
        catalog = {"bat": {"all": []}}
        with self.assertRaises(CatalogError) as ctx:
            resolve(["bat"], catalog)
        self.assertIn("must not be an empty list", str(ctx.exception))

    def test_missing_post_install_is_empty_list(self):
        catalog = {
            "bat": {"all": {"provider": "mise", "packages": ["bat@0.26.1"]}},
        }
        self.assertEqual(resolve(["bat"], catalog)["post_install"], [])


class ResolveCatalogPostInstallTests(unittest.TestCase):
    def _rambox(self, post_install):
        return {
            "rambox": {
                "arch": {
                    "provider": "aur",
                    "packages": ["rambox-pro-bin"],
                    "post_install": post_install,
                },
                "darwin": {"provider": "cask", "packages": ["rambox"]},
            }
        }

    def test_desktop_exec_collected_on_matching_os(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                }
            ]
        )
        arch = resolve(["rambox"], catalog, "arch", "pacman")
        self.assertEqual(arch["packages"], {"aur": ["rambox-pro-bin"]})
        self.assertEqual(
            arch["post_install"],
            [
                {
                    "app": "rambox",
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                    "optional": False,
                    "section": "Desktop Entry",
                }
            ],
        )

    def test_desktop_exec_skipped_on_other_os(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                }
            ]
        )
        darwin = resolve(["rambox"], catalog, "darwin", "brew")
        self.assertEqual(darwin["packages"], {"cask": ["rambox"]})
        self.assertEqual(darwin["post_install"], [])

    def test_optional_and_section_pass_through(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "~/.local/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                    "optional": True,
                    "section": "Desktop Action NewWindow",
                }
            ]
        )
        resolved = resolve(["rambox"], catalog, "arch", "pacman")
        action = resolved["post_install"][0]
        self.assertTrue(action["optional"])
        self.assertEqual(action["section"], "Desktop Action NewWindow")

    def test_preserves_order_and_dedups_exact_copies(self):
        first = {
            "action": "desktop_exec",
            "path": "/usr/share/applications/a.desktop",
            "exec": "a --flag",
        }
        second = {
            "action": "desktop_exec",
            "path": "/usr/share/applications/b.desktop",
            "exec": "b --flag",
        }
        catalog = self._rambox([first, second, first])
        resolved = resolve(["rambox"], catalog, "arch", "pacman")
        paths = [a["path"] for a in resolved["post_install"]]
        self.assertEqual(
            paths,
            [
                "/usr/share/applications/a.desktop",
                "/usr/share/applications/b.desktop",
            ],
        )

    def test_chmod_collected_on_matching_os(self):
        catalog = self._rambox(
            [
                {"action": "chmod", "path": "/opt/rambox", "mode": "0755"},
                {"action": "chmod", "path": "/opt/rambox/rambox", "mode": "+x"},
            ]
        )
        arch = resolve(["rambox"], catalog, "arch", "pacman")
        self.assertEqual(
            arch["post_install"],
            [
                {
                    "app": "rambox",
                    "action": "chmod",
                    "path": "/opt/rambox",
                    "mode": "0755",
                    "optional": False,
                },
                {
                    "app": "rambox",
                    "action": "chmod",
                    "path": "/opt/rambox/rambox",
                    "mode": "+x",
                    "optional": False,
                },
            ],
        )
        darwin = resolve(["rambox"], catalog, "darwin", "brew")
        self.assertEqual(darwin["post_install"], [])

    def test_chmod_integer_mode_fails(self):
        catalog = self._rambox(
            [{"action": "chmod", "path": "/opt/rambox", "mode": 755}]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("must be a string", str(ctx.exception))

    def test_chmod_missing_mode_fails(self):
        catalog = self._rambox([{"action": "chmod", "path": "/opt/rambox"}])
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("mode", str(ctx.exception))

    def test_invalid_action_fails(self):
        catalog = self._rambox([{"action": "symlink", "path": "/tmp"}])
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("invalid action", str(ctx.exception))

    def test_unknown_key_fails(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                    "owner": "root",
                }
            ]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("unknown keys", str(ctx.exception))

    def test_missing_path_fails(self):
        catalog = self._rambox(
            [{"action": "desktop_exec", "exec": "/opt/rambox/rambox"}]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("path", str(ctx.exception))

    def test_path_must_be_desktop_file(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                }
            ]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn(".desktop", str(ctx.exception))

    def test_exec_must_omit_key_prefix(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "Exec=/opt/rambox/rambox --no-sandbox %U",
                }
            ]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("omit the 'Exec=' prefix", str(ctx.exception))

    def test_empty_post_install_list_fails(self):
        catalog = self._rambox([])
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("must be a non-empty list", str(ctx.exception))

    def test_optional_must_be_bool(self):
        catalog = self._rambox(
            [
                {
                    "action": "desktop_exec",
                    "path": "/usr/share/applications/rambox.desktop",
                    "exec": "/opt/rambox/rambox --no-sandbox %U",
                    "optional": "yes",
                }
            ]
        )
        with self.assertRaises(CatalogError) as ctx:
            resolve(["rambox"], catalog)
        self.assertIn("optional", str(ctx.exception))


class MiseUseAndInstallSplitTests(unittest.TestCase):
    GLOBAL_JSON = """
    {
      "bat": [{"version": "0.26.1", "installed": true}],
      "claude-code": [{"version": "2.1.266", "installed": true}],
      "github:steveyegge/beads": [{"version": "1.2.2", "installed": true}]
    }
    """

    def test_latest_not_in_config_stays_on_use(self):
        specs = ["claude-code@latest", "bat@0.26.1"]
        self.assertEqual(
            mise_use_specs(specs, {}),
            ["claude-code@latest", "bat@0.26.1"],
        )
        self.assertEqual(mise_install_tools(specs, {}), [])

    def test_latest_in_config_goes_to_unversioned_install(self):
        specs = ["claude-code@latest", "bat@0.26.1", "opencode@latest"]
        self.assertEqual(
            mise_use_specs(specs, self.GLOBAL_JSON),
            ["bat@0.26.1", "opencode@latest"],
        )
        self.assertEqual(
            mise_install_tools(specs, self.GLOBAL_JSON),
            ["claude-code"],
        )

    def test_concrete_pin_always_uses_catalog_version(self):
        specs = ["bat@0.26.1"]
        self.assertEqual(mise_use_specs(specs, self.GLOBAL_JSON), ["bat@0.26.1"])
        self.assertEqual(mise_install_tools(specs, self.GLOBAL_JSON), [])

    def test_latest_with_backend_options_matches_config_name(self):
        specs = ["github:steveyegge/beads[exe=bd]@latest"]
        self.assertEqual(mise_use_specs(specs, self.GLOBAL_JSON), [])
        self.assertEqual(
            mise_install_tools(specs, self.GLOBAL_JSON),
            ["github:steveyegge/beads"],
        )

    def test_empty_and_invalid_global_json_are_unconfigured(self):
        specs = ["claude-code@latest"]
        self.assertEqual(mise_use_specs(specs, ""), specs)
        self.assertEqual(mise_use_specs(specs, "not-json"), specs)
        self.assertEqual(mise_install_tools(specs, ""), [])


if __name__ == "__main__":
    unittest.main()
