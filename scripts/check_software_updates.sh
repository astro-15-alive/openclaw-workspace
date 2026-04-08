#!/bin/bash
# Software Update Checker
# Checks for software updates only - never auto-updates
# Reports commands to run for manual updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_FILE="/tmp/software_update_report.txt"

# Initialize report
echo "📦 **Software Update Report** — $(date '+%A, %B %d, %Y at %I:%M %p %Z')" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

UPDATES_AVAILABLE=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add to report
add_to_report() {
    echo "$1" >> "$REPORT_FILE"
}

# Check Node.js
if command_exists node; then
    add_to_report "**🟢 Node.js**"
    add_to_report ""
    CURRENT_VERSION=$(node --version 2>/dev/null || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""

    # Get latest (non-LTS) version
    LATEST=$(curl -s --connect-timeout 5 "https://nodejs.org/dist/index.json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['version'])" 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ "$CURRENT_VERSION" != "$LATEST" ]; then
        add_to_report "⚠️ Update available: \`$CURRENT_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`brew upgrade node\` or see https://nodejs.org"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$CURRENT_VERSION\`)"
        add_to_report ""
    fi
fi

# Check Python
if command_exists python3; then
    add_to_report "**🐍 Python**"
    add_to_report ""
    CURRENT_VERSION=$(python3 --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""

    LATEST=$(curl -s --connect-timeout 5 "https://endoflife.date/api/python.json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['latest'])" 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ "$CURRENT_VERSION" != "$LATEST" ]; then
        add_to_report "⚠️ Update available: \`$CURRENT_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`brew upgrade python\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$CURRENT_VERSION\`)"
        add_to_report ""
    fi
fi

# Check Go
if command_exists go; then
    add_to_report "**🔵 Go**"
    add_to_report ""
    CURRENT_VERSION=$(go version 2>/dev/null | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""

    LATEST=$(curl -s --connect-timeout 5 "https://go.dev/dl/?mode=json" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['version'])" 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ "$CURRENT_VERSION" != "$LATEST" ]; then
        add_to_report "⚠️ Update available: \`$CURRENT_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`brew upgrade go\` or see https://go.dev/dl/"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$CURRENT_VERSION\`)"
        add_to_report ""
    fi
fi

# Check Docker
if command_exists docker; then
    add_to_report "**🐳 Docker**"
    add_to_report ""
    CURRENT_VERSION=$(docker --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""
    add_to_report "Updates via Docker Desktop app (check ⚙️ → Settings → General)"
    add_to_report ""
fi

# Check macOS system updates
add_to_report "**🍎 macOS**"
add_to_report ""
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
add_to_report "Current version: \`$MACOS_VERSION\`"
SYSTEM_UPDATES=$(softwareupdate --list 2>&1 | grep -c "\*" || echo "0")
if [ "$SYSTEM_UPDATES" -gt 0 ]; then
    add_to_report "⚠️ $SYSTEM_UPDATES system update(s) available"
    add_to_report "**To update:** \`sudo softwareupdate -i -a\`"
    add_to_report ""
    UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
else
    add_to_report "✅ No system updates available"
    add_to_report ""
fi

# Check Colima
if command_exists colima; then
    add_to_report "**🦺 Colima**"
    add_to_report ""
    COLIMA_VERSION=$(colima version 2>/dev/null | grep "version" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    add_to_report "Current version: \`$COLIMA_VERSION\`"
    LATEST=$(curl -s --connect-timeout 5 "https://api.github.com/repos/abiosoft/colima/releases/latest" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tag_name','$COLIMA_VERSION').lstrip('v'))" 2>/dev/null || echo "$COLIMA_VERSION")
    if [ "$LATEST" != "" ] && [ "$LATEST" != "$COLIMA_VERSION" ]; then
        add_to_report "⚠️ Update available: \`$COLIMA_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`brew upgrade colima\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$COLIMA_VERSION\`)"
        add_to_report ""
    fi
fi

# Check Homebrew
if command_exists brew; then
    add_to_report "**📦 Homebrew**"
    add_to_report ""

    OUTDATED=$(brew outdated 2>/dev/null || true)
    if [ -n "$OUTDATED" ]; then
        add_to_report "⚠️ Updates available:"
        add_to_report "\`\`\`"
        echo "$OUTDATED" >> "$REPORT_FILE"
        add_to_report "\`\`\`"
        add_to_report "**To update:** \`brew upgrade\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ All packages up to date"
        add_to_report ""
    fi
fi

# Check npm global packages
if command_exists npm; then
    add_to_report "**📦 npm (global packages)**"
    add_to_report ""

    OUTDATED=$(npm outdated -g 2>/dev/null || true)
    if [ -n "$OUTDATED" ]; then
        add_to_report "⚠️ Updates available:"
        add_to_report "\`\`\`"
        echo "$OUTDATED" >> "$REPORT_FILE"
        add_to_report "\`\`\`"
        add_to_report "**To update:** \`npm update -g\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ All global packages up to date"
        add_to_report ""
    fi
fi

# Check Ollama
if command_exists ollama; then
    add_to_report "**🤖 Ollama**"
    add_to_report ""

    CURRENT_VERSION=$(ollama --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""

    LATEST=$(curl -s "https://api.ollama.ai/version" 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "")
    if [ -n "$LATEST" ] && [ "$CURRENT_VERSION" != "$LATEST" ]; then
        add_to_report "⚠️ Update available: \`$CURRENT_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`curl -fsSL https://ollama.com/install.sh | sh\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$CURRENT_VERSION\`)"
        add_to_report ""
    fi
fi

# Check LM Studio
LM_STUDIO_APP="/Applications/LM Studio.app"
if [ -d "$LM_STUDIO_APP" ]; then
    add_to_report "**🖥️ LM Studio**"
    add_to_report ""

    CURRENT_VERSION=$(mdls -name kMDItemVersion "$LM_STUDIO_APP" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"' || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""
    add_to_report "Updates via the app (check the app for new versions)"
    add_to_report ""
fi

# Check OpenClaw
if command_exists openclaw; then
    add_to_report "**🦞 OpenClaw**"
    add_to_report ""

    CURRENT_VERSION=$(openclaw --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    add_to_report "Current version: \`$CURRENT_VERSION\`"
    add_to_report ""

    LATEST=$(npm show openclaw version 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ "$CURRENT_VERSION" != "$LATEST" ]; then
        add_to_report "⚠️ Update available: \`$CURRENT_VERSION\` → \`$LATEST\`"
        add_to_report "**To update:** \`npm update -g openclaw\`"
        add_to_report ""
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        add_to_report "✅ Already at latest version (\`$CURRENT_VERSION\`)"
        add_to_report ""
    fi
fi

# Summary
add_to_report "---"
add_to_report ""
if [ $UPDATES_AVAILABLE -gt 0 ]; then
    add_to_report "⚠️ **Summary:** $UPDATES_AVAILABLE software update(s) available"
    add_to_report ""
    add_to_report "Run the commands above to update each package."
else
    add_to_report "✅ **Summary:** All software is up to date"
fi

# Print report for cron output
cat "$REPORT_FILE"

exit 0
