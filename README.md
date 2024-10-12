# My dotfiles

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system:
- `git`
- `chezmoi`

## Installation

1. First, check out the dotfiles repo in your `$HOME` directory using git

    ```shell
    chezmoi init https://github.com/Manas73/dotfiles.git
    ```

2. then use apply the config

    ```shell
    chezmoi apply
    ```
<p align="center"><b>Or</b></p>

1. The above commands can be combined into a single init, checkout, and apply:
    ```shell
    chezmoi init --apply --verbose https://github.com/Manas73/dotfiles.git
    ```