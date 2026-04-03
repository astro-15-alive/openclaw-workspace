#!/bin/bash

# Export Apple Reminders to JSON file for local models to read
# Usage: export_reminders.sh [list_name]

OUTPUT_DIR="/Users/keenaben/.openclaw/workspace/reminders_export"
mkdir -p "$OUTPUT_DIR"

LIST_NAME="${1:-all}"
TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S%z")
OUTPUT_FILE="$OUTPUT_DIR/reminders_${LIST_NAME}_$(date +%Y%m%d_%H%M%S).json"

echo "{"
echo "  \"exported_at\": \"$TIMESTAMP\","
echo "  \"lists\": {"

if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "astro" ]; then
    echo "    \"astro\": {"
    echo "      \"name\": \"astro\","
    echo "      \"tasks\": ["
    remindctl list astro --format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read task; do
        echo "        $task,"
    done
    echo "      ]"
    echo "    },"
fi

if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "bk" ]; then
    echo "    \"bk\": {"
    echo "      \"name\": \"bk\","
    echo "      \"tasks\": ["
    remindctl list bk --format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read task; do
        echo "        $task,"
    done
    echo "      ]"
    echo "    },"
fi

if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "shares" ]; then
    echo "    \"shares\": {"
    echo "      \"name\": \"shares\","
    echo "      \"tasks\": ["
    remindctl list shares --format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read task; do
        echo "        $task,"
    done
    echo "      ]"
    echo "    },"
fi

if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "business" ]; then
    echo "    \"business\": {"
    echo "      \"name\": \"business\","
    echo "      \"tasks\": ["
    remindctl list business --format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read task; do
        echo "        $task,"
    done
    echo "      ]"
    echo "    },"
fi

if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "longevity" ]; then
    echo "    \"longevity\": {"
    echo "      \"name\": \"longevity\","
    echo "      \"tasks\": ["
    remindctl list longevity --format json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read task; do
        echo "        $task,"
    done
    echo "      ]"
    echo "    }"
fi

echo "  }"
echo "}"

# Also create a simple text version for easy reading
echo ""
echo "=== REMINDERS EXPORT ===" > "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
echo "Exported: $TIMESTAMP" >> "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
echo "" >> "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"

for list in astro bk shares business longevity; do
    if [ "$LIST_NAME" = "all" ] || [ "$LIST_NAME" = "$list" ]; then
        echo "## $list" >> "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
        remindctl list "$list" 2>/dev/null >> "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
        echo "" >> "$OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
    fi
done

echo "Exported to: $OUTPUT_DIR/reminders_${LIST_NAME}_latest.txt"
