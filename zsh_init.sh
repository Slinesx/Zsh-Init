#!/usr/bin/env bash
set -euo pipefail

# ─── Error handling ────────────────────────────────────────────────────────────────
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\`" >&2; exit 1' ERR
trap 'echo "🔪 Interrupted." >&2; exit 1' INT

echo "🚀 Starting Zsh + Oh-My-Zsh setup (Debian/Ubuntu)…"

# ─── 1) Must be root ───────────────────────────────────────────────────────────────
(( EUID == 0 )) || { echo "❌ Please run as root!" >&2; exit 1; }

# ─── 2) Install prerequisites ──────────────────────────────────────────────────────
echo "🔧 Installing prerequisites…"
apt-get update -qq
apt-get install -y -qq zsh git xz-utils > /dev/null

# ─── 3) Clone Oh-My-Zsh & prepare skeleton ────────────────────────────────────────
echo "🛠️  Cloning Oh-My-Zsh & preparing skeleton…"
chsh -s /bin/zsh root > /dev/null
[ ! -d /etc/oh-my-zsh ] && git clone --depth=1 --quiet https://github.com/ohmyzsh/ohmyzsh.git /etc/oh-my-zsh
cp /etc/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
mkdir -p /etc/skel/.config

# instant prompt for Powerlevel10k
sed -i '1i\
# ⏱︎ Instant prompt for Powerlevel10k\n\
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then\n\
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"\n\
fi\n' /etc/skel/.zshrc

# point ZSH & cache dir, set theme and alias
sed -i 's|^export ZSH=.*|export ZSH=/etc/oh-my-zsh|' /etc/skel/.zshrc
sed -i '/^export ZSH=\/etc\/oh-my-zsh/a export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"' /etc/skel/.zshrc
sed -i '/^ZSH_THEME=/c ZSH_THEME="powerlevel10k/powerlevel10k"' /etc/skel/.zshrc
echo 'alias ll="ls -lahF --color --time-style=long-iso"' >> /etc/skel/.zshrc

# ─── 4) Install plugins ─────────────────────────────────────────────────────────────
echo "🔌 Installing plugins…"
PLUGINS=/etc/oh-my-zsh/custom/plugins
mkdir -p "$PLUGINS"

git clone --depth=1 --quiet https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGINS/zsh-syntax-highlighting" > /dev/null || true
git clone --depth=1 --quiet https://github.com/zsh-users/zsh-autosuggestions.git  "$PLUGINS/zsh-autosuggestions" > /dev/null || true
git clone --depth=1 --quiet https://github.com/zsh-users/zsh-completions.git     "$PLUGINS/zsh-completions" > /dev/null || true

mkdir -p "$PLUGINS/shellfirm"
curl -fsSL https://raw.githubusercontent.com/kaplanelad/shellfirm/main/shell-plugins/shellfirm.plugin.oh-my-zsh.zsh \
  -o "$PLUGINS/shellfirm/shellfirm.plugin.zsh"

# add zsh-completions to fpath
sed -i '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~\/.oh-my-zsh}\/custom}\/plugins\/zsh-completions\/src' /etc/skel/.zshrc

# enable plugins in skeleton .zshrc
sed -i '/^plugins=/c plugins=(shellfirm copypath git zsh-autosuggestions extract z sudo zsh-syntax-highlighting zsh-completions)' /etc/skel/.zshrc

# ─── 5) Install Powerlevel10k ──────────────────────────────────────────────────────
echo "🎨 Installing Powerlevel10k…"
THEMES=/etc/oh-my-zsh/custom/themes
mkdir -p "$THEMES"
git clone --depth=1 --quiet https://github.com/romkatv/powerlevel10k.git "$THEMES/powerlevel10k" > /dev/null || true
curl -fsSL https://raw.githubusercontent.com/Slinesx/Zsh-Init/main/p10k.zsh \
  -o /etc/oh-my-zsh/custom/p10k.zsh

# symlink central p10k.zsh for new users
cat >> /etc/skel/.zshrc << 'EOF'

# 🌟 Load central p10k configuration
if [ ! -L "$HOME/.p10k.zsh" ]; then
  ln -s /etc/oh-my-zsh/custom/p10k.zsh "$HOME/.p10k.zsh"
fi
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF

# ─── 6) Install Shellfirm binary ───────────────────────────────────────────────────
echo "📦 Installing Shellfirm binary…"
URL=$(curl -s https://api.github.com/repos/kaplanelad/shellfirm/releases/latest \
     | grep '"browser_download_url"' \
     | grep 'linux.*\.tar\.xz' \
     | cut -d '"' -f4 \
     | head -n1)
curl -fsSL "$URL" \
  | tar -xJf - --wildcards --strip-components=1 -C /usr/local/bin '*shellfirm*/shellfirm' > /dev/null
chmod +x /usr/local/bin/shellfirm

# ─── 7) Finalize & prepare shell ──────────────────────────────────────────────────
echo "🔧 Configuring Zsh as default shell…"
sed -i '/^SHELL=/c SHELL=/bin/zsh' /etc/default/useradd > /dev/null || true
install -m644 /etc/skel/.zshrc /root/.zshrc
mkdir -p /root/.config

echo "✅ Setup complete! Switching root shell to Zsh…"
exec /bin/zsh -l