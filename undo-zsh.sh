#!/usr/bin/env bash
set -euo pipefail

# ─── Error handling ────────────────────────────────────────────────────
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\`" >&2; exit 1' ERR
trap 'echo "🔪 Interrupted." >&2; exit 1' INT

echo "🛑 Rolling back Zsh + Oh-My-Zsh…"

# 1) Must run as root
(( EUID == 0 )) || { echo "❌ Run as root!" >&2; exit 1; }

# 2) Reset root's shell to Bash
echo "🔄 Resetting root shell to Bash…"
chsh -s /bin/bash root >/dev/null
[ -f /etc/default/useradd ] && sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd

# 3) Remove global Zsh configs & Shellfirm
echo "🗑️  Removing global Zsh configs and Shellfirm…"
rm -rf /etc/oh-my-zsh /etc/skel/.zshrc /etc/skel/.config /usr/local/bin/shellfirm

# 4) Clean up /root's Zsh files
echo "🗑️  Cleaning up /root Zsh files…"
rm -f /root/.zshrc /root/.p10k.zsh /root/.z /root/.zcompdump* /root/.zsh_history
rm -rf /root/.config /root/.cache

# 5) Uninstall packages quietly
echo "📦 Uninstalling Zsh, Git, XZ-utils…"
apt-get update -qq > /dev/null
apt-get purge -y -qq zsh git xz-utils > /dev/null
apt-get autoremove -y -qq > /dev/null
apt-get clean -qq > /dev/null

# 6) Switch back to Bash
echo "✅ Rollback complete! Switching to Bash…"
exec /bin/bash -l