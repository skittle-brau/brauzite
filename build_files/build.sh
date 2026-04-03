#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux korganizer merkuro firefox

bash

#!/bin/bash
set -ouex pipefail

### Install packages
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
ln -s /usr/lib/1Password /opt/1Password

# Tell systemd to recreate the /var/opt/1Password symlink on every boot
mkdir -p /usr/lib/tmpfiles.d
cat > /usr/lib/tmpfiles.d/1password.conf << 'EOF'
L /var/opt/1Password - - - - /usr/lib/1Password
EOF

# Install polkit policy
export POLICY_OWNERS="unix-user:root"
eval "cat <<EOF
$(cat /usr/lib/1Password/com.1password.1Password.policy.tpl)
EOF" > /usr/share/polkit-1/actions/com.1password.1Password.policy

# Install custom allowed browsers config
install -Dm0644 /usr/lib/1Password/resources/custom_allowed_browsers -t /etc/1password/

# Set chrome-sandbox setuid bit
chmod 4755 /usr/lib/1Password/chrome-sandbox

# Create /usr/bin/1password symlink
ln -sf /usr/lib/1Password/1password /usr/bin/1password

# Write the native messaging host manifest to the system-wide Mozilla paths
# 1Password normally writes this at runtime but we need it baked into the image
mkdir -p /usr/lib/mozilla/native-messaging-hosts
cat > /usr/lib/mozilla/native-messaging-hosts/com.1password.1password.json << 'EOF'
{
  "name": "com.1password.1password",
  "description": "1Password BrowserSupport",
  "path": "/usr/lib/1Password/1Password-BrowserSupport",
  "type": "stdio",
  "allowed_extensions": [
    "{0a75d802-9aed-41e7-8daa-24c067386e82}",
    "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}",
    "{d634138d-c276-4fc8-924b-40a0ea21d284}"
  ]
}
EOF

# Also write to /usr/lib64 path as Firefox may check either location
mkdir -p /usr/lib64/mozilla/native-messaging-hosts
cp /usr/lib/mozilla/native-messaging-hosts/com.1password.1password.json \
   /usr/lib64/mozilla/native-messaging-hosts/com.1password.1password.json

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
