#!/bin/bash
# Weekly Security Audit Script
# Run from ~/.openclaw/workspace/scripts/security_audit.sh

REPORT_DATE=$(date '+%A, %B %d, %Y at %I:%M %p %Z')
HOSTNAME=$(hostname)
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")

# Initialize report
REPORT=""
REPORT+="🔒 **Security Audit Report** — $REPORT_DATE\n"
REPORT+="\n"
REPORT+="📍 **Host:** $HOSTNAME\n"
REPORT+="🖥️ **macOS:** $OS_VERSION\n"
REPORT+="\n"

# Section 1: System Updates
REPORT+="**1️⃣ System Software Updates**\n"
if command -v softwareupdate &> /dev/null; then
    UPDATES=$(softwareupdate -l 2>&1)
    if echo "$UPDATES" | grep -q "No new software available"; then
        REPORT+="✅ No system updates available\n"
    else
        UPDATE_COUNT=$(echo "$UPDATES" | grep -c "\*" || echo "0")
        REPORT+="⚠️ $UPDATE_COUNT system update(s) available\n"
        REPORT+="\`\`\`\n"
        # Extract all update labels with details
        REPORT+=$(echo "$UPDATES" | grep -A 1 "\*" | grep -v "^--$" | head -20)
        REPORT+="\n\`\`\`\n"
        # Check for recommended/restart required
        if echo "$UPDATES" | grep -q "restart"; then
            REPORT+="🔄 **Note:** Some updates require restart\n"
        fi
    fi
else
    REPORT+="⚠️ softwareupdate not available\n"
fi
REPORT+="\n"

# Section 2: Open Ports
REPORT+="**2️⃣ Network Ports**\n"
LISTENING_PORTS=$(netstat -an -p tcp 2>/dev/null | grep LISTEN | wc -l | xargs)
REPORT+="🌐 Listening TCP ports: $LISTENING_PORTS\n"
if [ "$LISTENING_PORTS" -gt 0 ]; then
    REPORT+="\`\`\`\n"
    REPORT+=$(netstat -an -p tcp 2>/dev/null | grep LISTEN | head -5)
    REPORT+="\n\`\`\`\n"
fi
REPORT+="\n"

# Section 3: User Accounts
REPORT+="**3️⃣ User Accounts**\n"
ADMIN_USERS=$(dscl . list /Groups/admin GroupMembership 2>/dev/null | tr ' ' '\n' | grep -v GroupMembership | sort -u | tr '\n' ',' | sed 's/,$//')
REPORT+="👤 Admin users: $ADMIN_USERS\n"
REPORT+="\n"

# Section 4: FileVault Encryption
REPORT+="**4️⃣ Disk Encryption**\n"
FILEVAULT_STATUS=$(fdesetup status 2>&1)
if echo "$FILEVAULT_STATUS" | grep -q "FileVault is On"; then
    REPORT+="✅ FileVault: Enabled\n"
else
    REPORT+="⚠️ FileVault: Not enabled\n"
fi
REPORT+="\n"

# Section 5: Firewall
REPORT+="**5️⃣ Firewall Status**\n"
FIREWALL_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1)
if echo "$FIREWALL_STATE" | grep -q "enabled"; then
    REPORT+="✅ Firewall: Enabled\n"
    # Get additional firewall settings
    ALLOW_SIGNED=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>&1 | head -1)
    REPORT+="   • $ALLOW_SIGNED\n"
else
    REPORT+="⚠️ Firewall: Not enabled\n"
fi
REPORT+="\n"

# Section 6: Disk Usage
REPORT+="**6️⃣ Disk Usage**\n"
DISK_USAGE=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
REPORT+="💾 Root disk usage: ${DISK_USAGE}%\n"
if [ "$DISK_USAGE" -gt 90 ]; then
    REPORT+="🚨 **Critical:** Disk usage above 90%\n"
elif [ "$DISK_USAGE" -gt 80 ]; then
    REPORT+="⚠️ **Warning:** Disk usage above 80%\n"
else
    REPORT+="✅ Disk usage healthy\n"
fi
REPORT+="\n"

# Section 7: Failed Login Attempts
REPORT+="**7️⃣ Failed Authentication Attempts (Last 24h)**\n"
FAILED_LOGS=$(log show --predicate 'eventMessage contains "authentication failure" OR eventMessage contains "Failed to authenticate" OR eventMessage contains "failed"' --last 24h 2>/dev/null)
FAILED_COUNT=$(echo "$FAILED_LOGS" | grep -v "^$" | wc -l | xargs)
if [ "$FAILED_COUNT" -eq 0 ]; then
    REPORT+="✅ No failed login attempts in last 24h\n"
else
    REPORT+="⚠️ $FAILED_COUNT failed authentication event(s) in last 24h\n"
    REPORT+="\`\`\`\n"
    # Show timestamp, process, and message for each failure
    REPORT+=$(echo "$FAILED_LOGS" | grep -E "(timestamp|authentication|failed)" | head -10)
    REPORT+="\n\`\`\`\n"
fi
REPORT+="\n"

# Section 8: World-writable files in critical directories
REPORT+="**8️⃣ World-Writable Files**\n"
WORLD_WRITABLE=$(find /usr/local/bin /usr/local/sbin /opt/homebrew/bin ~/.openclaw -type f -perm -002 2>/dev/null | wc -l | xargs)
if [ "$WORLD_WRITABLE" -eq 0 ]; then
    REPORT+="✅ No world-writable files found in critical paths\n"
else
    REPORT+="⚠️ $WORLD_WRITABLE world-writable file(s) found\n"
fi
REPORT+="\n"

# Section 9: SSH Configuration
REPORT+="**9️⃣ SSH Configuration**\n"
if [ -f ~/.ssh/config ]; then
    SSH_PERMS=$(ls -l ~/.ssh/config 2>/dev/null | awk '{print $1}')
    REPORT+="🔑 SSH config permissions: $SSH_PERMS\n"
    if echo "$SSH_PERMS" | grep -q "rw-------"; then
        REPORT+="✅ SSH config permissions are secure\n"
    else
        REPORT+="⚠️ SSH config may have overly permissive permissions\n"
    fi
else
    REPORT+="ℹ️ No SSH config file found\n"
fi
REPORT+="\n"

# Summary
REPORT+="---\n"
REPORT+="✅ **Audit Complete** — Review any ⚠️ warnings above\n"

echo -e "$REPORT"
