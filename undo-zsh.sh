#!/usr/bin/env bash
set -euo pipefail

# ─── Error handling ────────────────────────────────────────────────────
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\`" >&2; exit 1' ERR
trap 'echo "🔪 Interrupted." >&2; exit 1' INT

echo "🛑 Rolling back Zsh + Oh-My-Zsh…"

# must be root
(( EUID == 0 )) || { echo "❌ Run as root!" >&2; exit 1; }

echo "🔄 Resetting shells to bash…"
chsh -s /bin/bash root >/dev/null 2>&1
[ -f /etc/default/useradd ] && sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd

echo "🗑️  Removing system-wide Zsh configs & binaries…"
rm -rf /etc/oh-my-zsh
rm -f /etc/skel/.zshrc
rm -rf /etc/skel/.config
rm -f /usr/local/bin/shellfirm

echo "🗑️  Removing root user Zsh configs…"
rm -f /root/.zshrc \
      /root/.p10k.zsh \
      /root/.z \
      /root/.zcompdump* \
      /root/.zsh_history
rm -rf /root/.config /root/.cache

echo "📦 Uninstalling packages…"
apt-get update -qq
apt-get purge -y -qq zsh git xz-utils
apt-get autoremove -y -qq
apt-get clean -qq

echo "🧑‍💻 Removing all users with homes in /home…"
for dir in /home/*; do
  [ -d "$dir" ] || continue
  user=$(basename "$dir")
  echo " • Deleting user '$user'"
  userdel -r "$user" >/dev/null 2>&1 || echo "⚠️ Could not remove '$user'" >&2
done

echo "✅ Rollback complete!"