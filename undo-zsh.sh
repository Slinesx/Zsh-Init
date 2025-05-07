#!/usr/bin/env bash
set -euo pipefail

# Must run as root
if (( EUID != 0 )); then
  echo "❌ Please run as root." >&2
  exit 1
fi

echo "🔄 Rolling back Zsh/Oh-My-Zsh configuration…"

# 1) Reset root’s shell to bash
echo " • Resetting root shell → /bin/bash"
chsh -s /bin/bash root

# 2) Restore default for new users
if [ -f /etc/default/useradd ]; then
  echo " • Restoring /etc/default/useradd SHELL to /bin/bash"
  sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
fi

# 3) Remove global Oh-My-Zsh tree
echo " • Removing /etc/oh-my-zsh"
rm -rf /etc/oh-my-zsh

# 4) Remove system-wide skeleton config
echo " • Cleaning /etc/skel/.zshrc and /etc/skel/.config"
rm -f /etc/skel/.zshrc
rm -rf /etc/skel/.config

# 5) Remove Shellfirm binary
echo " • Removing /usr/local/bin/shellfirm"
rm -f /usr/local/bin/shellfirm

# 6) Clean up root’s Zsh-related files
echo " • Removing leftover Zsh files in /root"
rm -f /root/.zshrc \
      /root/.p10k.zsh \
      /root/.zcompdump* \
      /root/.zsh_history

rm -rf /root/.config

# 7) Clear any stray zcompdump cache (if zsh is available)
command -v zsh &>/dev/null && zsh -c 'rm -f $HOME/.zcompdump*' || true

echo "✅ Rollback complete."

# 8) Immediately switch this session back to Bash
exec /bin/bash -l
