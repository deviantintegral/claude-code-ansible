#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  github-org-setup                          # interactive mode
  github-org-setup --org NAME --email EMAIL # non-interactive (token via stdin)

Sets up a GitHub organization directory with:
  - Per-org GH_TOKEN via direnv .env
  - Per-org git commit email via gitconfig includeIf
USAGE
    exit 1
}

org=""
email=""
token=""
interactive=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --org)
            org="$2"
            interactive=false
            shift 2
            ;;
        --email)
            email="$2"
            interactive=false
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

if "$interactive"; then
    read -rp "GitHub org name: " org
    read -rp "Git commit email for this org: " email
    read -rsp "GitHub token (input hidden): " token
    echo  # newline after hidden input
else
    # Non-interactive: read token from stdin
    IFS= read -r token
fi

# Validate required inputs
if [[ -z "$org" ]]; then
    echo "Error: org name is required" >&2
    exit 1
fi
if [[ -z "$email" ]]; then
    echo "Error: email is required" >&2
    exit 1
fi
if [[ -z "$token" ]]; then
    echo "Error: token is required" >&2
    exit 1
fi

org_dir="$HOME/github.com/$org"
env_file="$org_dir/.env"
gitconfig_org="$HOME/.gitconfig-$org"
gitconfig_main="$HOME/.gitconfig"

# 1. Create org directory
mkdir -p "$org_dir"

# 2. Write .env with GH_TOKEN (mode 0600)
printf 'GH_TOKEN=%s\n' "$token" > "$env_file"
chmod 0600 "$env_file"

# 3. Write per-org gitconfig
printf '[user]\n\temail = %s\n' "$email" > "$gitconfig_org"

# 4. Add includeIf to ~/.gitconfig (idempotent)
include_pattern="gitdir:~/github.com/$org/"
if ! grep -qF "$include_pattern" "$gitconfig_main" 2>/dev/null; then
    # Ensure trailing newline before appending
    if [[ -f "$gitconfig_main" ]] && [[ -s "$gitconfig_main" ]]; then
        # Add a newline if the file doesn't end with one
        if [[ "$(tail -c 1 "$gitconfig_main" | wc -l)" -eq 0 ]]; then
            printf '\n' >> "$gitconfig_main"
        fi
    fi
    cat >> "$gitconfig_main" <<EOF
[includeIf "gitdir:~/github.com/$org/"]
	path = ~/.gitconfig-$org
EOF
fi

echo "Done! Set up GitHub org '$org':"
echo "  Directory:  $org_dir"
echo "  .env:       $env_file (GH_TOKEN, mode 0600)"
echo "  Git config: $gitconfig_org (email: $email)"
echo "  includeIf:  added to $gitconfig_main"
