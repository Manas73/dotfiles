"""Unit tests for the package catalog resolver.

Run from ansible/: python -m unittest tests.test_catalog
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "filter_plugins"))

from catalog import CatalogError, resolve_catalog  # noqa: E402


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

    def test_mise_rejects_latest(self):
        catalog = {"bat": {"all": {"provider": "mise", "packages": ["bat@latest"]}}}
        with self.assertRaises(CatalogError) as ctx:
            resolve(["bat"], catalog)
        self.assertIn("concrete version", str(ctx.exception))

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


if __name__ == "__main__":
    unittest.main()
