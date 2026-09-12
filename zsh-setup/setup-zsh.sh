#!/usr/bin/env bash
# Portable personal Zsh setup. Compatible with macOS Bash 3.2.
set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
log() { printf '\n%s\n' "$*"; }
has() { command -v "$1" >/dev/null 2>&1; }
usage() {
  cat <<'HELP'
Usage: bash setup-zsh.sh [options]
  --dry-run          Show the plan without writing files or using the network
  --yes              Approve the displayed setup plan without a prompt
  --config-only      Write the bundled configs; do not install software
  --target-home DIR  Stage configs in DIR (requires --config-only)
  --with-font        Install JetBrainsMono Nerd Font in your user font directory
  --with-eza         Build missing eza with Cargo; ask separately before installing Rust
  --help             Show this help

Default: install shell tools, clone missing OMZ/plugins, then back up and replace
.zshrc and the Starship config. Existing repos are kept, not reset or updated.
Supports macOS (direct upstream binaries) and Linux apt, dnf, pacman, or zypper.
Does not install Docker, kubectl, AWS CLI, Go, mise, or change your login shell.
Run as your normal user, not with sudo. System packages use sudo when needed.
HELP
}
setup_yes=0
setup_dry=0
setup_config_only=0
setup_font=0
setup_eza=0
setup_target_set=0
setup_home=$HOME
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) setup_yes=1 ;;
    --dry-run) setup_dry=1 ;;
    --config-only) setup_config_only=1 ;;
    --with-font) setup_font=1 ;;
    --with-eza) setup_eza=1 ;;
    --target-home)
      [[ $# -ge 2 && -n "$2" ]] || die '--target-home requires a directory'
      setup_home=$2; setup_target_set=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done
[[ "$setup_home" == /* && "$setup_home" != / ]] || die 'Target home must be an absolute directory other than /'
[[ $setup_target_set -eq 0 || $setup_config_only -eq 1 ]] || die '--target-home requires --config-only'
[[ $setup_config_only -eq 0 || $setup_font -eq 0 ]] || die '--with-font cannot be used with --config-only'
[[ $setup_config_only -eq 0 || $setup_eza -eq 0 ]] || die '--with-eza cannot be used with --config-only'
if [[ $setup_target_set -eq 0 && -n ${ZDOTDIR:-} && ${ZDOTDIR} != "$HOME" ]]; then
  die 'Custom ZDOTDIR detected. Use --config-only --target-home to stage and merge manually.'
fi
if [[ $setup_target_set -eq 0 && -n ${STARSHIP_CONFIG:-} ]]; then
  die 'STARSHIP_CONFIG is set. Unset it for the standard location, or stage with --config-only --target-home.'
fi
if [[ $setup_target_set -eq 0 && -n ${ZSH_CUSTOM:-} && ${ZSH_CUSTOM} != "$HOME/.oh-my-zsh/custom" ]]; then
  die 'Custom ZSH_CUSTOM detected. Stage with --config-only --target-home and merge manually.'
fi
setup_os=$(uname -s)
setup_pm=none
case "$setup_os" in
  Darwin) setup_pm=direct ;;
  Linux)
    for candidate in apt-get dnf pacman zypper; do
      if has "$candidate"; then setup_pm=$candidate; break; fi
    done ;;
  *) [[ $setup_config_only -eq 1 ]] || die "Unsupported OS: $setup_os" ;;
esac
[[ $setup_pm != none || $setup_config_only -eq 1 ]] || die 'No supported package manager found'
if [[ $setup_target_set -eq 1 ]]; then
  setup_config_dir="$setup_home/.config"
else
  setup_config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
fi
[[ "$setup_config_dir" == /* ]] || die 'XDG_CONFIG_HOME must be absolute'
setup_rc="$setup_home/.zshrc"
setup_theme="$setup_config_dir/starship.toml"
log "Target: $setup_home | OS: $setup_os | package manager: $setup_pm"
if [[ $setup_config_only -eq 0 ]]; then
  if [[ $setup_os == Darwin ]]; then
    log 'Use system Zsh, curl and unzip plus existing Git (Apple Command Line Tools may be required).'
    log 'Download missing fzf, zoxide, direnv, bat and ripgrep from upstream into ~/.local/bin.'
  else
    log 'Install missing shell tools: Zsh, Git, curl, unzip, fzf, zoxide, direnv, bat, ripgrep; try eza when available. Also install CA certificates.'
  fi
  log 'Install missing Starship through its official installer; clone missing Oh My Zsh and two zsh-users plugins.'
  [[ $setup_pm != pacman ]] || log 'Arch: run a full system upgrade (pacman -Syu) before installing packages to avoid partial upgrades.'
fi
[[ $setup_font -eq 0 ]] || log 'Install JetBrainsMono Nerd Font from the official Nerd Fonts GitHub release.'
if [[ $setup_eza -eq 1 ]]; then
  log 'Build missing eza into ~/.local/bin using Cargo. Linux also installs native build dependencies.'
  log 'If Rust is absent, ask separately before installing minimal stable Rust via rustup; --yes does not bypass that question.'
elif [[ $setup_os == Darwin ]]; then
  log 'Use eza only if already installed; otherwise retain standard ls.'
fi
log "Back up and replace: $setup_rc and $setup_theme (unchanged files are skipped)."
log 'Docker, kubectl, AWS CLI, Go, mise, and login-shell changes are not included.'
[[ $setup_dry -eq 0 ]] || exit 0
[[ $setup_config_only -eq 1 || $(id -u) -ne 0 ]] || die 'Run as your normal user, not root'
if [[ $setup_yes -eq 0 ]]; then
  printf '\nProceed with this plan? [y/N] '
  read -r setup_answer || die 'No answer; use --yes for unattended setup'
  case "$setup_answer" in y|Y|yes|YES) ;; *) log 'Cancelled; nothing changed.'; exit 0 ;; esac
fi

umask 077
setup_tmp=$(mktemp -d "${TMPDIR:-/tmp}/zsh-setup.XXXXXXXX")
trap 'rm -rf -- "$setup_tmp"' EXIT
trap 'printf "Setup failed near line %s. Config backups, if created, are retained.\n" "$LINENO" >&2' ERR
export PATH="$HOME/.local/bin:$PATH"
download() { curl --fail --show-error --location --retry 3 --proto '=https' --tlsv1.2 "$1" -o "$2"; }
admin() { has sudo || die 'sudo is required to install system packages'; sudo "$@"; }
pkg_install() {
  case "$setup_pm" in
    apt-get) admin apt-get install -y "$@" ;;
    dnf) admin dnf install -y "$@" ;;
    pacman) admin pacman -S --needed --noconfirm "$@" ;;
    zypper) admin zypper --non-interactive install "$@" ;;
  esac
}
ensure_tool() {
  local executable=$1 package=$2
  has "$executable" || pkg_install "$package"
}
clone_missing() {
  local url=$1 dest=$2 sentinel=$3
  if [[ -e "$dest" || -L "$dest" ]]; then
    [[ -f "$dest/$sentinel" ]] || die "Existing directory is incomplete: $dest (not overwritten)"
    log "Keeping existing $dest"
  else
    mkdir -p "$(dirname "$dest")"
    git clone --depth=1 "$url" "$dest"
  fi
}

# macOS has plutil built in: parse release metadata without Python, jq, or Ruby.
mac_release_binary() {
  local repo=$1 executable=$2 pattern=$3 kind=$4
  if has "$executable"; then log "Keeping existing $executable"; return; fi
  local release_dir="$setup_tmp/release-$executable"
  local index=0 matches=0 name url='' digest='' asset source actual
  mkdir -p "$release_dir"
  download "https://api.github.com/repos/$repo/releases/latest" "$release_dir/metadata.json"
  /usr/bin/plutil -convert json -o /dev/null "$release_dir/metadata.json"
  while name=$(/usr/bin/plutil -extract "assets.$index.name" raw -o - "$release_dir/metadata.json" 2>/dev/null); do
    if [[ "$name" == $pattern ]]; then
      matches=$((matches + 1))
      url=$(/usr/bin/plutil -extract "assets.$index.browser_download_url" raw -o - "$release_dir/metadata.json")
      digest=$(/usr/bin/plutil -extract "assets.$index.digest" raw -o - "$release_dir/metadata.json" 2>/dev/null) || digest=''
    fi
    index=$((index + 1))
  done
  [[ $matches -eq 1 ]] || die "Expected one $executable release matching $pattern; found $matches"
  [[ "$url" == "https://github.com/$repo/releases/download/"* ]] || die "Unexpected release URL for $executable"
  asset="$release_dir/asset"
  download "$url" "$asset"
  if [[ "$digest" == sha256:* ]]; then
    actual=$(/usr/bin/shasum -a 256 "$asset")
    actual=${actual%% *}
    [[ "$actual" == "${digest#sha256:}" ]] || die "Checksum mismatch for $executable"
  else
    log "$executable: upstream metadata has no SHA-256 digest; using the HTTPS release download."
  fi
  if [[ "$kind" == tar ]]; then
    mkdir "$release_dir/unpacked"
    tar -xzf "$asset" -C "$release_dir/unpacked"
    source=$(find "$release_dir/unpacked" -type f -name "$executable")
    [[ -n "$source" && -f "$source" ]] || die "Could not locate one $executable executable in archive"
  else
    source=$asset
  fi
  chmod u+x "$source"
  "$source" --version >/dev/null || die "$executable cannot run on this macOS version"
  mkdir -p "$setup_bin_dir"
  [[ ! -e "$setup_bin_dir/$executable" && ! -L "$setup_bin_dir/$executable" ]] || die "Refusing to overwrite unexpected $setup_bin_dir/$executable"
  /usr/bin/install -m 755 "$source" "$setup_bin_dir/$executable"
  log "Installed $executable in $setup_bin_dir"
}

install_mac_tools() {
  local tool git_path rust_arch go_arch
  for tool in zsh curl unzip tar; do has "$tool" || die "Required macOS tool missing: $tool"; done
  [[ -x /usr/bin/plutil ]] || die 'macOS plutil is required'
  # Apple Git is a developer-tools launcher when CLT/Xcode is absent.
  git_path=$(command -v git || true)
  [[ -n "$git_path" ]] || die 'Install Apple Command Line Tools with xcode-select --install, then rerun'
  if [[ "$git_path" == /usr/bin/git ]] && ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    die 'Install Apple Command Line Tools with xcode-select --install, finish installation, then rerun'
  fi
  git --version >/dev/null || die 'Git is not usable; finish installing Apple Command Line Tools and rerun'
  case "$(uname -m)" in
    arm64|aarch64) rust_arch=aarch64; go_arch=arm64 ;;
    x86_64) rust_arch=x86_64; go_arch=amd64 ;;
    *) die 'Supported macOS architectures are Apple Silicon and Intel' ;;
  esac
  mac_release_binary junegunn/fzf fzf "fzf-*-darwin_${go_arch}.tar.gz" tar
  mac_release_binary ajeetdsouza/zoxide zoxide "zoxide-*-${rust_arch}-apple-darwin.tar.gz" tar
  mac_release_binary direnv/direnv direnv "direnv.darwin-${go_arch}" binary
  mac_release_binary sharkdp/bat bat "bat-*-${rust_arch}-apple-darwin.tar.gz" tar
  mac_release_binary BurntSushi/ripgrep rg "ripgrep-*-${rust_arch}-apple-darwin.tar.gz" tar
  if [[ $setup_eza -eq 0 ]] && ! has eza; then log 'Keeping standard ls; use --with-eza to build eza from source.'; fi
}

# Source build is opt-in. The Rust consent is deliberately independent of --yes.
install_eza_source() {
  local cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin" rust_answer
  if [[ -d "$cargo_bin" ]]; then export PATH="$PATH:$cargo_bin"; fi
  if has eza; then log 'Keeping existing eza; no Rust installation or build needed.'; return; fi
  if ! has cargo || ! has rustc; then
    if has cargo || has rustc || has rustup; then
      die 'An incomplete Rust installation exists. Repair it so cargo and rustc work, then rerun --with-eza.'
    fi
    printf '\nInstall minimal stable Rust/Cargo using official rustup? [y/N] '
    if ! read -r rust_answer; then rust_answer=n; fi
    case "$rust_answer" in
      y|Y|yes|YES) ;;
      *) log 'Rust installation declined; skipping eza and continuing shell setup.'; return ;;
    esac
    download https://sh.rustup.rs "$setup_tmp/rustup.sh"
    sh "$setup_tmp/rustup.sh" --yes --profile minimal --default-toolchain stable --no-modify-path
    export PATH="$PATH:$cargo_bin"
  fi
  cargo --version >/dev/null && rustc --version >/dev/null || die 'Existing Rust toolchain is unusable. Repair or update it, then rerun --with-eza.'
  if [[ $setup_os == Darwin ]]; then
    /usr/bin/xcrun --find clang >/dev/null 2>&1 || die 'Building eza requires Apple Command Line Tools; run xcode-select --install, then rerun.'
  else
    case "$setup_pm" in
      apt-get) pkg_install build-essential pkg-config libssl-dev cmake ;;
      dnf) pkg_install gcc gcc-c++ make pkgconf-pkg-config openssl-devel cmake ;;
      pacman) pkg_install base-devel pkgconf openssl cmake ;;
      zypper) pkg_install gcc gcc-c++ make pkg-config libopenssl-devel cmake ;;
    esac
  fi
  log 'Building eza from crates.io; this may take several minutes.'
  cargo install eza --locked --root "${setup_bin_dir%/bin}"
  "$setup_bin_dir/eza" --version
}

setup_bin_dir="$HOME/.local/bin"
if [[ $setup_config_only -eq 0 ]]; then
  if [[ $setup_os == Darwin ]]; then
    install_mac_tools
  else
    case "$setup_pm" in
      apt-get) admin apt-get update ;;
      pacman) admin pacman -Syu --noconfirm ;;
      zypper) admin zypper --non-interactive refresh ;;
    esac
    pkg_install ca-certificates
    ensure_tool zsh zsh
    ensure_tool git git
    ensure_tool curl curl
    ensure_tool unzip unzip
    ensure_tool fzf fzf
    ensure_tool zoxide zoxide
    ensure_tool direnv direnv
    ensure_tool rg ripgrep
    if ! has bat && ! has batcat; then pkg_install bat; fi
    if [[ $setup_eza -eq 0 ]] && ! has eza; then
      if ! pkg_install eza; then log 'eza is unavailable; standard ls will remain active.'; fi
    fi
  fi
  if [[ $setup_eza -eq 1 ]]; then install_eza_source; fi
  mkdir -p "$HOME/.local/bin"
  if ! has starship; then
    download https://starship.rs/install.sh "$setup_tmp/starship.sh"
    sh "$setup_tmp/starship.sh" --yes --bin-dir "$HOME/.local/bin"
  fi
  clone_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" oh-my-zsh.sh
  clone_missing https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" zsh-autosuggestions.plugin.zsh
  clone_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" zsh-syntax-highlighting.plugin.zsh
  if [[ $setup_font -eq 1 ]]; then
    if [[ $setup_os == Darwin ]]; then
      setup_font_dir="$HOME/Library/Fonts/JetBrainsMonoNerdFont"
    else
      setup_font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"
    fi
    if [[ -d "$setup_font_dir" ]]; then
      log "Keeping existing font directory: $setup_font_dir"
    else
      download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip "$setup_tmp/font.zip"
      mkdir "$setup_tmp/font"
      unzip -q "$setup_tmp/font.zip" -d "$setup_tmp/font"
      mkdir -p "$(dirname "$setup_font_dir")"
      mv "$setup_tmp/font" "$setup_font_dir"
      chmod -R u+rwX,go+rX "$setup_font_dir"
      if has fc-cache; then fc-cache -f "$setup_font_dir"; fi
    fi
  fi
fi

# Quoted payloads below are literal; no expansion occurs during installation.

cat > "$setup_tmp/zshrc" <<'ZSH_SETUP_RC_PAYLOAD'
# ~/.zshrc

typeset -U path
[[ -d "$HOME/.docker/bin" ]] && path+=("$HOME/.docker/bin")
path=("$HOME/.local/bin" $path)
[[ -d "${CARGO_HOME:-$HOME/.cargo}/bin" ]] && path+=("${CARGO_HOME:-$HOME/.cargo}/bin")
export ZSH="$HOME/.oh-my-zsh"
[[ -d "$HOME/.fzf" ]] && export FZF_BASE="$HOME/.fzf"

# Let Starship own the prompt.
ZSH_THEME=""
HIST_STAMPS="yyyy-mm-dd"

plugins=(git)
(( $+commands[docker] )) && plugins+=(docker docker-compose)
(( $+commands[kubectl] )) && plugins+=(kubectl)
(( $+commands[aws] )) && plugins+=(aws)
(( $+commands[go] )) && plugins+=(golang)
(( $+commands[fzf] )) && plugins+=(fzf)
(( $+commands[zoxide] )) && plugins+=(zoxide)
(( $+commands[direnv] )) && plugins+=(direnv)
plugins+=(zsh-autosuggestions zsh-syntax-highlighting)

source "$ZSH/oh-my-zsh.sh"

# ------------------------------------------------------------
# History
# ------------------------------------------------------------

HISTSIZE=100000
SAVEHIST=100000

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

# ------------------------------------------------------------
# Zsh behavior
# ------------------------------------------------------------

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

unsetopt BEEP

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|=*' \
  'l:|=* r:|=*'

zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''

# ------------------------------------------------------------
# CLI defaults
# ------------------------------------------------------------

if command -v eza >/dev/null; then
  alias ls='eza'
  alias ll='eza -lah --git --icons'
  alias lt='eza --tree --level=2 --icons'
fi

# Debian/Ubuntu may call the binary batcat.
if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
  bat() { command batcat "$@"; }
fi
if command -v bat >/dev/null; then
  alias cat='bat --paging=never'
  alias b='bat --paging=always'
fi

alias ..='cd ..'
alias ...='cd ../..'

# ------------------------------------------------------------
# Git
# ------------------------------------------------------------

alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --graph --decorate --oneline --all'

# ------------------------------------------------------------
# Kubernetes
# ------------------------------------------------------------

alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'

compdef k=kubectl

kctx() {
  (( $+commands[kubectl] && $+commands[fzf] )) || { print -u2 'kctx requires kubectl and fzf'; return 1; }
  local context
  context="$(
    kubectl config get-contexts -o name |
      fzf --prompt='kube context > '
  )" || return

  [[ -n "$context" ]] && kubectl config use-context "$context"
}

kns() {
  (( $+commands[kubectl] && $+commands[fzf] )) || { print -u2 'kns requires kubectl and fzf'; return 1; }
  local namespace
  namespace="$(
    kubectl get namespace \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' |
      fzf --prompt='namespace > '
  )" || return

  [[ -n "$namespace" ]] && kubectl config set-context --current --namespace="$namespace"
}

# ------------------------------------------------------------
# fzf
# ------------------------------------------------------------

export FZF_DEFAULT_OPTS="
  --height=60%
  --layout=reverse
  --border
  --info=inline
"

if (( $+commands[bat] || $+commands[batcat] )); then
  # fzf previews run in a child shell, so use a real executable, not a function.
  _preview_bat=${commands[bat]:-${commands[batcat]}}
  export FZF_CTRL_T_OPTS="
  --preview '\"$_preview_bat\" --color=always --style=numbers --line-range=:300 {} 2>/dev/null'
"
  unset _preview_bat
fi

# ------------------------------------------------------------
# Toolchain
# ------------------------------------------------------------

if command -v mise >/dev/null; then
  eval "$(mise activate zsh)"
fi

# ------------------------------------------------------------
# Prompt
# ------------------------------------------------------------

if command -v starship >/dev/null; then
  eval "$(starship init zsh)"
fi
ZSH_SETUP_RC_PAYLOAD

cat > "$setup_tmp/starship.toml" <<'ZSH_SETUP_THEME_PAYLOAD'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[](red)\
$os\
$username\
[](bg:peach fg:red)\
$directory\
[](bg:yellow fg:peach)\
$git_branch\
$git_status\
[](fg:yellow bg:green)\
$c\
$rust\
$golang\
$nodejs\
$bun\
$php\
$java\
$kotlin\
$haskell\
$python\
[](fg:green bg:sapphire)\
$conda\
[](fg:sapphire bg:lavender)\
$time\
[ ](fg:lavender)\
$cmd_duration\
$line_break\
$character"""

palette = 'catppuccin_mocha'

[os]
disabled = false
style = "bg:red fg:crust"

[os.symbols]
Windows = ""
Ubuntu = "󰕈"
SUSE = ""
Raspbian = "󰐿"
Mint = "󰣭"
Macos = "󰀵"
Manjaro = ""
Linux = "󰌽"
Gentoo = "󰣨"
Fedora = "󰣛"
Alpine = ""
Amazon = ""
Android = ""
AOSC = ""
Arch = "󰣇"
Artix = "󰣇"
CentOS = ""
Debian = "󰣚"
Redhat = "󱄛"
RedHatEnterprise = "󱄛"

[username]
show_always = true
style_user = "bg:red fg:crust"
style_root = "bg:red fg:crust"
format = '[ $user]($style)'

[directory]
style = "bg:peach fg:crust"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = "󰝚 "
"Pictures" = " "
"Developer" = "󰲋 "

[git_branch]
symbol = ""
style = "bg:yellow"
format = '[[ $symbol $branch ](fg:crust bg:yellow)]($style)'

[git_status]
style = "bg:yellow"
format = '[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)'

[nodejs]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[bun]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[c]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[rust]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[golang]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[php]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[java]
symbol = " "
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[kotlin]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[haskell]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version) ](fg:crust bg:green)]($style)'

[python]
symbol = ""
style = "bg:green"
format = '[[ $symbol( $version)(\(#$virtualenv\)) ](fg:crust bg:green)]($style)'

[docker_context]
symbol = ""
style = "bg:sapphire"
format = '[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)'

[conda]
symbol = "  "
style = "fg:crust bg:sapphire"
format = '[$symbol$environment ]($style)'
ignore_base = false

[time]
disabled = false
time_format = "%R"
style = "bg:lavender"
format = '[[  $time ](fg:crust bg:lavender)]($style)'

[line_break]
disabled = true

[character]
disabled = false
success_symbol = '[❯](bold fg:green)'
error_symbol = '[❯](bold fg:red)'
vimcmd_symbol = '[❮](bold fg:green)'
vimcmd_replace_one_symbol = '[❮](bold fg:lavender)'
vimcmd_replace_symbol = '[❮](bold fg:lavender)'
vimcmd_visual_symbol = '[❮](bold fg:yellow)'

[cmd_duration]
show_milliseconds = true
format = " in $duration "
style = "bg:lavender"
disabled = false
show_notifications = true
min_time_to_notify = 45000

[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
flamingo = "#f2cdcd"
pink = "#f5c2e7"
mauve = "#cba6f7"
red = "#f38ba8"
maroon = "#eba0ac"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
teal = "#94e2d5"
sky = "#89dceb"
sapphire = "#74c7ec"
blue = "#89b4fa"
lavender = "#b4befe"
text = "#cdd6f4"
subtext1 = "#bac2de"
subtext0 = "#a6adc8"
overlay2 = "#9399b2"
overlay1 = "#7f849c"
overlay0 = "#6c7086"
surface2 = "#585b70"
surface1 = "#45475a"
surface0 = "#313244"
base = "#1e1e2e"
mantle = "#181825"
crust = "#11111b"

[palettes.catppuccin_frappe]
rosewater = "#f2d5cf"
flamingo = "#eebebe"
pink = "#f4b8e4"
mauve = "#ca9ee6"
red = "#e78284"
maroon = "#ea999c"
peach = "#ef9f76"
yellow = "#e5c890"
green = "#a6d189"
teal = "#81c8be"
sky = "#99d1db"
sapphire = "#85c1dc"
blue = "#8caaee"
lavender = "#babbf1"
text = "#c6d0f5"
subtext1 = "#b5bfe2"
subtext0 = "#a5adce"
overlay2 = "#949cbb"
overlay1 = "#838ba7"
overlay0 = "#737994"
surface2 = "#626880"
surface1 = "#51576d"
surface0 = "#414559"
base = "#303446"
mantle = "#292c3c"
crust = "#232634"

[palettes.catppuccin_latte]
rosewater = "#dc8a78"
flamingo = "#dd7878"
pink = "#ea76cb"
mauve = "#8839ef"
red = "#d20f39"
maroon = "#e64553"
peach = "#fe640b"
yellow = "#df8e1d"
green = "#40a02b"
teal = "#179299"
sky = "#04a5e5"
sapphire = "#209fb5"
blue = "#1e66f5"
lavender = "#7287fd"
text = "#4c4f69"
subtext1 = "#5c5f77"
subtext0 = "#6c6f85"
overlay2 = "#7c7f93"
overlay1 = "#8c8fa1"
overlay0 = "#9ca0b0"
surface2 = "#acb0be"
surface1 = "#bcc0cc"
surface0 = "#ccd0da"
base = "#eff1f5"
mantle = "#e6e9ef"
crust = "#dce0e8"

[palettes.catppuccin_macchiato]
rosewater = "#f4dbd6"
flamingo = "#f0c6c6"
pink = "#f5bde6"
mauve = "#c6a0f6"
red = "#ed8796"
maroon = "#ee99a0"
peach = "#f5a97f"
yellow = "#eed49f"
green = "#a6da95"
teal = "#8bd5ca"
sky = "#91d7e3"
sapphire = "#7dc4e4"
blue = "#8aadf4"
lavender = "#b7bdf8"
text = "#cad3f5"
subtext1 = "#b8c0e0"
subtext0 = "#a5adcb"
overlay2 = "#939ab7"
overlay1 = "#8087a2"
overlay0 = "#6e738d"
surface2 = "#5b6078"
surface1 = "#494d64"
surface0 = "#363a4f"
base = "#24273a"
mantle = "#1e2030"
crust = "#181926"
ZSH_SETUP_THEME_PAYLOAD

if has zsh; then
  zsh -n "$setup_tmp/zshrc"
else
  log 'Zsh is unavailable; syntax validation skipped in config-only mode.'
fi
if has starship; then
  STARSHIP_CONFIG="$setup_tmp/starship.toml" STARSHIP_CACHE="$setup_tmp/starship-cache" \
    starship prompt --path "$setup_tmp" --logical-path "$setup_tmp" > "$setup_tmp/prompt.txt"
fi
setup_backup_dir=''
for setup_dest in "$setup_rc" "$setup_theme"; do
  [[ ! -d "$setup_dest" ]] || die "Config destination is a directory: $setup_dest"
done
save_config() {
  local src=$1 dst=$2 label=$3
  if [[ -d "$dst" ]]; then die "Config destination is a directory: $dst"; fi
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    log "Already current: $dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -z "$setup_backup_dir" ]]; then
      mkdir -p "$setup_home/.local/state/zsh-setup/backups"
      setup_backup_dir=$(mktemp -d "$setup_home/.local/state/zsh-setup/backups/$(date +%Y%m%d-%H%M%S).XXXXXXXX")
    fi
    # Moving preserves symlinks without overwriting their original targets.
    mv "$dst" "$setup_backup_dir/$label"
    printf '%s -> %s\n' "$setup_backup_dir/$label" "$dst" >> "$setup_backup_dir/restore-map.txt"
    if ! cp "$src" "$dst"; then
      mv "$setup_backup_dir/$label" "$dst"
      die "Could not write $dst; original restored"
    fi
  else
    cp "$src" "$dst"
  fi
  chmod 600 "$dst"
  log "Installed: $dst"
}
save_config "$setup_tmp/zshrc" "$setup_rc" zshrc
save_config "$setup_tmp/starship.toml" "$setup_theme" starship.toml
[[ -z "$setup_backup_dir" ]] || log "Backups and restore map: $setup_backup_dir"
log 'Configuration ready. Open Zsh with: zsh'
log 'Select JetBrainsMono Nerd Font in your terminal font settings for Powerline icons.'
log 'To make Zsh your login shell, optionally run: chsh -s "$(command -v zsh)"'
log 'If chsh rejects that path, use a Zsh path already listed in /etc/shells.'
if [[ $setup_config_only -eq 1 ]]; then
  log 'Config-only mode did not install dependencies; the target machine still needs OMZ, its plugins, and Starship.'
fi
