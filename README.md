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

## Running the Playbook Directly on the Target Host

If you are running the playbook on the same machine you want to provision (i.e. no SSH hop), use Ansible's local connection mode. This is useful when bootstrapping the VM from within a post-install script or when SSH is not available.

1. Install Ansible on the target host:
   ```bash
   apt install ansible
   ```

2. Copy the example variables file and fill in your details:
   ```bash
   cp group_vars/all.yml.example group_vars/all.yml
   ```

3. Run the playbook with a local inventory and `--connection=local`:
   ```bash
   ansible-playbook -i localhost, --connection=local site.yml
   ```

   The trailing comma after `localhost` tells Ansible to treat the value as an inline inventory rather than a file path.

   When done, run `source ~/.bashrc` or create a new shell to get updated PATH settings.

### Running with lima-vm

```console
$ limactl create --name claude --cpus=8 --memory=32 template:debian-13
```

**It is highly recommended** to edit or disable the default mount of your home directory. Otherwise, nothing will stop Claude from making changes there.

## What It Does

- Sets hostname to `claude.lan` (configurable)
- Creates a user (default: `claude`) with passwordless sudo and SSH key access
- Installs development tools: Docker CE, ddev, Node.js, Go, Python 3, uv, mkcert, Java, and CLI utilities
- Installs the [GitHub CLI (`gh`)](https://cli.github.com/) and configures it as the git credential helper for HTTPS authentication
- Installs Claude Code CLI configured for autonomous operation
- Optionally configures a Docker registry proxy for caching pulls
- Deploys tmux, git, and bashrc configurations

## GitHub Authentication

The playbook installs `gh` and configures it as the git credential helper so that `git push` and `git pull` over HTTPS work automatically. GitHub tokens are managed per-organization using direnv and the `github-org-setup` script.

### How it works

Each GitHub organization gets its own directory under `~/github.com/<org>/`. Inside that directory:

- A `.env` file sets `GH_TOKEN` for that org's repositories (loaded automatically by direnv)
- A `.gitconfig-<org>` file sets the git commit email for that org
- A gitconfig `includeIf` entry activates the per-org email when working in that directory

When you `cd` into `~/github.com/<org>/` (or any subdirectory), direnv loads the `.env` file and `GH_TOKEN` is set automatically. When you leave, it is unloaded. `GH_TOKEN` takes precedence over the credential stored by `gh auth login`, so per-org tokens work without conflicting with any default token.

### Setting up an organization during provisioning

Set the org variables in `group_vars/all.yml` or pass them on the command line:

```bash
ansible-playbook -i inventory site.yml \
  --extra-vars "user_github_org=my-org user_github_org_email=me@my-org.com user_github_org_token=ghp_xxxx"
```

The playbook runs `github-org-setup` non-interactively to create the directory, token, email config, and direnv approval.

### Adding or updating organizations after deployment

SSH into the VM and run `github-org-setup`:

```bash
# Interactive mode — prompts for org, email, and token:
github-org-setup

# Non-interactive mode — org and email as flags, token via stdin:
echo "ghp_xxxx" | github-org-setup --org my-org --email me@my-org.com
```

Running the script again for an existing org overwrites the token and email configuration.

### Multiple organizations

You can set up as many organizations as you need. Each gets its own isolated directory and token:

```bash
github-org-setup   # set up lullabot
github-org-setup   # set up personal
```

This creates:

```
~/github.com/
  lullabot/
    .env           # GH_TOKEN for lullabot repos
  personal/
    .env           # GH_TOKEN for personal repos
```

Switching between directories automatically swaps the active token and git commit email.

### Recommended: Fine-grained Personal Access Tokens

Fine-grained PATs are recommended over classic PATs. They offer several advantages:

- **Scoped to specific repositories** — a token can only access the repos you choose
- **Granular permissions** — grant only the access each project needs
- **Mandatory expiration dates** — tokens cannot be created without an expiry

Create them at: **Settings > Developer settings > Personal access tokens > Fine-grained tokens**.

Commonly needed permissions:

| Permission | Access | Purpose |
|------------|--------|---------|
| Contents | Read and write | Push and pull code |
| Pull requests | Read and write | Create and manage PRs |
| Issues | Read and write | Create and manage issues (if needed) |
| Metadata | Read-only | Always required (automatically included) |

For the best security posture, create a separate fine-grained token per organization or client.

## Security Model

This playbook creates a **disposable, single-purpose development VM** intended to be run by Claude Code as an autonomous coding agent. The security posture reflects this:

- **Passwordless sudo** is enabled for the configured user (default: `claude`). The VM is not intended to host multiple users or untrusted workloads.
- **Claude Code runs with `--dangerously-skip-permissions`**, allowing it to operate without interactive approval prompts. This is appropriate because the VM is ephemeral and isolated — it can be torn down and reprovisioned at any time.
- **A random password** is generated on each provision for SSH and Samba access. It is not stored persistently.

**Do not use this playbook to provision machines that hold sensitive data or are exposed to the public internet.** It is designed for an isolated LAN or virtual network where the VM is treated as disposable.

## Configurable Variables

Copy `group_vars/all.yml.example` to `group_vars/all.yml` and edit, or override via `--extra-vars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `user_name` | `claude` | Username for the primary system account |
| `base_hostname` | `claude` | VM hostname |
| `base_domain` | `lan` | Domain suffix (FQDN = hostname.domain) |
| `base_locale` | `en_CA.UTF-8` | System locale |
| `user_git_user_name` | `Your Name` | Git user.name |
| `user_git_user_email` | `you@example.com` | Git user.email (default) |
| `user_github_keys_url` | `https://github.com/your-username.keys` | SSH authorized_keys source |
| `user_github_org` | _(empty)_ | GitHub organization name for initial setup (e.g. `lullabot`) |
| `user_github_org_email` | _(empty)_ | Git commit email for the initial org |
| `user_github_org_token` | _(empty)_ | GitHub PAT for the initial org (fine-grained PATs recommended) |
| `devtools_docker_registry_proxy_host` | `docker-registry-proxy.example` | Docker registry proxy hostname |
| `devtools_docker_registry_proxy_port` | `3128` | Docker registry proxy port |

## Roles

- **base** — Hostname, locale, APT packages
- **user** — User creation, sudo, SSH, tmux, git, bashrc
- **samba** — Samba file sharing for the user's home directory
- **dev-tools** — Docker, ddev, cloudflared, uv, mkcert, Docker registry proxy
- **claude-code** — Claude Code CLI installation and configuration
