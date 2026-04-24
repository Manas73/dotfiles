# Role: docker

Configures Docker for the primary user.

## Responsibilities

- On Linux: ensure Docker is installed, the `docker` group exists, the user is in it, and the socket/service is enabled.
- On macOS: handle via Docker Desktop install or skip, as decided later.
- Only runs when `docker_enabled: true`.

## Does Not

- Install Docker on macOS via Homebrew cask unless decided later.
- Build or run containers.

## Inputs

- `primary_user`
- `docker_enabled`

## Implementation Task

Tracked by Beads issue `chezmoi-hoz`.
