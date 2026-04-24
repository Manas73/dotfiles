# Role: docker

Configures Docker so the primary user can run it without sudo.

## Responsibilities

- Verify `docker` is installed (package install happens in `arch_packages`).
- Ensure the `docker` group exists.
- Add `primary_user` to the `docker` group.
- Enable `docker.socket` (socket-activated Docker starts on demand).

## Does Not

- Install Docker.
- Run containers.
- Handle macOS; macOS hosts skip this role until Docker Desktop is wired in later.

## Inputs

- `primary_user` (from host_vars).
- `docker_enabled` (from host_vars). Role is only run when true; gated at the site.yml level.

## Notes

- Users must log out and back in for the new group membership to take effect.
- Enabling `docker.socket` rather than `docker.service` matches the original Chezmoi script behavior and is the Arch default.
