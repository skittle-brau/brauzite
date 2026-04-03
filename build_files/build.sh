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

# Debug: find where 1Password put its manifest files
find /usr/lib/1Password -name "*.json" 2>/dev/null || true
find /var/opt/1Password -name "*.json" 2>/dev/null || true
find /usr/lib/mozilla -name "*1password*" 2>/dev/null || true
find /etc -name "*1password*" 2>/dev/null || true

# Move 1Password's files into /usr which is immutable and persists across boots
# Then symlink /usr/lib/1Password back to where the app expects itself to be
mv /var/opt/1Password /usr/lib/1Password
ln -s /usr/lib/1Password /opt/1Password

# Fix GIDs
mkdir -p /usr/lib/sysusers.d
cat > /usr/lib/sysusers.d/onepassword.conf << 'EOF'
g onepassword     1500
g onepassword-cli 1600
EOF

find /usr/lib/1Password -type f -perm /g+s -exec chgrp 1500 {} \;
find /usr/lib/1Password -type f -perm /g+s -exec chmod g+s {} \;
chgrp 1600 /usr/bin/op
chmod g+s /usr/bin/op

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
