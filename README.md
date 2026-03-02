# Claude Code Development VM Playbook

Ansible playbook to provision a Debian 13 (trixie) VM as a Claude Code development environment.

## Prerequisites

- A fresh Debian 13 (trixie) minimal installation with SSH access as root
- Ansible installed on the control machine (`apt install ansible`)
- SSH key access to the target VM's root user

## Quick Start

1. Edit `inventory` and replace `CHANGE_ME` with the target VM's IP address:
   ```
   claude.lan ansible_host=192.168.1.100 ansible_user=root
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory site.yml
   ```

## What It Does

- Sets hostname to `claude.lan`
- Creates a `claude` user with passwordless sudo and SSH key access
- Installs development tools: Docker CE, ddev, Node.js, Go, Python 3, uv, mkcert, Java, and CLI utilities
- Installs Claude Code CLI configured for autonomous operation
- Configures Docker registry proxy at `docker-registry-proxy.lan:3128`
- Deploys tmux, git, and bashrc configurations

## Configurable Variables

Override in `group_vars/all.yml` or via `--extra-vars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `base_hostname` | `claude` | VM hostname |
| `base_domain` | `lan` | Domain suffix (FQDN = hostname.domain) |
| `base_locale` | `en_CA.UTF-8` | System locale |
| `user_git_user_name` | `Andrew Berry` | Git user.name |
| `user_git_user_email` | `andrew@furrypaws.ca` | Git user.email (default) |
| `user_git_lullabot_email` | `andrew.berry@lullabot.com` | Git email for ~/lullabot/ repos |
| `user_github_keys_url` | `https://github.com/deviantintegral.keys` | SSH authorized_keys source |
| `devtools_docker_registry_proxy_host` | `docker-registry-proxy.lan` | Docker registry proxy hostname |
| `devtools_docker_registry_proxy_port` | `3128` | Docker registry proxy port |

## Roles

- **base** — Hostname, locale, APT packages
- **user** — User creation, sudo, SSH, tmux, git, bashrc
- **dev-tools** — Docker, ddev, cloudflared, uv, mkcert, Docker registry proxy
- **claude-code** — Claude Code CLI installation and configuration
