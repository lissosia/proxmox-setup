#!/bin/bash

LOGFILE="/var/log/proxmox_post_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

contains_line() {
    grep -Fxq "$1" "$2"
}

# 1 Correct Proxmox VE Sources (Ensuring Debian and Proxmox sources are correct)
echo "Correcting Proxmox VE Sources..."
cat <<EOF > /etc/apt/sources.list
deb http://ftp.us.debian.org/debian bookworm main contrib
deb http://security.debian.org bookworm-security main contrib
deb http://ftp.us.debian.org/debian bookworm-updates main contrib
EOF

# 2 Disable Proxmox Enterprise Repository
PVE_ENTERPRISE_FILE="/etc/apt/sources.list.d/pve-enterprise.list"
if [ -f "$PVE_ENTERPRISE_FILE" ] && grep -q "^deb https://enterprise.proxmox.com/debian" "$PVE_ENTERPRISE_FILE"; then
    sed -i "s|deb https://enterprise.proxmox.com/debian|#deb https://enterprise.proxmox.com/debian|g" "$PVE_ENTERPRISE_FILE"
fi

# 3 Enable No-Subscription Repository
PVE_REPO_FILE="/etc/apt/sources.list.d/pve-install-repo.list"
PVE_REPO_LINE="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"
if ! contains_line "$PVE_REPO_LINE" "$PVE_REPO_FILE"; then
    echo "$PVE_REPO_LINE" > "$PVE_REPO_FILE"
fi

# 4 Fix Ceph Repository
CEPH_REPO_FILE="/etc/apt/sources.list.d/ceph.list"
CEPH_NO_SUB_LINE="deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"
if [ ! -f "$CEPH_REPO_FILE" ] || ! contains_line "$CEPH_NO_SUB_LINE" "$CEPH_REPO_FILE"; then
    echo "$CEPH_NO_SUB_LINE" > "$CEPH_REPO_FILE"
fi

# 5 Remove Subscription Nag Message
JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if grep -q "const subscription" "$JS_FILE"; then
    sed -i.bak "s|const subscription = !(!res || !res.data || res.data.status.toLowerCase() !== 'active');|const subscription = true;|g" "$JS_FILE"
fi

# 6 Restart Proxmox Web UI
systemctl restart pveproxy

# 7 Offer System Update During Post-Install
read -p "Would you like to update Proxmox VE now? (y/n): " update_choice
if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    apt update && apt dist-upgrade -y
fi

# 8 Prompt for Reboot
read -p "Would you like to reboot now? (y/n): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    reboot
fi
