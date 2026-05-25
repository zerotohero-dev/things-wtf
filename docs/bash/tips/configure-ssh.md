
> TODO: ssh-copy-id and other useful tricks.

## Configure SSH

```bash
#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="asgard"
USERNAME="volkan"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

cat >> ~/.ssh/config <<'EOF'
Host asgard
    User $USERNAME     # current user
    HostName $HOSTNAME # host to SSH to
    IdentityFile ~/.ssh/id_ed25519
EOF

chmod 600 ~/.ssh/config

echo "Done: $HOSTNAME entry added to ~/.ssh/config"
```
