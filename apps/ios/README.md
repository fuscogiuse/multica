# Calm Tasks for iPhone

Native SwiftUI app for Calm Tasks, the Calm UI fork of Multica. It reads and writes the self-hosted Multica API over Tailscale. iPhone only, portrait, mobile first. Based on Multica.

Plan and decisions: [docs/calm-ios/PLAN.md](../../docs/calm-ios/PLAN.md).

## What it does

- Login with the server address and an email code.
- Tabs: Oggi, Task, Progetti, Altro, with a floating "+" for a new task.
- Lista and Kanban per project. The columns come from the project's workflow, in the workflow's order. Projects on the Default workflow, and the all-tasks view, use the status catalog.
- Move a task with a swipe (done), a long press ("Sposta in…") or a drag onto a column.
- Task detail: title, status, priority, due date, notes, comments.
- Live refresh through the server websocket, and pull to refresh.
- "Colonne" opens the web workflow editor in Safari. Columns are not edited natively.

## Layout

```
project.yml              XcodeGen spec (CalmCore framework, CalmTasks app, CalmCoreTests)
Sources/CalmCore/        API client, models, board logic, store, websocket (no UI)
Sources/CalmTasks/       SwiftUI screens
Tests/CalmCoreTests/     unit tests; Fixtures/ holds sanitised API responses
build-device.sh          sign with a Personal Team and install on a connected iPhone
Update-iPhone.command    double-click wrapper around build-device.sh
```

The `.xcodeproj` is generated and never committed.

## Build and test: GitHub Actions only

The `iOS` workflow (`.github/workflows/ios.yml`) generates the project, runs the unit tests, builds for the simulator, and uploads two artifacts:

- `CalmTasks-simulator`: the simulator build.
- `screenshots`: screens rendered with built-in demo data (launch argument `-demo`).

Do not build on the Mac for development. The only local compile is the install on your own phone.

## Install on the iPhone (free Personal Team)

One-time setup:

1. Install Xcode and XcodeGen (`brew install xcodegen`).
2. Sign in to Xcode with your Apple ID (Xcode, Settings, Accounts) and note your team id.
3. Write the team id into `~/.calmtasks-team`: `echo ABCDE12345 > ~/.calmtasks-team`.
4. Plug the iPhone in once, trust the Mac, and enable Developer Mode on the phone.
5. In Xcode, Window, Devices and Simulators, select the phone and tick "Connect via network".

Every update after that: double-click `Update-iPhone.command`. The phone must be unlocked and on the same Wi-Fi as the Mac.

A free Personal Team build expires after 7 days. Run the same double-click again to renew it.

First launch on the phone: Settings, General, VPN & Device Management, trust your developer certificate.

## Server address and login

Enter the Tailscale address of the Mac, for example `your-mac.your-tailnet.ts.net`. HTTPS is required (plain HTTP only works for `localhost`). The self-hosted server prints the login code in its log instead of sending an email:

```bash
docker logs multica-backend-1 2>&1 | grep "Verification code" | tail -1
```

## Demo mode

`-demo` loads sample data and skips the network. The screenshot job uses it. The launch arguments `-calm.tab <0-3>`, `-calm.view <list|kanban>` and `-calm.openProject <id>` pick the screen.

## Known limits

- The Mac must be on, with Docker and Tailscale running. Tailscale must also be connected on the phone.
- No offline writes. A failed change is rolled back and shown in an alert.
- Workflows and columns are edited on the web, not in the app.
