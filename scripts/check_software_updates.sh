#!/bin/bash
# Software Update Script
# Checks and installs software updates, reports manual steps to Discord

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="/tmp/software_update_report.txt"

# Initialize report
echo "📦 **Software Update Report** — $(date '+%A, %B %d, %Y at %I:%M %p %Z')" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

AUTO_UPDATES_DONE=0
AUTO_UPDATES_FAILED=0
MANUAL_UPDATES=0
OPENCLAW_UPDATED=false
OLLAMA_UPDATED=false

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add to report
add_to_report() {
    echo "$1" >> "$REPORT_FILE"
}

# Check and update Homebrew
if command_exists brew; then
    add_to_report "**📦 Homebrew**"
    add_to_report ""
    
    # Update brew itself
    brew update >/dev/null 2>&1
    
    # Check for outdated packages
    OUTDATED=$(brew outdated 2>/dev/null || true)
    if [ -n "$OUTDATED" ]; then
        add_to_report "Outdated packages found:"
        add_to_report "\`\`\`"
        echo "$OUTDATED" >> "$REPORT_FILE"
        add_to_report "\`\`\`"
        add_to_report ""
        add_to_report "⬆️ **Running:** \`brew upgrade\`"
        add_to_report ""
        
        # Run brew upgrade
        if brew upgrade --quiet 2>&1 >> "$REPORT_FILE"; then
            add_to_report "✅ **Homebrew packages upgraded successfully**"
            AUTO_UPDATES_DONE=$((AUTO_UPDATES_DONE + 1))
        else
            add_to_report "❌ **Homebrew upgrade failed**"
            add_to_report "**To manually install:** \`brew upgrade\`"
            AUTO_UPDATES_FAILED=$((AUTO_UPDATES_FAILED + 1))
        fi
    else
        add_to_report "✅ All packages up to date"
    fi
    add_to_report ""
fi

# Check and update npm global packages
if command_exists npm; then
    add_to_report "**📦 npm (global packages)**"
    add_to_report ""
    
    # Check for outdated global packages
    OUTDATED=$(npm outdated -g 2>/dev/null || true)
    
    # Check if openclaw is in the outdated list
    if echo "$OUTDATED" | grep -q "openclaw"; then
        OPENCLAW_UPDATED=true
    fi
    
    if [ -n "$OUTDATED" ]; then
        add_to_report "Outdated global packages found:"
        add_to_report "\`\`\`"
        echo "$OUTDATED" >> "$REPORT_FILE"
        add_to_report "\`\`\`"
        add_to_report ""
        add_to_report "⬆️ **Running:** \`npm update -g\`"
        add_to_report ""
        
        # Run npm update
        if npm update -g 2>&1 >> "$REPORT_FILE"; then
            add_to_report "✅ **npm packages upgraded successfully**"
            AUTO_UPDATES_DONE=$((AUTO_UPDATES_DONE + 1))
        else
            add_to_report "❌ **npm upgrade failed**"
            add_to_report "**To manually install:** \`npm update -g\`"
            AUTO_UPDATES_FAILED=$((AUTO_UPDATES_FAILED + 1))
        fi
    else
        add_to_report "✅ All global packages up to date"
    fi
    add_to_report ""
fi

# Check and update Ollama
if command_exists ollama; then
    add_to_report "**🤖 Ollama**"
    add_to_report ""
    CURRENT_VERSION=$(ollama --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""
    add_to_report "⬆️ **Running Ollama installer to check for updates...**"
    add_to_report ""
    
    # Run Ollama install script to update
    if curl -fsSL https://ollama.com/install.sh | sh 2>&1 >> "$REPORT_FILE"; then
        NEW_VERSION=$(ollama --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
            add_to_report ""
            add_to_report "✅ **Ollama updated: $CURRENT_VERSION → $NEW_VERSION**"
            OLLAMA_UPDATED=true
        else
            add_to_report ""
            add_to_report "✅ **Ollama is already at latest version ($CURRENT_VERSION)**"
        fi
        AUTO_UPDATES_DONE=$((AUTO_UPDATES_DONE + 1))
    else
        add_to_report ""
        add_to_report "❌ **Ollama update failed**"
        add_to_report "**To manually update:** Download from https://ollama.com/download"
        AUTO_UPDATES_FAILED=$((AUTO_UPDATES_FAILED + 1))
    fi
    add_to_report ""
fi

# Restart OpenClaw gateway if it was updated
if [ "$OPENCLAW_UPDATED" = true ]; then
    add_to_report "**🔄 OpenClaw Gateway Restart**"
    add_to_report ""
    add_to_report "OpenClaw was updated. Scheduling gateway restart in 2 minutes..."
    add_to_report ""
    
    # Schedule restart for later so this script can finish and report to Discord
    if command_exists at; then
        echo "openclaw gateway restart" | at now + 2 minutes 2>/dev/null
        add_to_report "✅ **OpenClaw gateway restart scheduled (in 2 minutes)**"
    else
        # Fallback: background the restart with nohup
        (sleep 30 && openclaw gateway restart) &
        add_to_report "✅ **OpenClaw gateway restart scheduled (in 30 seconds)**"
    fi
    add_to_report ""
fi

# Summary
add_to_report "---"
add_to_report ""
if [ $AUTO_UPDATES_DONE -gt 0 ] && [ $AUTO_UPDATES_FAILED -eq 0 ]; then
    add_to_report "✅ **Summary:** $AUTO_UPDATES_DONE update(s) completed"
    [ "$OPENCLAW_UPDATED" = true ] && add_to_report "🔄 OpenClaw gateway restarted"
    [ "$OLLAMA_UPDATED" = true ] && add_to_report "🤖 Ollama updated"
elif [ $AUTO_UPDATES_DONE -gt 0 ] && [ $AUTO_UPDATES_FAILED -gt 0 ]; then
    add_to_report "⚠️ **Summary:** $AUTO_UPDATES_DONE updated, $AUTO_UPDATES_FAILED failed"
elif [ $AUTO_UPDATES_FAILED -gt 0 ]; then
    add_to_report "❌ **Summary:** $AUTO_UPDATES_FAILED update(s) failed"
else
    add_to_report "✅ **Summary:** All software is up to date"
fi

# Print report for cron output
cat "$REPORT_FILE"

# Always exit successfully - failures are reported in the output
exit 0