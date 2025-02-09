#!/bin/bash

LOGFILE="/var/log/proxmox_post_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

contains_line() {
    grep -Fxq "$1" "$2"
}

ask_user() {
    read -p "$1 (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]]
}

echo "Starting Proxmox Post-Install Setup..."

# 1 Correct Proxmox VE Sources
if ask_user "Correct Proxmox VE sources?"; then
    REQUIRED_REPOS=(
        "deb http://ftp.us.debian.org/debian bookworm main contrib"
        "deb http://security.debian.org bookworm-security main contrib"
        "deb http://ftp.us.debian.org/debian bookworm-updates main contrib"
    )

    for repo in "${REQUIRED_REPOS[@]}"; do
        if ! contains_line "$repo" /etc/apt/sources.list; then
            echo "$repo" >> /etc/apt/sources.list
            echo "Added repository: $repo"
        fi
    done
fi

# 2 Disable Proxmox Enterprise Repository
PVE_ENTERPRISE_FILE="/etc/apt/sources.list.d/pve-enterprise.list"
if [ -f "$PVE_ENTERPRISE_FILE" ] && grep -q "^deb https://enterprise.proxmox.com/debian" "$PVE_ENTERPRISE_FILE"; then
    if ask_user "Disable Proxmox Enterprise Repository?"; then
        sed -i.bak -E "s|^[[:space:]]*deb https://enterprise.proxmox.com/debian|#&|" "$PVE_ENTERPRISE_FILE"
        echo "Disabled Proxmox Enterprise Repository."
    fi
fi

# 3 Enable No-Subscription Repository
PVE_REPO_FILE="/etc/apt/sources.list.d/pve-install-repo.list"
PVE_REPO_LINE="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"

if ask_user "Enable No-Subscription Repository?"; then
    if [ ! -f "$PVE_REPO_FILE" ] || ! contains_line "$PVE_REPO_LINE" "$PVE_REPO_FILE"; then
        echo "$PVE_REPO_LINE" > "$PVE_REPO_FILE"
        echo "Enabled No-Subscription Repository."
    fi
fi

# 4 Fix Ceph Repository
CEPH_REPO_FILE="/etc/apt/sources.list.d/ceph.list"
CEPH_NO_SUB_LINE="deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"

if ask_user "Fix Ceph Repository?"; then
    if [ ! -f "$CEPH_REPO_FILE" ] || ! contains_line "$CEPH_NO_SUB_LINE" "$CEPH_REPO_FILE"; then
        echo "$CEPH_NO_SUB_LINE" > "$CEPH_REPO_FILE"
        echo "Configured Ceph No-Subscription Repository."
    fi
fi

# 5 Remove Subscription Nag Message
JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if grep -q "const subscription" "$JS_FILE"; then
    if ask_user "Remove Proxmox Subscription Nag Message?"; then
        sed -i.bak "s|const subscription = !(!res || !res.data || res.data.status.toLowerCase() !== 'active');|const subscription = true;|g" "$JS_FILE"
        echo "Subscription Nag Message Removed."
    fi
fi

# 6 Restart Proxmox Web UI
if ask_user "Restart Proxmox Web UI now?"; then
    systemctl restart pveproxy
fi

# 7 Offer System Update
if ask_user "Update Proxmox VE now?"; then
    apt update && apt dist-upgrade -y
fi

# 8 Prompt for Reboot
if ask_user "Reboot now?"; then
    reboot
fi

echo "Proxmox Post-Install Setup Completed."
