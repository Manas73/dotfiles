# Inventory Examples

These are committed placeholders for future machines. They live outside the active `host_vars/` and `hosts.yml` on purpose so they do not affect Ansible runs today.

The directory sits next to `host_vars/` rather than inside it, because Ansible interprets any subdirectory under `host_vars/` as per-host variables for a host with that directory's name.

## Onboarding a Future Host

When a new machine exists:

1. Copy the relevant example file into the active `host_vars/` directory:
   ```sh
   cp ansible/inventories/personal/examples/host_vars/future-linux-laptop.yml \
      ansible/inventories/personal/host_vars/<real-hostname>.yml
   ```
2. Edit the file for the actual host:
   - Update `primary_user` if different.
   - Adjust `gpu_vendor`, `window_managers`, and `plasma_window_manager`.
   - Toggle `docker_enabled`, `kanata_enabled`, `gaming_enabled`.
3. Add the host to the appropriate groups in `inventories/personal/hosts.yml`.
4. Validate:
   ```sh
   ansible-inventory -i ansible/inventories/personal/hosts.yml --host <real-hostname>
   ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --syntax-check
   ```

## Files

- `future-linux-laptop.yml`: generic Arch/Garuda laptop with Hyprland.
- `future-macbook.yml`: macOS laptop for development work.

## Rules

- Host vars contain only true per-machine values (user, GPU, WM choices, enablement flags, Chezmoi intent).
- Shared package lists and role behavior live in `group_vars/`, never in `host_vars/`.
