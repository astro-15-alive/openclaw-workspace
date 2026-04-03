# How-To: Setup Goplaces Skill

## Overview
The goplaces skill enables OpenClaw to query Google Places API for location-based searches, place details, and reviews.

## Prerequisites

1. Google Cloud Project with Places API (New) enabled
2. API Key from Google Cloud Console

## Configuration

The goplaces skill is already configured in `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "goplaces": {
        "apiKey": "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"
      }
    }
  }
}
```

## Installation

```bash
# Install goplaces CLI if not already installed
clawhub list | grep goplaces

# If not found, install via clawhub
clawhub install goplaces
```

## Usage

### Text Search
```bash
# Search for places by text query
goplaces search "coffee shops near Melbourne CBD"

# Search with location bias
goplaces search "restaurants" --location "-37.8136,144.9631" --radius 1000
```

### Place Details
```bash
# Get detailed information about a place
goplaces details <place_id>

# Get place details with reviews
goplaces details <place_id> --include-reviews
```

### Place Resolution
```bash
# Resolve a place name to place ID
goplaces resolve "Sydney Opera House"
```

### Reviews
```bash
# Get reviews for a place
goplaces reviews <place_id> --limit 5
```

## Common Use Cases

### Find Nearby Places
```bash
# Find coffee shops within 500m of current location
goplaces search "coffee" --location "-37.8136,144.9631" --radius 500
```

### Get Business Hours
```bash
# Get opening hours for a specific place
goplaces details <place_id> --fields "opening_hours"
```

### Verify Address
```bash
# Verify and format an address
goplaces resolve "123 Main St, Melbourne"
```

## API Key Management

### Storing API Key Securely (Recommended)

Instead of hardcoding in config, use environment variable:

```bash
# Add to ~/.zshrc or ~/.bashrc
export GOOGLE_PLACES_API_KEY="your-api-key"

# Then reference in openclaw.json
{
  "skills": {
    "entries": {
      "goplaces": {
        "apiKey": "${GOOGLE_PLACES_API_KEY}"
      }
    }
  }
}
```

Or use 1Password:
```bash
goplaces search "query" --api-key $(op read "op://Private/Google Places API/credential")
```

## Troubleshooting

**"API key not valid" error:**
- Verify Places API (New) is enabled in Google Cloud Console
- Check API key restrictions (HTTP referrers, IP addresses)
- Ensure billing is enabled for the project

**"Quota exceeded" error:**
- Check quota limits in Google Cloud Console
- Consider implementing caching for repeated queries

**No results found:**
- Try broadening search terms
- Check location coordinates are correct (lat,lng format)
- Increase search radius

## Rate Limits

- Standard Google Places API (New) quotas apply
- Free tier: Limited requests per month
- Paid tier: Pay-per-use pricing

## Privacy Note

Location queries are sent to Google Places API. Consider:
- Using local LLM for general questions when location not needed
- Caching frequent queries to reduce API calls
- Being mindful of sharing precise location data

---
*Document created: 2026-03-15*
