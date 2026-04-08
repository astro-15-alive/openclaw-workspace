#!/bin/bash
# Startup script for SearXNG
# Runs after Colima starts

sleep 5  # Wait for Colima to fully start

if docker ps -a | grep -q searxng; then
    docker start searxng
else
    docker run -d \
        --name searxng \
        --restart unless-stopped \
        -p 8888:8080 \
        searxng/searxng:latest
fi
