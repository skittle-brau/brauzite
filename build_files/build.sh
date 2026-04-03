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

# Pre-create the install directory (/opt is a symlink to /var/opt in OSTree)
mkdir -p /var/opt/1Password

# Add GPG key and repo
rpm --import https://downloads.1password.com/linux/keys/1password.asc

cat > /etc/yum.repos.d/1password.repo << 'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

dnf5 install -y 1password 1password-cli

rm /etc/yum.repos.d/1password.repo

# Move 1Password's files into /usr which is immutable and persists across boots
mv /var/opt/1Password /usr/lib/1Password

# Tell systemd to recreate the /var/opt/1Password symlink on every boot
# (bootc lint requires this instead of leaving real content in /var)
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/1password.conf << 'EOF'
L /var/opt/1Password - - - - /usr/lib/1Password
EOF

# Run 1Password's own post-install script to set up manifests, polkit, etc.
/usr/lib/1Password/after-install.sh

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

# Clean up dnf cache left in /var to satisfy bootc lint
rm -rf /var/lib/dnf

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
