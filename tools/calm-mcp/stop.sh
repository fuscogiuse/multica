#!/usr/bin/env bash
# Emergency stop: closes the public entry and stops the connector.
TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
command -v tailscale >/dev/null 2>&1 && TS=tailscale
"$TS" funnel --https="${CALM_FUNNEL_PORT:-8443}" off || true
launchctl bootout "gui/$(id -u)/ai.calm-tasks.mcp" 2>/dev/null || true
echo "Connettore fermato e ingresso pubblico chiuso."
