# My Dotfiles

This repository contains the dotfiles for my system, managed using [chezmoi](https://www.chezmoi.io/).

## Requirements

Ensure you have the following installed on your system:
- `git`
- `age` (version `1.2.0` or newer)
- `chezmoi` (version `2.52.2` or newer)

## Installation

You have two options for installation:

### Option 1: One-step process (Recommended)

- Initialize and apply the dotfiles in a single command:
    ```shell
    chezmoi init --apply https://github.com/Manas73/dotfiles.git
    ```

### Option 2: Two-step process

1. Initialize the dotfiles repository:

    ```shell
    chezmoi init https://github.com/Manas73/dotfiles.git
    ```

2. Apply the configuration:

    ```shell
    chezmoi apply
    ```