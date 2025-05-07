#!/usr/bin/env bash
set -euo pipefail

# ─── Error handling ──────────────────────────────────────────────────────────────
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\`" >&2' ERR
trap 'echo "🔪 Script interrupted." >&2; exit 1' INT

# -----------------------------------------------------------------------------
# Script to globally install & configure Zsh + Oh-My-Zsh with:
# • Powerlevel10k (instant prompt + central p10k.zsh symlink for new users)
# • Plugins: shellfirm (plugin + binary), copypath, git,
#   zsh-autosuggestions, extract, z, sudo, zsh-syntax-highlighting, zsh-completions
# • FPATH setup for zsh-completions
# • Create ~/.config for root and new users
# • Copy .zshrc into /root and exec into zsh to apply immediately
# -----------------------------------------------------------------------------

# 1) Must be root
if (( EUID != 0 )); then
  echo "❌ Please run as root." >&2
  exit 1
fi

# 2) Detect package manager
if   command -v apt   >/dev/null; then PM_UPDATE="apt update";    PM_INSTALL="apt install -y"; DISTRO="debian"
elif command -v yum   >/dev/null; then PM_UPDATE="yum makecache"; PM_INSTALL="yum install -y"; DISTRO="rhel"
elif command -v dnf   >/dev/null; then PM_UPDATE="dnf makecache"; PM_INSTALL="dnf install -y"; DISTRO="rhel"
else
  echo "❌ Unsupported distro—install zsh & git manually." >&2
  exit 1
fi

# 3) Install prerequisites (including xz-utils for .tar.xz)
$PM_UPDATE
if [ "$DISTRO" = "debian" ]; then
  $PM_INSTALL zsh git curl unzip xz-utils
else
  $PM_INSTALL zsh git util-linux-user curl unzip xz
fi

# 4) Make Zsh the shell for root
chsh -s /bin/zsh root

# 5) Clone Oh-My-Zsh into /etc if absent
if [ ! -d /etc/oh-my-zsh ]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/oh-my-zsh
fi

# 6) Provision /etc/skel/.zshrc and default ~/.config for new users
cp /etc/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
mkdir -p /etc/skel/.config

# 7) Prepend Powerlevel10k instant prompt block
cat << 'EOF' > /etc/skel/.zshrc.new
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

EOF
cat /etc/skel/.zshrc >> /etc/skel/.zshrc.new
mv /etc/skel/.zshrc.new /etc/skel/.zshrc

# 8) Point $ZSH to /etc/oh-my-zsh and isolate its cache
sed -i 's|^export ZSH=.*|export ZSH=/etc/oh-my-zsh|' /etc/skel/.zshrc
sed -i '/^export ZSH=\/etc\/oh-my-zsh/a export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"' /etc/skel/.zshrc

# 9) Configure Powerlevel10k theme and ll alias
sed -i '/^ZSH_THEME=/c ZSH_THEME="powerlevel10k/powerlevel10k"' /etc/skel/.zshrc
echo 'alias ll="ls -lahF --color --time-style=long-iso"' >> /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# 10) Install requested plugins under /etc/oh-my-zsh/custom/plugins
# -----------------------------------------------------------------------------
PLUGINS=/etc/oh-my-zsh/custom/plugins
mkdir -p "$PLUGINS"

[ ! -d "$PLUGINS/zsh-syntax-highlighting" ] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$PLUGINS/zsh-syntax-highlighting"

[ ! -d "$PLUGINS/zsh-autosuggestions" ] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$PLUGINS/zsh-autosuggestions"

[ ! -d "$PLUGINS/zsh-completions" ] && \
  git clone --depth=1 https://github.com/zsh-users/zsh-completions.git \
    "$PLUGINS/zsh-completions"

if [ ! -d "$PLUGINS/shellfirm" ]; then
  mkdir -p "$PLUGINS/shellfirm"
  curl -fsSL \
    https://raw.githubusercontent.com/kaplanelad/shellfirm/main/shell-plugins/shellfirm.plugin.oh-my-zsh.zsh \
    -o "$PLUGINS/shellfirm/shellfirm.plugin.zsh"
fi

# 11) FPATH setup for zsh-completions
sed -i '/^source \$ZSH\/oh-my-zsh\.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~\/.oh-my-zsh}\/custom}\/plugins\/zsh-completions\/src' /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# 12) Install Shellfirm binary (tar.xz) robustly
# -----------------------------------------------------------------------------
echo "🔄 Installing Shellfirm binary…"
LATEST_URL=$(curl -s "https://api.github.com/repos/kaplanelad/shellfirm/releases/latest" \
  | grep '"browser_download_url"' \
  | grep 'linux.*\.tar\.xz' \
  | cut -d '"' -f4 \
  | head -n1)

curl -fsSL "$LATEST_URL" \
  | tar -xJf - --wildcards --strip-components=1 -C /usr/local/bin '*shellfirm*/shellfirm'

chmod +x /usr/local/bin/shellfirm
echo "✅ Shellfirm installed."

# -----------------------------------------------------------------------------
# 13) Enable exactly these plugins in /etc/skel/.zshrc
# -----------------------------------------------------------------------------
sed -i '/^plugins=/c plugins=(shellfirm copypath git zsh-autosuggestions extract z sudo zsh-syntax-highlighting zsh-completions)' \
  /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# 14) Install Powerlevel10k theme & central config
# -----------------------------------------------------------------------------
THEMES=/etc/oh-my-zsh/custom/themes
mkdir -p "$THEMES"
[ ! -d "$THEMES/powerlevel10k" ] && \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$THEMES/powerlevel10k"

curl -fsSL \
  https://raw.githubusercontent.com/Slinesx/Zsh-Init/refs/heads/main/p10k.zsh \
  -o /etc/oh-my-zsh/custom/p10k.zsh

# 15) Symlink ~/.p10k.zsh for each new user and source it
cat << 'EOF' >> /etc/skel/.zshrc

# ─── Powerlevel10k central config ─────────────────────────────────────────────────
if [ ! -L "${HOME}/.p10k.zsh" ]; then
  ln -s /etc/oh-my-zsh/custom/p10k.zsh "${HOME}/.p10k.zsh"
fi
[[ -f "${HOME}/.p10k.zsh" ]] && source "${HOME}/.p10k.zsh"
EOF

# 16) Make Zsh the default for future users
[ -f /etc/default/useradd ] && sed -i '/^SHELL=/c SHELL=/bin/zsh' /etc/default/useradd

# 17) Copy .zshrc into root's home, create root ~/.config, and switch to Zsh
install -m 0644 /etc/skel/.zshrc /root/.zshrc
chown root:root /root/.zshrc
mkdir -p /root/.config && chown root:root /root/.config

echo "🔄 Switching to Zsh for root to apply configuration…"
exec /bin/zsh -l
