# Zsh-Init

A single-command installer and rollback for a global Zsh + Oh-My-Zsh setup with Powerlevel10k, Shellfirm, and a curated set of plugins.

## Repository Contents

- **zsh_init.sh**  
  System-wide installer:
  - Installs Zsh & Oh-My-Zsh  
  - Sets up Powerlevel10k (instant prompt + central `p10k.zsh`)  
  - Installs plugins: `shellfirm`, `copypath`, `git`, `zsh-autosuggestions`, `extract`, `z`, `sudo`, `zsh-syntax-highlighting`, `zsh-completions`  
  - Configures `/etc/skel/.zshrc` and `/etc/skel/.config` for new users  
  - Copies config into `/root` and switches to Zsh  

- **undo-zsh.sh**  
  Rollback script:
  - Resets root’s shell to Bash  
  - Cleans up `/etc/oh-my-zsh`, `/etc/skel`, `/root` Zsh files  
  - Removes the Shellfirm binary  
  - Restores defaults for future users  

- **p10k.zsh**  
  Centralized Powerlevel10k theme configuration. Symlinked into each user’s home as `~/.p10k.zsh`.

## Quickstart

### Install / Configure

Run as root to install and configure:

\`\`\`bash
bash -c "$(curl -H 'Cache-Control: no-cache, no-store' -fsSL https://raw.githubusercontent.com/Slinesx/Zsh-Init/main/zsh_init.sh)"
\`\`\`

### Rollback / Uninstall

To undo all changes and return to Bash:

\`\`\`bash
bash -c "$(curl -H 'Cache-Control: no-cache, no-store' -fsSL https://raw.githubusercontent.com/Slinesx/Zsh-Init/main/undo-zsh.sh)"
\`\`\`

Feel free to inspect and customize any script to suit your environment!
