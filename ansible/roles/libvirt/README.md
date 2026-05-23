# Role: libvirt

Configures the libvirt / qemu virtualization stack on Linux hosts so the
primary user can run `virt-manager`, `virsh`, and `qemu-system-*` without
sudo. Companion to the `virtualization` profile in
`group_vars/all/profiles.yml`, which installs the actual packages.

## Responsibilities

- Assert the host is Linux; no-op otherwise.
- Verify `libvirtd` is installed (it is, if the host opts into the
  `virtualization` profile and the `packages` orchestrator has run).
- Create the `kvm` and `libvirt` groups (idempotent; they usually already
  exist after libvirt installs).
- Add the primary user to both groups, appended.
- Enable `libvirtd.socket` and `virtlogd.socket` so libvirt starts on
  demand. Socket activation means there's no need to enable `.service`
  units directly.

## Does Not

- Install libvirt, qemu, virt-manager, virt-viewer, dnsmasq, swtpm,
  edk2-ovmf, or iptables-nft. Those come from the `virtualization`
  profile via the `packages` orchestrator.
- Configure storage pools, network bridges, or any specific VM.
- Touch the libvirt session-mode user-level daemon (`libvirtd --session`);
  this role wires the system-mode daemon, which is what virt-manager and
  most workflows use.

## Inputs

- `libvirt_enabled` (default `false`, set in `group_vars/all/main.yml`;
  flip to `true` per host in `host_vars/<hostname>.yml`).
- `primary_user` (from `host_vars/<hostname>.yml`).

## Post-install Notes

Group membership requires a logout/login (or `newgrp libvirt && newgrp
kvm` in a single shell) to take effect. The role prints a reminder when
it just granted membership.

## Tags

`system`, `libvirt`.
