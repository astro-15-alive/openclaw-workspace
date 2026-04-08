#!/bin/bash
# Daily Briefing Script
# Compiles morning briefing with weather, balances, BTC, AI news

source ~/.openclaw/secrets.env 2>/dev/null

TODAY=$(date '+%A, %B %d, %Y')

# --- Weather ---
WEATHER=$(curl -s --connect-timeout 5 "wttr.in/Baranduda?format=j1" 2>/dev/null)
if [ -n "$WEATHER" ]; then
    MIN_TEMP=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['mintempC'])")
    MAX_TEMP=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['maxtempC'])")
    RAIN_CHANCE=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['hourly'][4]['chanceofrain'])" 2>/dev/null || echo "0")
    RAIN_AMOUNT=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['hourly'][4]['precipMM'])" 2>/dev/null || echo "0")
    WEATHER_BLOCK="🌤️ **Weather Forecast for Baranduda**
• Min: ${MIN_TEMP}°C | Max: ${MAX_TEMP}°C
• Rain: ${RAIN_CHANCE}% (${RAIN_AMOUNT}mm)
"
else
    WEATHER_BLOCK="🌤️ **Weather Forecast for Baranduda**
• ⚠️ Weather data unavailable
"
fi

# --- OpenRouter Balance ---
OPENROUTER_BLOCK="🧠 **OpenRouter Balance**
• Balance: check openrouter.ai"
if command -v openrouter &>/dev/null; then
    OR_BALANCE=$(openrouter models --json 2>/dev/null | python3 -c "import sys; print('see openrouter.ai')" 2>/dev/null || echo "check dashboard")
    OPENROUTER_BLOCK="🧠 **OpenRouter Balance**
• Balance: $OR_BALANCE"
fi

# --- XAI Usage ---
XAI_BLOCK="[XAI script output]"
if [ -f ~/.openclaw/workspace/scripts/track_xai_usage.sh ]; then
    XAI_BLOCK=$(~/.openclaw/workspace/scripts/track_xai_usage.sh 2>/dev/null | grep -v "^$" | head -3 | sed 's/^/• /' || echo "[XAI data unavailable]")
fi

# --- Bitcoin ---
BTC=$(curl -s --connect-timeout 5 "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=aud,usd" 2>/dev/null)
if [ -n "$BTC" ]; then
    BTC_AUD=$(echo "$BTC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"\${d['bitcoin']['aud']:,}\")")
    BTC_USD=$(echo "$BTC" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"\${d['bitcoin']['usd']:,}\")")
    BTC_BLOCK="₿ **Bitcoin Prices**
• BTC-AUD: $BTC_AUD
• BTC-USD: $BTC_USD
"
else
    BTC_BLOCK="₿ **Bitcoin Prices**
• ⚠️ Price data unavailable
"
fi

# --- AI News ---
NEWS=$(curl -s --connect-timeout 8 "http://localhost:8888/search?q=AI&categories=news&format=json" 2>/dev/null)
if [ -n "$NEWS" ]; then
    NEWS1=$(echo "$NEWS" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('results',[]); print(f\"{r[0]['title']}\n{r[0]['url']}\")" 2>/dev/null || echo "• Could not fetch news")
    NEWS2=$(echo "$NEWS" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('results',[]); print(f\"{r[1]['title']}\n{r[1]['url']}\")" 2>/dev/null || echo "• Could not fetch news")
    NEWS_BLOCK="📰 **Top AI News**
$(echo "$NEWS1" | sed 's/^/"/')
$(echo "$NEWS2" | sed 's/^/"/')"
else
    NEWS_BLOCK="📰 **Top AI News**
⚠️ Search unavailable - localhost:8888 not responding"
fi

# --- Output ---
echo "🌅 **Morning Brief** - $TODAY"
echo ""
echo "$WEATHER_BLOCK"
echo ""
echo "$OPENROUTER_BLOCK"
echo ""
echo "**XAI Usage:**
$xAI_BLOCK"
echo ""
echo "$BTC_BLOCK"
echo ""
echo "$NEWS_BLOCK"
