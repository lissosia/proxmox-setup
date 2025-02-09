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

log_success() {
    echo -e "[OK] $1"
}

log_failure() {
    echo -e "[FAIL] $1"
}

log_skip() {
    echo -e "[SKIP] $1"
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
            log_success "Added repository: $repo"
        else
            log_skip "Repository already present: $repo"
        fi
    done
else
    log_skip "Skipped correcting Proxmox VE sources."
fi

# 2 Disable Proxmox Enterprise Repository
PVE_ENTERPRISE_FILE="/etc/apt/sources.list.d/pve-enterprise.list"
if [ -f "$PVE_ENTERPRISE_FILE" ] && grep -q "^deb https://enterprise.proxmox.com/debian" "$PVE_ENTERPRISE_FILE"; then
    if ask_user "Disable Proxmox Enterprise Repository?"; then
        sed -i.bak -E "s|^[[:space:]]*deb https://enterprise.proxmox.com/debian|#&|" "$PVE_ENTERPRISE_FILE"
        if [ $? -eq 0 ]; then
            log_success "Disabled Proxmox Enterprise Repository."
        else
            log_failure "Failed to disable Proxmox Enterprise Repository."
        fi
    fi
else
    log_skip "Proxmox Enterprise Repository is already disabled."
fi

# 3 Enable No-Subscription Repository
PVE_REPO_FILE="/etc/apt/sources.list.d/pve-install-repo.list"
PVE_REPO_LINE="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"

if ask_user "Enable No-Subscription Repository?"; then
    if [ ! -f "$PVE_REPO_FILE" ] || ! contains_line "$PVE_REPO_LINE" "$PVE_REPO_FILE"; then
        echo "$PVE_REPO_LINE" > "$PVE_REPO_FILE"
        log_success "Enabled No-Subscription Repository."
    else
        log_skip "No-Subscription Repository already enabled."
    fi
else
    log_skip "Skipped enabling No-Subscription Repository."
fi

# 4 Fix Ceph Repository
CEPH_REPO_FILE="/etc/apt/sources.list.d/ceph.list"
CEPH_NO_SUB_LINE="deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription"

if ask_user "Fix Ceph Repository?"; then
    if [ ! -f "$CEPH_REPO_FILE" ] || ! contains_line "$CEPH_NO_SUB_LINE" "$CEPH_REPO_FILE"; then
        echo "$CEPH_NO_SUB_LINE" > "$CEPH_REPO_FILE"
        log_success "Configured Ceph No-Subscription Repository."
    else
        log_skip "Ceph No-Subscription Repository is already configured."
    fi
else
    log_skip "Skipped fixing Ceph Repository."
fi

# 5 Remove Subscription Nag Message
JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
if grep -q "const subscription" "$JS_FILE"; then
    if ask_user "Remove Proxmox Subscription Nag Message?"; then
        sed -i.bak -E "s|const subscription = !\(!res \|\| !res.data \|\| res.data.status.toLowerCase\(\) !== 'active'\);|const subscription = true;|g" "$JS_FILE"
        if grep -q "const subscription = true;" "$JS_FILE"; then
            log_success "Subscription Nag Message Removed."
        else
            log_failure "Failed to remove Subscription Nag Message."
        fi
    fi
else
    log_skip "Subscription Nag Message is already removed."
fi

# 6 Restart Proxmox Web UI
if ask_user "Restart Proxmox Web UI now?"; then
    echo "Restarting Proxmox Web UI..."
    systemctl restart pveproxy && sleep 3
    clear
    if [ $? -eq 0 ]; then
        log_success "Proxmox Web UI restarted successfully."
    else
        log_failure "Failed to restart Proxmox Web UI."
    fi
else
    log_skip "Skipped Proxmox Web UI restart."
fi

# 7 Offer System Update
if ask_user "Update Proxmox VE now?"; then
    apt update && apt dist-upgrade -y
    if [ $? -eq 0 ]; then
        log_success "Proxmox VE updated successfully."
    else
        log_failure "Failed to update Proxmox VE."
    fi
else
    log_skip "Skipped updating Proxmox VE."
fi

# 8 Prompt for Reboot
if ask_user "Reboot now?"; then
    reboot
else
    log_skip "Skipped system reboot."
fi

echo "Proxmox Post-Install Setup Completed."
