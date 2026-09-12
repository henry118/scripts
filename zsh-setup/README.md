# Portable Zsh + Catppuccin setup

`setup-zsh.sh` is self-contained: copy that one file to another machine. It embeds the accompanying `zshrc` and `starship.toml`; these separate copies are included for inspection only. Editing the separate copies does not change the script.

## Run

```bash
# Preview without network access or writes.
bash setup-zsh.sh --dry-run

# Install shell tools and configuration; asks before starting.
bash setup-zsh.sh

# Also install JetBrainsMono Nerd Font for the theme's icons.
bash setup-zsh.sh --with-font

# Also build eza; asks separately before installing Rust if needed.
bash setup-zsh.sh --with-font --with-eza
```

Run as your ordinary user, **not** with sudo. The script uses sudo only for Linux system packages. On macOS it uses system tools and downloads upstream binaries into `~/.local/bin`. It never probes for, invokes, installs, or configures Homebrew. A fresh Mac needs working Git; if Apple Command Line Tools are absent, the script stops and tells you to run `xcode-select --install`, finish that installation, then rerun. It does not launch that installation itself.

Use `--yes` to accept the script's plan without a prompt. Linux administrator authentication may still require interaction. For a remote Linux machine, install/select the Nerd Font on the computer running your terminal; a font installed only on the remote host cannot fix local rendering.

After installation, select **JetBrainsMono Nerd Font** (or its Mono variant) in your terminal font settings, then open Zsh with `zsh`. Font and terminal background selection are manual; the preset uses Catppuccin Mocha and looks best on a dark background.

## Scope and supported systems

- macOS 12+ on Apple Silicon or Intel, using built-in `plutil` to read upstream GitHub release metadata. Downloaded tools may impose newer macOS minimums; each executable is checked before installation. Uses existing Zsh, curl, unzip, tar, and working Git. No Python, jq, Ruby, or external package manager is required.
- Recent Debian/Ubuntu (`apt-get`), Fedora (`dnf`), Arch (`pacman`), and openSUSE (`zypper`) with the named packages available in enabled repositories.
- Arch performs a full system upgrade before adding packages, as required to avoid partial upgrades.
- Older Linux releases, minimal images, and enterprise distributions with restricted repositories may lack packages such as zoxide or direnv. The script stops on required-package failure; it does not add third-party package repositories. eza is optional and falls back to standard ls on Linux. On macOS, eza is kept if already installed; otherwise use `--with-eza` to build it from source, since its current upstream release has no macOS binary.
- Bash is required to run the script. Network access is required for installation.

On Linux, installs missing **Zsh, Git, curl, unzip, fzf, zoxide, direnv, bat, ripgrep, Starship**, and tries **eza**; also installs CA certificates. On macOS, reuses system tools and downloads missing **fzf, zoxide, direnv, bat, ripgrep** from their official GitHub releases, choosing the appropriate architecture. Published SHA-256 asset digests are checked when provided; absent digests are reported. Starship uses its official installer. GitHub API rate limits or unavailable release assets cause a clear failure; no alternate package manager is used. Oh My Zsh, autosuggestions, and syntax highlighting are cloned from their official GitHub repositories. Existing installations and plugin directories are retained; incomplete existing plugin directories cause an explanatory error.

The script uses current packages and upstream downloads, not pinned versions. It does not silently upgrade existing Starship, Rust toolchains, or plugin clones. This reproduces the configuration, not a byte-for-byte tool version lock.

**Docker, Docker Compose, kubectl, AWS CLI, Go, and mise are not installed.** They are separate development toolchains rather than requirements for the shell. Their OMZ plugins activate automatically when their commands are visible at shell startup. Existing mise and Starship initialization is retained. No cloud credentials, Kubernetes configuration, history, or other private files are copied into the bundle.

## Included behavior

- Your Catppuccin Powerline Mocha preset, including its 45-second command-notification setting.
- Fuzzy history/file/directory selection; zoxide; direnv; command suggestions and syntax coloring.
- Your history preferences, completion matching, Git aliases, Kubernetes selectors, and CLI defaults.
- User-local executable PATH setup; deduplicated PATH; Debian/Ubuntu batcat support. No package-manager-specific PATH entries are added.
- `kctx` switches your active Kubernetes context. `kns` changes the namespace of your current context. Neither command runs during installation.

It does not change your login shell. Optionally run `chsh -s "$(command -v zsh)"` afterward. If that path is not in `/etc/shells`, use an already listed Zsh path or consult your administrator. Existing `.zprofile`, `.zshenv`, and OMZ custom scripts are left intact; their settings can still affect shell startup.

## Optional eza source build and Rust

`--with-eza` works on macOS and supported Linux distributions. Existing eza is reused. Otherwise the script finds Cargo in PATH or `${CARGO_HOME:-$HOME/.cargo}/bin` and builds the published crates.io package using:

```bash
cargo install eza --locked --root "$HOME/.local"
```

If Rust/Cargo are absent, the script asks a **separate question** before downloading and running official `rustup` with the minimal stable toolchain. `--yes` does **not** answer that question. Declining or reaching end-of-input skips eza and continues the shell setup. An incomplete or unusable existing Rust installation causes an error rather than being overwritten; repair it and rerun. An old Rust compiler may need a manual update to satisfy current eza requirements.

Rustup uses its standard user directories (or existing `CARGO_HOME`/`RUSTUP_HOME` overrides) and `--no-modify-path`, so it does not edit other shell startup files. The generated Zsh config adds Cargo's bin directory when present. Eza itself goes into `~/.local/bin`. No administrator access is needed for Rust or eza installation.

Compiling requires Apple's Command Line Tools on macOS. On Linux, the opt-in build installs compiler, make, pkg-config, OpenSSL development files, and CMake through the native package manager, which can require sudo. These dependencies are listed in the setup plan. Builds can take several minutes. Rust and build dependencies remain installed if a later build fails; rerunning is supported.

`--with-eza` cannot be combined with `--config-only`.

## Backups and reruns

Before replacing different configuration, the script moves the original files into a unique directory under:

```text
~/.local/state/zsh-setup/backups/<timestamp>.<unique-id>/
```

`restore-map.txt` records each original destination. Symlinks are moved as symlinks; their targets are not overwritten. Identical configuration files are skipped on reruns. Package-manager operations may still occur on reruns, particularly Arch's system upgrade. There is no automatic rollback of installed packages if a later step fails.

To restore an ordinary backed-up file, copy it to its destination from `restore-map.txt`. To restore a backed-up symlink, first move the newly generated destination out of the way, then move the backed-up symlink back. Do not blindly restore every backup to the same destination.

## Configuration-only mode

```bash
# Apply configuration without software installation.
bash setup-zsh.sh --config-only

# Stage files in a separate directory for review; no home-directory changes.
bash setup-zsh.sh --config-only --target-home /absolute/path/to/staging --yes
```

Configuration-only mode requires dependencies to exist before the generated shell can be used. Staging can be used even when they are absent. Custom `ZDOTDIR`, `ZSH_CUSTOM`, or `STARSHIP_CONFIG` overrides require manual integration; the installer reports them rather than guessing. Standard `XDG_CONFIG_HOME` is respected for Starship.

## Validation and sources

Checked Bash and Zsh syntax, configuration generation, backups, symlink preservation, rerun behavior, cancellation, invalid options, and Starship rendering locally on macOS. Tested the macOS release downloader offline with fixture archives, architecture-specific asset selection, raw binaries, checksum failures, and existing-executable reuse. Mocked eza/Rust tests cover separate consent (including `--yes`), declined/absent input, successful bootstrap/build, existing tools, and incomplete toolchains. No real Rust/eza build was performed. Installation on fresh macOS/Linux machines has **not** been run; package-manager/network integration remains unverified.

Official references: [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh), [Starship installation](https://starship.rs/guide/), [Catppuccin preset](https://starship.rs/presets/catppuccin-powerline), [fzf](https://github.com/junegunn/fzf), [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts), [Rustup](https://rust-lang.github.io/rustup/installation/index.html), [eza installation](https://github.com/eza-community/eza/blob/main/INSTALL.md).
