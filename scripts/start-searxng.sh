#!/bin/bash
# Startup script for SearXNG
# Runs after Colima starts

sleep 10  # Wait for Colima to fully start

if ! docker ps | grep -q searxng; then
    docker start searxng 2>/dev/null || docker run -d -p 8888:8080 --name searxng --restart unless-stopped searxng/searxng:latest
fi
