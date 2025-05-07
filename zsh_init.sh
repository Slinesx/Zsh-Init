#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Script to globally install and configure Zsh + Oh-My-Zsh with plugins
# Based on: https://sysin.org/blog/linux-zsh-all/
# -----------------------------------------------------------------------------

# Ensure running as root
if (( EUID != 0 )); then
  echo "This script must be run as root."
  exit 1
fi

# Detect package manager and install prerequisites
if command -v apt >/dev/null; then
  PM_UPDATE="apt update"
  PM_INSTALL="apt install -y"
elif command -v yum >/dev/null; then
  PM_UPDATE="yum makecache"
  PM_INSTALL="yum install -y"
elif command -v dnf >/dev/null; then
  PM_UPDATE="dnf makecache"
  PM_INSTALL="dnf install -y"
else
  echo "Unsupported distribution. Please install zsh and git manually."
  exit 1
fi

# Update repos and install zsh & git
$PM_UPDATE
$PM_INSTALL zsh git util-linux-user

# Set Zsh as login shell for root
chsh -s /bin/zsh root

# Clone Oh-My-Zsh globally
if [ ! -d /etc/oh-my-zsh ]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/oh-my-zsh
fi

# Copy default template for new users
cp /etc/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc

# Point $ZSH to global install and set up cache dir
sed -i 's|^export ZSH=.*|export ZSH=/etc/oh-my-zsh|' /etc/skel/.zshrc
sed -i '/^export ZSH=\/etc\/oh-my-zsh/a export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"' /etc/skel/.zshrc

# Configure theme, disable auto-updates, add ll alias
sed -i '/^ZSH_THEME=/c ZSH_THEME="ys"' /etc/skel/.zshrc
sed -i 's/# zstyle .omz:update.*/zstyle '"'"':omz:update'"'"' mode disabled/' /etc/skel/.zshrc
echo 'alias ll="ls -lahF --color --time-style=long-iso"' >> /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# Install plugins into /etc/oh-my-zsh/custom/plugins
# -----------------------------------------------------------------------------
PLUGINS_DIR=/etc/oh-my-zsh/custom/plugins
mkdir -p "$PLUGINS_DIR"

# 1) zsh-syntax-highlighting
if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$PLUGINS_DIR/zsh-syntax-highlighting"
fi

# 2) zsh-autosuggestions
if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$PLUGINS_DIR/zsh-autosuggestions"
fi

# 3) shellfirm (risky-command CAPTCHA)
if [ ! -d "$PLUGINS_DIR/shellfirm" ]; then
  mkdir -p "$PLUGINS_DIR/shellfirm"
  curl -fsSL \
    https://raw.githubusercontent.com/kaplanelad/shellfirm/main/shell-plugins/shellfirm.plugin.oh-my-zsh.zsh \
    -o "$PLUGINS_DIR/shellfirm/shellfirm.plugin.zsh"
fi

# 4) zsh-completions (set fpath before sourcing Oh-My-Zsh)
if [ ! -d "$PLUGINS_DIR/zsh-completions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions \
    "$PLUGINS_DIR/zsh-completions"
fi
sed -i '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH}\/custom}\/plugins\/zsh-completions\/src' /etc/skel/.zshrc

# 5) incr (incremental completion)
INCR_DIR="$PLUGINS_DIR/incr"
if [ ! -d "$INCR_DIR" ]; then
  mkdir -p "$INCR_DIR"
  curl -fsSL https://mimosa-pudica.net/src/incr-0.2.zsh -o "$INCR_DIR/incr.zsh"
fi
echo "source /etc/oh-my-zsh/custom/plugins/incr/incr.zsh" >> /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# Enable all requested plugins in /etc/skel/.zshrc
# -----------------------------------------------------------------------------
sed -i '/^plugins=/c plugins=(shellfirm copypath git zsh-autosuggestions extract z sudo zsh-syntax-highlighting)' /etc/skel/.zshrc

# -----------------------------------------------------------------------------
# Default shell for future users
# -----------------------------------------------------------------------------
if [ -f /etc/default/useradd ]; then
  sed -i '/^SHELL=/c SHELL=/bin/zsh' /etc/default/useradd
fi

echo "✅ Global Zsh + Oh-My-Zsh installation complete!
New users will inherit these settings. Existing users can run:
  cp /etc/skel/.zshrc ~/.zshrc && source ~/.zshrc
" 
