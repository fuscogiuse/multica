#!/usr/bin/env bash
# Calm Tasks MCP connector: one-time setup.
#
# Asks for a personal access token (created in the app: Settings > Tokens),
# generates the connector key, installs a LaunchAgent that keeps the server
# running, and publishes only the connector through Tailscale Funnel.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ENV_FILE="$HOME/.multica/calm-mcp.env"
PLIST="$HOME/Library/LaunchAgents/ai.calm-tasks.mcp.plist"
PORT="${CALM_MCP_PORT:-8765}"
FUNNEL_PORT="${CALM_FUNNEL_PORT:-8443}"
TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
command -v tailscale >/dev/null 2>&1 && TS=tailscale

mkdir -p "$HOME/.multica"
if [ ! -f "$ENV_FILE" ]; then
  printf "Incolla il token personale di Calm Tasks (non viene mostrato): "
  read -rs TOKEN; echo
  [ -n "$TOKEN" ] || { echo "Token vuoto."; exit 1; }
  KEY=$(openssl rand -hex 32)
  umask 077
  cat > "$ENV_FILE" <<ENV
CALM_API_URL=http://127.0.0.1:8080
CALM_WORKSPACE_SLUG=${CALM_WORKSPACE_SLUG:-solid}
CALM_TOKEN=$TOKEN
CALM_MCP_KEY=$KEY
CALM_MCP_PORT=$PORT
ENV
  chmod 600 "$ENV_FILE"
fi

[ -d node_modules ] || npm install --silent

NODE=$(command -v node)
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>ai.calm-tasks.mcp</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>-c</string>
    <string>set -a; . "$ENV_FILE"; set +a; exec "$NODE" "$PWD/server.mjs"</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$HOME/.multica/calm-mcp.err.log</string>
</dict></plist>
PL
launchctl bootout "gui/$(id -u)/ai.calm-tasks.mcp" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
sleep 2
curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null && echo "Server attivo su 127.0.0.1:$PORT"

"$TS" funnel --bg --https="$FUNNEL_PORT" "http://127.0.0.1:$PORT"
HOST=$("$TS" status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
echo
echo "Connettore pronto."
echo "  URL:    https://$HOST:$FUNNEL_PORT/mcp"
echo "  Chiave: in $ENV_FILE (CALM_MCP_KEY)"
