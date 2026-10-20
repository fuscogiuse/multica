#!/usr/bin/env bash
# Calm Tasks on your Mac.
#
# Builds the self-hosted stack from this checkout (Docker), publishes the web
# app privately on your Tailscale network (reachable from your iPhone on any
# network, never from the public internet) and starts the agent daemon.
#
#   bash scripts/calm-mac.sh setup    first install, or after changing .env
#   bash scripts/calm-mac.sh code     print the latest login code
#   bash scripts/calm-mac.sh update   pull the latest code and rebuild
#   bash scripts/calm-mac.sh stop     stop everything
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

need() { command -v "$1" >/dev/null 2>&1; }
ts() {
  if need tailscale; then tailscale "$@"
  else /Applications/Tailscale.app/Contents/MacOS/Tailscale "$@"; fi
}
ts_url() {
  ts status --json | python3 -c 'import json,sys; print("https://" + json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))'
}
set_env() {
  if grep -q "^$1=" .env; then sed -i '' "s#^$1=.*#$1=$2#" .env; else echo "$1=$2" >> .env; fi
}
compose() { docker compose -f docker-compose.selfhost.yml -f docker-compose.selfhost.build.yml "$@"; }

check_tools() {
  [ "$(uname)" = "Darwin" ] || { echo "Questo script è pensato per macOS."; exit 1; }
  need docker || { echo "Installa Docker Desktop: https://www.docker.com/products/docker-desktop/"; exit 1; }
  docker info >/dev/null 2>&1 || { echo "Apri Docker Desktop, aspetta che sia avviato e riprova."; exit 1; }
  if ! need tailscale && [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
    echo "Installa Tailscale (https://tailscale.com/download/mac), accedi e riprova."; exit 1
  fi
  ts status >/dev/null 2>&1 || { echo "Tailscale non è connesso: aprilo e accedi."; exit 1; }
}

write_env() {
  local url=$1
  if [ ! -f .env ]; then
    cp .env.example .env
    set_env JWT_SECRET "$(openssl rand -hex 32)"
    local pg; pg=$(openssl rand -hex 24)
    set_env POSTGRES_PASSWORD "$pg"
    sed -i '' -E "s#^(DATABASE_URL=postgres://[^:]+:)[^@]*(@.*)#\1$pg\2#" .env
    set_env MULTICA_VCS_SECRET_KEY "$(openssl rand -base64 32)"
  fi
  set_env FRONTEND_ORIGIN "$url"
  set_env MULTICA_APP_URL "$url"
  set_env CORS_ALLOWED_ORIGINS "$url"
  set_env DO_NOT_TRACK 1
  set_env FF_PROJECT_WORKFLOWS_V1 true
}

case "${1:-setup}" in
setup)
  check_tools
  URL=$(ts_url)
  echo "==> Indirizzo privato: $URL"
  write_env "$URL"
  make selfhost-build
  ts serve --bg http://127.0.0.1:3000
  if ! need multica; then
    need brew || { echo "Installa Homebrew (https://brew.sh) per avviare gli agenti."; exit 1; }
    brew install multica-ai/tap/multica
  fi
  multica setup self-host --server-url http://localhost:8080 --app-url "$URL" || \
    echo "Agenti: lancia di nuovo 'multica setup self-host --server-url http://localhost:8080 --app-url $URL' dopo il primo accesso."
  cat <<EOF

Fatto. Apri $URL
  Mac:    Safari > File > Aggiungi al Dock
  iPhone: installa Tailscale, accedi con lo stesso account,
          apri il link in Safari > Condividi > Aggiungi a Home
Codice di accesso: bash scripts/calm-mac.sh code
EOF
  ;;
code)
  compose logs backend 2>/dev/null | grep -i "verification code" | tail -1 || echo "Nessun codice: prova prima ad accedere dalla pagina di login."
  ;;
update)
  check_tools
  git pull --ff-only
  write_env "$(ts_url)"
  make selfhost-build
  ;;
stop)
  compose down
  ts serve reset || true
  ;;
*)
  echo "uso: bash scripts/calm-mac.sh [setup|code|update|stop]"; exit 2
  ;;
esac
