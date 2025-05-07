#!/usr/bin/env bash
set -euo pipefail

trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\`" >&2' ERR
trap 'echo "🔪 Interrupted." >&2; exit 1' INT

echo "🚀 Starting Zsh + Oh-My-Zsh setup…"

# 1) Check root
(( EUID == 0 )) || { echo "❌ Please run as root." >&2; exit 1; }

# 2) Detect package manager
if   command -v apt   >/dev/null; then PM_UPDATE="apt update";    PM_INSTALL="apt install -y"; DISTRO=debian
elif command -v yum   >/dev/null; then PM_UPDATE="yum makecache"; PM_INSTALL="yum install -y"; DISTRO=rhel
elif command -v dnf   >/dev/null; then PM_UPDATE="dnf makecache"; PM_INSTALL="dnf install -y"; DISTRO=rhel
else echo "❌ Unsupported distro." >&2; exit 1; fi

echo "🔧 Installing prerequisites…"
$PM_UPDATE
if [ "$DISTRO" = debian ]; then
  $PM_INSTALL zsh git curl unzip xz-utils
else
  $PM_INSTALL zsh git util-linux-user curl unzip xz
fi

echo "🛠️  Cloning Oh-My-Zsh and preparing skeleton…"
chsh -s /bin/zsh root
[ ! -d /etc/oh-my-zsh ] && \
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/oh-my-zsh
cp /etc/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc
mkdir -p /etc/skel/.config

# instant prompt
sed -i '1i\
# Instant prompt for Powerlevel10k\n\
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then\n\
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"\n\
fi\n' /etc/skel/.zshrc

# point ZSH path & cache
sed -i 's|^export ZSH=.*|export ZSH=/etc/oh-my-zsh|' /etc/skel/.zshrc
sed -i '/^export ZSH=\/etc\/oh-my-zsh/a export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"' \
    /etc/skel/.zshrc

# theme & alias
sed -i '/^ZSH_THEME=/c ZSH_THEME="powerlevel10k/powerlevel10k"' /etc/skel/.zshrc
echo 'alias ll="ls -lahF --color --time-style=long-iso"' >> /etc/skel/.zshrc

echo "🔌 Installing plugins…"
PLUGINS=/etc/oh-my-zsh/custom/plugins
mkdir -p $PLUGINS
[ ! -d $PLUGINS/zsh-syntax-highlighting ]   && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git $PLUGINS/zsh-syntax-highlighting
[ ! -d $PLUGINS/zsh-autosuggestions ]      && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git  $PLUGINS/zsh-autosuggestions
[ ! -d $PLUGINS/zsh-completions ]          && git clone --depth=1 https://github.com/zsh-users/zsh-completions.git    $PLUGINS/zsh-completions
if [ ! -d $PLUGINS/shellfirm ]; then
  mkdir -p $PLUGINS/shellfirm
  curl -fsSL https://raw.githubusercontent.com/kaplanelad/shellfirm/main/shell-plugins/shellfirm.plugin.oh-my-zsh.zsh \
    -o $PLUGINS/shellfirm/shellfirm.plugin.zsh
fi

# FPATH for completions
sed -i '/^source \$ZSH\/oh-my-zsh.sh/i fpath+=${ZSH_CUSTOM:-${ZSH:-~\/.oh-my-zsh}\/custom}\/plugins\/zsh-completions\/src' \
    /etc/skel/.zshrc

# enable plugins
sed -i '/^plugins=/c plugins=(shellfirm copypath git zsh-autosuggestions extract z sudo zsh-syntax-highlighting zsh-completions)' \
    /etc/skel/.zshrc

echo "🎨 Installing Powerlevel10k…"
TH=/etc/oh-my-zsh/custom/themes
mkdir -p $TH
[ ! -d $TH/powerlevel10k ] && \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $TH/powerlevel10k
curl -fsSL https://raw.githubusercontent.com/Slinesx/Zsh-Init/main/p10k.zsh \
  -o /etc/oh-my-zsh/custom/p10k.zsh

# p10k symlink snippet
cat >> /etc/skel/.zshrc << 'EOF'

# Load central p10k config
if [ ! -L "$HOME/.p10k.zsh" ]; then
  ln -s /etc/oh-my-zsh/custom/p10k.zsh "$HOME/.p10k.zsh"
fi
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
EOF

echo "📦 Installing Shellfirm binary…"
URL=$(curl -s https://api.github.com/repos/kaplanelad/shellfirm/releases/latest \
  | grep '"browser_download_url"' | grep 'linux.*\.tar\.xz' | cut -d '"' -f4 | head -n1)
curl -fsSL "$URL" \
  | tar -xJf - --wildcards --strip-components=1 -C /usr/local/bin '*shellfirm*/shellfirm'
chmod +x /usr/local/bin/shellfirm

echo "✅ Finalizing and switching to Zsh…"
[ -f /etc/default/useradd ] && sed -i '/^SHELL=/c SHELL=/bin/zsh' /etc/default/useradd
install -m644 /etc/skel/.zshrc /root/.zshrc
mkdir -p /root/.config
exec /bin/zsh -l
