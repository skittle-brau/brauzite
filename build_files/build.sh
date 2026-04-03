#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux korganizer merkuro firefox

### Install 1Password

# Pre-create the directory the RPM expects to exist
# (the RPM's scriptlet fails to mkdir it in the OSTree build environment)
mkdir -p /var/opt/1Password

# Add the 1Password GPG key
rpm --import https://downloads.1password.com/linux/keys/1password.asc

# Add the 1Password repo
cat > /etc/yum.repos.d/1password.repo << 'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

# Install 1Password and the CLI
dnf5 install -y 1password 1password-cli

# Clean up the repo file so it doesn't persist on the final image
# (the package is already installed; the repo isn't needed at runtime)
rm /etc/yum.repos.d/1password.repo

# Fix UID/GID drift - reserve fixed GIDs for 1Password's privileged helpers
# The RPM assigns GIDs dynamically; we need them pinned so sysusers.d
# creates the groups with the correct numbers on every boot/deploy.

# Declare the groups with fixed GIDs via sysusers.d
mkdir -p /usr/lib/sysusers.d
cat > /usr/lib/sysusers.d/onepassword.conf << 'EOF'
g onepassword     1500
g onepassword-cli 1600
EOF

# Re-chown the setgid helper binaries to the reserved GIDs
# so they match what sysusers.d will create at runtime
chgrp 1500 /opt/1Password/1Password-BrowserSupport
chgrp 1600 /usr/bin/op

# Ensure the setgid bit is set on the helpers
chmod g+s /opt/1Password/1Password-BrowserSupport
chmod g+s /usr/bin/op

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
