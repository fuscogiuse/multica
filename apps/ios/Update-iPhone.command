#!/usr/bin/env bash
# Double-click to update Calm Tasks on your iPhone.
# Reads the Apple team id from ~/.calmtasks-team (one line), pulls the latest code, then installs.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f "$HOME/.calmtasks-team" ]; then
  echo "First run: write your Apple team id (Xcode > Settings > Accounts) into ~/.calmtasks-team"
  echo "Example: echo ABCDE12345 > ~/.calmtasks-team"
  read -r -p "Press Return to close." _
  exit 1
fi
TEAM="$(tr -d '[:space:]' < "$HOME/.calmtasks-team")"
export TEAM
git pull --ff-only || echo "Could not pull. Continuing with the code on disk."
if ./build-device.sh; then
  echo "Done. Calm Tasks is updated on your iPhone."
else
  echo "The install failed. Is the iPhone unlocked and on the same Wi-Fi as this Mac?"
fi
read -r -p "Press Return to close." _
