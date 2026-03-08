# Claude Code Development VM Playbook

Ansible playbook to provision a Debian 13 (trixie) VM as a Claude Code development environment.

## Prerequisites

- A fresh Debian 13 (trixie) minimal installation with SSH access as root
- Ansible installed on the control machine (`apt install ansible`)
- SSH key access to the target VM's root user

## Quick Start

1. Copy the example variables file and fill in your details:
   ```bash
   cp group_vars/all.yml.example group_vars/all.yml
   ```
   Edit `group_vars/all.yml` with your Git identity, GitHub username, and network settings.

2. Edit `inventory` and replace `CHANGE_ME` with the target VM's IP address:
   ```
   claude.example ansible_host=192.168.1.100 ansible_user=debian
   ```

3. Run the playbook:
   ```bash
   ansible-playbook -i inventory site.yml
   ```

## What It Does

- Sets hostname to `claude.lan` (configurable)
- Creates a `claude` user with passwordless sudo and SSH key access
- Installs development tools: Docker CE, ddev, Node.js, Go, Python 3, uv, mkcert, Java, and CLI utilities
- Installs the [GitHub CLI (`gh`)](https://cli.github.com/) and configures it as the git credential helper for HTTPS authentication
- Installs Claude Code CLI configured for autonomous operation
- Optionally configures a Docker registry proxy for caching pulls
- Deploys tmux, git, and bashrc configurations

## GitHub Authentication

The playbook installs `gh` and configures it as the git credential helper so that `git push` and `git pull` over HTTPS work automatically using a GitHub Personal Access Token (PAT).

### Configuring a token during provisioning

Set the `user_github_pat` variable in `group_vars/all.yml` or pass it on the command line:

```bash
ansible-playbook -i inventory site.yml --extra-vars "user_github_pat=ghp_xxxx"
```

The token is passed to `gh auth login --with-token` and stored in `~/.config/gh/hosts.yml` on the VM.

### Changing the token after deployment

SSH into the VM and run one of:

```bash
# Non-interactively (recommended for automation):
echo "ghp_NEW_TOKEN" | gh auth login --with-token

# Interactively (browser or manual paste):
gh auth login
```

## Security Model

This playbook creates a **disposable, single-purpose development VM** intended to be run by Claude Code as an autonomous coding agent. The security posture reflects this:

- **Passwordless sudo** is enabled for the `claude` user. The VM is not intended to host multiple users or untrusted workloads.
- **Claude Code runs with `--dangerously-skip-permissions`**, allowing it to operate without interactive approval prompts. This is appropriate because the VM is ephemeral and isolated — it can be torn down and reprovisioned at any time.
- **A random password** is generated on each provision for SSH and Samba access. It is not stored persistently.

**Do not use this playbook to provision machines that hold sensitive data or are exposed to the public internet.** It is designed for an isolated LAN or virtual network where the VM is treated as disposable.

## Configurable Variables

Copy `group_vars/all.yml.example` to `group_vars/all.yml` and edit, or override via `--extra-vars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `base_hostname` | `claude` | VM hostname |
| `base_domain` | `lan` | Domain suffix (FQDN = hostname.domain) |
| `base_locale` | `en_CA.UTF-8` | System locale |
| `user_git_user_name` | `Your Name` | Git user.name |
| `user_git_user_email` | `you@example.com` | Git user.email (default) |
| `user_git_lullabot_email` | `you@example.com` | Git email for ~/lullabot/ repos |
| `user_github_keys_url` | `https://github.com/your-username.keys` | SSH authorized_keys source |
| `user_github_pat` | _(empty)_ | GitHub Personal Access Token for HTTPS git auth via `gh` |
| `devtools_docker_registry_proxy_host` | `docker-registry-proxy.example` | Docker registry proxy hostname |
| `devtools_docker_registry_proxy_port` | `3128` | Docker registry proxy port |

## Roles

- **base** — Hostname, locale, APT packages
- **user** — User creation, sudo, SSH, tmux, git, bashrc
- **samba** — Samba file sharing for the user's home directory
- **dev-tools** — Docker, ddev, cloudflared, uv, mkcert, Docker registry proxy
- **claude-code** — Claude Code CLI installation and configuration
