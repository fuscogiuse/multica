# Calm Tasks for iPhone: native app plan

Status: draft for approval. No code is part of this plan.
Date: 2026-10-20. Branch: `calm-ios-plan`. Base: `calm-ui`.

Goal: a native SwiftUI iPhone app for Calm Tasks (the Calm UI fork of Multica) that shows companies, projects, workflow columns and tasks, with a List view and a Kanban view. It talks to the self-hosted Multica API over Tailscale. It is built with the same method as GrokPe (`apps/ios` in the GrokPe repo): SwiftUI, XcodeGen `project.yml`, `build-device.sh`, free Personal Team signing.

The work is split into small tasks. Each task runs as its own background Claude Code session, started by the Grok Bot "App & Tools" (the orchestrator). Sessions write code and open pull requests. They never build or test on the Mac. GitHub Actions does that.

## 1. Rules

1. Everything on GitHub is in English: code, comments, commits, branches, PRs, this file. App UI strings are Italian.
2. Never build, compile, test or lint on the Mac. This means no `xcodebuild`, `swift build`, `swift test`, `xcodegen`, `pnpm build`, `npm test`, `make`. Only edit files, use git, and read CI with `gh`.
3. Every task works on its own branch and ends with a PR. No direct pushes to `calm-ios` or `calm-ui`.
4. Never commit `.env`, tokens, passwords, provisioning profiles or the `.xcodeproj` (CI and `build-device.sh` generate it with XcodeGen).
5. Keep the Multica name, logo and the "basato su Multica" credit in the app (Settings screen, About line).
6. No public exposure. The app talks only to the Tailscale address, over HTTPS. No TLS bypass, no HTTP except `localhost` for simulator fixtures.
7. Outputs (screenshots, exports, reports) go to Drive, not to git. Files over 5 MB are never committed.
8. No message is sent to anyone on Giuseppe's behalf by any session or by the bot without his explicit consent.

## 2. Decisions to confirm before Phase 1

| # | Decision | Recommendation |
|---|---|---|
| D1 | Where the code lives | `apps/ios/` in this repo (`fuscogiuse/multica`). Same repo as the API it consumes, shared CI, one place for fixtures. |
| D2 | Branch model | Integration branch `calm-ios`, cut from `calm-ui`. Each task branch `ios/T<nn>-<slug>` is cut from `calm-ios` and merged into it by PR. One final PR `calm-ios` into `calm-ui`. |
| D3 | Upstream mobile app | Upstream already ships `apps/mobile` (Expo / React Native). The request is SwiftUI, so this plan does not use it. It stays a fallback if the native app proves too slow to build. |
| D4 | How the app reaches the iPhone | See section 2.1. Recommendation: TestFlight with the paid developer account. |
| D5 | Signing | The free Personal Team expires every 7 days and needs a Mac build for each install. The paid account (99 EUR/year) removes both limits. |
| D6 | Auth | Email code login: `POST /auth/send-code` then `POST /auth/verify-code`. The self-hosted server prints the code in its log (`[DEV] Verification code`), so there is no email. After login, the app stores the JWT in the Keychain. Phase 2 evaluates a personal access token (`POST /api/tokens`, `mul_` prefix) to avoid re-login. |
| D7 | Workspace | One workspace (`solid`). The app sends `X-Workspace-ID` on every request. |
| D8 | Bundle prefix | `it.calmtasks.<user>` for the Personal Team (free teams need unique bundle ids). |

### 2.1 Updating the app without plugging in the phone

| Option | Cost | How an update arrives | Mac compile needed | Limits |
|---|---|---|---|---|
| A. TestFlight (recommended) | 99 EUR/year | CI builds and uploads. The iPhone offers the update by itself, no cable. | No | One-time setup of an App Store Connect API key and signing as GitHub secrets, done by Giuseppe. Builds last 90 days. |
| B. Free Personal Team, wireless install | 0 | Giuseppe runs `build-device.sh`. After a one-time cable pairing it can install over Wi-Fi. | Yes, every update | Breaks the "no builds on the Mac" rule. Expires after 7 days. The phone must be unlocked and on the same network. |
| C. Free account with AltStore or SideStore | 0 | CI publishes an unsigned `.ipa`. AltStore re-signs and refreshes it on the phone over Wi-Fi. | No | Needs AltServer running on the Mac. Weekly refresh. Not verified in this setup. |

Option A is the only one that matches "install once, then it updates itself". Phase 1 gets two extra tasks for it (T13 and T14). Until the account exists, option C or B can carry the first builds.

Mobile first means the iPhone is the only target. iPad and Mac layouts are out of scope.

## 3. Architecture

```
apps/ios/
  project.yml                 XcodeGen spec (targets CalmCore, CalmTasks, CalmCoreTests)
  build-device.sh             sign with Personal Team and install on a connected iPhone
  Sources/
    CalmCore/                 framework: no UI
      API/                    APIClient, Endpoints, Auth, WebSocketClient
      Models/                 Codable models and a tolerant decoder
      Store/                  BoardStore, WorkflowResolver, Keychain
    CalmTasks/                app target
      App/                    entry point, navigation, theme (calm palette)
      Screens/                Onboarding, Home, Board (List + Kanban), TaskDetail, NewTask, Today, Settings
  Tests/CalmCoreTests/        XCTest with JSON fixtures
  Fixtures/                   recorded API responses (sanitised)
```

Rules for the app code:

- Statuses come from `GET /api/issue-statuses`. Names, colours and order are never hard coded. The Italian names already live in the catalog.
- Columns come from the project workflow when `project_workflows_v1` is on, exactly as the web Calm UI does in `packages/views/calm/shared.tsx` (`useBoard`): workflow steps in workflow order, no `closed` category column, Default workflow and "all projects" view use the catalog order, hidden columns respected.
- A task whose status is not a column goes into the first column of the same category.
- Decoding is tolerant: unknown keys are ignored and a missing optional key never fails a whole list.
- Reading is open, writing is explicit: the app only changes a task through `PUT /api/issues/{id}` (status, title, priority, due date) and `POST /api/issues`.

API surface used (all under `/api`, headers `Authorization: Bearer <token>` and `X-Workspace-ID`):

| Need | Endpoint |
|---|---|
| Config and flags | `GET /api/config` |
| Login | `POST /auth/send-code`, `POST /auth/verify-code` |
| Workspaces | `GET /api/workspaces` |
| Companies | `GET /api/companies` |
| Projects | `GET /api/projects` (has `workflow_id`, `company_id`) |
| Status catalog | `GET /api/issue-statuses?include_archived=true` |
| Workflows | `GET /api/issue-workflows` (steps, handler, `is_default`) |
| Issues | `GET /api/issues`, `GET /api/issues/{id}`, `POST /api/issues`, `PUT /api/issues/{id}` |
| Comments | `GET/POST /api/issues/{id}/comments` |
| Live updates | `GET /ws` (WebSocket) |

Phase 0 task T00 verifies each of these against the running server and records the real request and response shapes in `apps/ios/Fixtures`. No Swift model is written from memory.

## 3.1 Mobile-first design rules

- One column of content. Portrait only. Thumb-reach layout: primary actions at the bottom, never in a top corner.
- Bottom tab bar: Oggi, Task, Progetti, Altro. A floating "+" opens the new task sheet.
- Kanban shows one column at a time with a paging strip on top. Dragging a card works by long press, and a "Sposta in…" menu is always available as the non-drag path.
- Tap targets at least 44 pt. Swipe on a row: complete, and move.
- Sheets for editing, not full pushes. Back swipe always works.
- Pull to refresh on every list. The live socket only updates what is on screen.
- Loads fast on a weak connection: lists first, details on demand.

## 4. Phases and tasks

Each task is small: one PR, a few files, a check that CI can run. IDs are stable. Sessions are named `ios-T<nn>-<slug>`.

### Phase 0: ground truth (no Swift)

- **T00 API contract.** Read the Go handlers and the TypeScript types for the endpoints above. Write `apps/ios/docs/API.md` and sanitised fixtures in `apps/ios/Fixtures/*.json` (issues, projects, companies, statuses, workflows, one login exchange). Check: fixtures are valid JSON, no tokens or emails in them (a CI grep job).
- **T01 Reference review.** Read GrokPe `apps/ios` (`project.yml`, `build-device.sh`, `APIClient.swift`, `WebSocketClient.swift`, `HomeScreen.swift`). Write `apps/ios/docs/REUSE.md` listing what to copy, what to adapt, what to skip. No code copied yet.

### Phase 1: scaffold and CI

- **T10 Project skeleton.** `project.yml`, empty `CalmCore` framework, empty `CalmTasks` app that shows "Calm Tasks", an asset catalog with a placeholder icon, `.gitignore` entries for `*.xcodeproj`, `build*/`, `DerivedData`. Check: CI job `ios-build` (T11).
- **T11 CI workflow.** `.github/workflows/ios.yml` on `macos-15`: install XcodeGen, `xcodegen generate`, build for the simulator with `CODE_SIGNING_ALLOWED=NO`, run `CalmCoreTests`, upload the `.app` as an artifact. Path filter on `apps/ios/**`. Check: the workflow is green on its own PR.
- **T13 TestFlight pipeline (needs the paid account).** A second workflow `ios-testflight.yml`, manual or on a tag: archive, sign with the secrets, upload with the App Store Connect API key. Giuseppe creates the secrets; no session ever sees them. Check: the first build appears in TestFlight.
- **T14 Version stamping.** The build number comes from the CI run number, the marketing version from the tag. Check: two consecutive builds install over each other.
- **T12 Device script.** `build-device.sh` adapted from GrokPe (team id, bundle prefix, `devicectl` install). README for the one manual step. Check: `shellcheck` job in CI.

### Phase 2: core library (no screens)

- **T20 Keychain and config.** `KeychainStore` (token, server URL, workspace id), `ServerConfig` with the HTTPS-only rule (HTTP allowed for `localhost`). Check: unit tests with an in-memory store.
- **T21 API client.** `APIClient` with auth and workspace headers, tolerant JSON decoding, typed errors, 401 handling. Check: tests with a fake `URLProtocol` and the T00 fixtures.
- **T22 Models.** `Issue`, `Project`, `Company`, `IssueStatusEntry`, `IssueWorkflow`, `WorkflowStep`. Check: every fixture decodes; a fixture with an unknown extra key still decodes.
- **T23 Login flow.** `AuthService` (send code, verify code, store token, sign out). Check: tests for success, wrong code, expired token.
- **T24 Board logic.** `BoardResolver`: columns for a project (workflow steps or catalog), `columnOf(issue)` with the category fallback, closed columns excluded. This is a port of `useBoard`. Check: tests that mirror the cases in the web Calm UI (Default workflow, named workflow, hidden column, unknown status).
- **T25 Stores.** `BoardStore` (load companies, projects, statuses, workflows, issues; refresh; optimistic status change with rollback). Check: tests with the fake API.

### Phase 3: screens

- **T30 Onboarding.** Server URL field, email, code entry, error states. Italian copy. Check: CI builds; a UI test on the simulator drives it against a local stub server started by the test.
- **T31 Home.** Companies and projects tree, "Oggi", "Task", and the "basato su Multica" credit in Settings. Calm palette from `packages/views/calm/shared.tsx`.
- **T32 List view.** Tasks grouped by column, in column order, with priority, due date and running-agent badge.
- **T33 Kanban view.** Horizontal columns with paging on iPhone; long-press and drag a card to another column; the change calls `PUT /api/issues/{id}` with rollback on failure.
- **T34 Workflow header.** Shows the project workflow name; a "Colonne" action opens the web editor in Safari at `?tab=workflows&workflow=<id>`. Columns are not edited natively in v1.
- **T35 Task detail.** Title, status pill (only statuses the workflow allows), priority, due date, description, comments, agent runs summary.
- **T36 New task.** Title, project (preselected from the current scope), priority, due date.
- **T37 Today view.** Due today and overdue, same rule as the web "Oggi".

### Phase 4: live updates and polish

- **T40 WebSocket.** Connect to `/ws`, reconnect with backoff, refresh the affected issue or list on events. Check: tests with a fake socket.
- **T41 Offline and errors.** Clear banner when the Tailscale address is unreachable ("Il Mac non risponde. Controlla Tailscale."). No offline writes.
- **T42 Accessibility and dark mode.** Dynamic Type, VoiceOver labels, a dark palette.
- **T43 App icon and launch screen.** Uses the Multica mark and name as the licence requires.

### Phase 5: release candidate

- **T50 Docs.** `apps/ios/README.md`: build in CI, the weekly device install, known limits.
- **T51 Final PR.** `calm-ios` into `calm-ui`, with the CI artifact and a checklist for Giuseppe's first run on the phone (login, open a project, move a task, kill and reopen the app).

Dependencies: T00 and T01 first. T10 before T11 and T12. T20 to T25 need T10 and T11. T30 to T37 need T24 and T25. T40 to T43 need T31. T50 and T51 last.

Parallelism: T00 and T01 can run together. T20, T21 and T22 touch different files and can run together after T11. Screens T32 and T33 can run together after T25. Never run two sessions that edit the same file.

## 5. Orchestration

### 5.1 Roles

- **Giuseppe** approves the plan, the decisions D1 to D8, and each PR merge.
- **Grok Bot "App & Tools"** reads the task list, starts sessions, and updates task status from the notifications. It never writes code.
- **Claude Code sessions** run on the Mac in the background, one per task, each in its own git worktree.
- **GitHub Actions** builds and tests. Sessions only read the result.

### 5.2 Where the tasks live

Recommendation: **Multica is the source of truth for the app tasks, and the Notion "Task" database is a mirror.**

- Create a Multica project "Calm Tasks iOS" under the SOLID company, with the Default workflow (no custom columns needed).
- One Multica issue per task above, titled `T24 Board logic`, with the brief in the description.
- Status mapping (uses built-in keys, so no new statuses and no fixed-position problems):

| Bot state | Multica status key | Calm column |
|---|---|---|
| Backlog | `backlog` | Backlog |
| Next | `todo` | Da fare |
| In corso | `in_progress` | In corso |
| In attesa | `blocked` | Bloccato |
| Completato | `done` | Fatto |

- The bot changes status with the `multica` CLI (`multica issue status <id> <status> --no-start`). The `--no-start` flag matters: without it a status change on a column with an agent handoff would start an agent run. The bot then adds the session summary with `multica issue comment`.
- Notion "✅ Task": mirror each issue as a page with the same title, the status above, a link to the Multica issue and a link to the PR. The Notion connector is not authorised in the session that wrote this plan, so the exact property names are **not verified**. Task T-N0 below (owned by the bot, not a code task) reads the database schema first and writes the mapping into the bot's notes before the first mirror.
- Single writer rule: for each field only one system writes. Multica owns status. Notion shows it. Nobody edits status by hand in two places.

### 5.3 Starting a session

The bot starts every session with:

```bash
cd ~/Code/multica-worktrees && git -C ~/Code/multica worktree add ../multica-worktrees/ios-T24-board-logic -b ios/T24-board-logic calm-ios
cd ../multica-worktrees/ios-T24-board-logic
claude --bg \
  --name "ios-T24-board-logic" \
  --remote-control "ios-T24-board-logic" \
  --permission-mode bypassPermissions \
  "$(cat ~/grokjobs/briefs/ios-T24-board-logic.md)"
```

Notes:

- `--permission-mode bypassPermissions` removes all prompts, so the brief must carry the hard rules from section 1. The brief states what the session may not do, and the worktree limits the blast radius to one branch.
- The session name equals the branch slug, so the bot can match a notification (`session`) to a task without a lookup table.
- `--remote-control` lets Giuseppe open any session from his phone and talk to it.
- The bot starts at most 3 sessions at once, and never two that touch the same files (see the parallelism notes in section 4).

### 5.4 Brief format (one markdown file per session)

Saved by the bot as `~/grokjobs/briefs/<session>.md`. The same text is the session prompt.

```markdown
# <session name>: <task title>

## Context
Repo: fuscogiuse/multica. Worktree: <path>. Branch: ios/T24-board-logic. Base: calm-ios.
Plan: docs/calm-ios/PLAN.md, task T24. Multica issue: <issue identifier or URL>.
Read first: apps/ios/docs/API.md, apps/ios/Fixtures/, packages/views/calm/shared.tsx (useBoard).

## Goal
One paragraph: what exists when the task is done.

## Files you may change
- apps/ios/Sources/CalmCore/Store/BoardResolver.swift
- apps/ios/Tests/CalmCoreTests/BoardResolverTests.swift
Do not touch any other file.

## Done when
- [ ] Specific, checkable item 1
- [ ] Specific, checkable item 2
- [ ] CI check "ios-build" is green on the PR

## Hard rules
- Do NOT run xcodebuild, swift build, swift test, xcodegen, make, pnpm or npm builds or tests. CI does that.
- English only in code, comments, commits, PR text.
- No secrets, no .env, no .xcodeproj, no files over 5 MB.
- Do not message anyone. Do not touch Notion, Slack, email.
- If blocked or the brief is ambiguous, stop and report "BLOCKED: <question>" in the summary.

## Last steps (in this order)
1. Commit in small commits, push the branch, open a PR into calm-ios. PR title: "T24: Board logic". PR body: what changed, how CI proves it.
2. Wait for CI: `gh pr checks --watch`. If it fails, fix and push again, up to 3 times.
3. Write the result file (format in section 5.5) to ~/grokjobs/out/<session>.md.
4. Run exactly:
   ~/grokjobs/notify-grokbot.sh "App & Tools" "<session name>" "<summary, max 400 chars>" "~/grokjobs/out/<session>.md"
```

The summary starts with one of four words so the bot can parse it without reading the file: `DONE`, `FAILED`, `BLOCKED`, `PARTIAL`. Example: `DONE T24: PR #12 green, 14 tests, no open questions`.

### 5.5 Output file format (what the bot reads)

`~/grokjobs/out/<session>.md`, always the same shape:

```markdown
---
session: ios-T24-board-logic
task: T24
result: DONE            # DONE | FAILED | BLOCKED | PARTIAL
pr: https://github.com/fuscogiuse/multica/pull/12
branch: ios/T24-board-logic
ci: success             # success | failure | pending | none
finished: 2026-10-21T15:42:00+02:00
next_status: done       # the Multica status the bot should set
---

## Summary
Two to five lines in plain English.

## Changed files
- path: one-line reason

## Checks
- CI ios-build: success (link)
- Tests added: 14

## Open questions
- None. (Or numbered questions. Required when result is BLOCKED.)

## Follow-ups
- Suggested new tasks, one per line, each with a proposed ID and title. The bot adds them to Backlog only after Giuseppe approves.
```

Bot rules for reading it:

| `result` | Multica status | Extra action |
|---|---|---|
| `DONE` and `ci: success` | `done` after Giuseppe merges the PR; until then `in_progress` with the comment "PR ready" | Notify Giuseppe once the PR is ready |
| `DONE` and `ci` not success | `in_progress` | Re-open the session or start a fix session |
| `PARTIAL` | `in_progress` | Comment with the open items |
| `BLOCKED` | `blocked` (In attesa) | Copy the question to Giuseppe, never answer for him |
| `FAILED` | `blocked` | Comment with the error, no automatic retry |

Merge is always Giuseppe's click. The bot does not merge.

### 5.6 Status lifecycle

```
Backlog -> Next            Giuseppe or the bot, when dependencies are done
Next -> In corso           the bot, at the moment it starts the session
In corso -> In attesa      notification result BLOCKED or FAILED
In corso -> In corso       PARTIAL, or DONE while the PR is still open
In corso -> Completato     PR merged by Giuseppe, CI green
In attesa -> Next          Giuseppe answered the question
```

The bot sets a Multica comment on every transition: session name, time, result word, PR link.

### 5.7 Existing notify script, and what it also does

`~/grokjobs/notify-grokbot.sh` posts to the Grok Bot webhook. It also creates a Todoist task and, if `.trello.env` exists, a Trello card (Trello is currently switched off). Decision for Giuseppe: keep the Todoist side effect, or remove it for iOS sessions. If it stays, 30 tasks will create about 30 Todoist items. Recommendation: pass an environment variable `NOTIFY_QUIET=1` for these sessions, and change the script once to skip Todoist and Trello when it is set.

### 5.8 Bot-side tasks (not code, run by the bot)

- **T-N0** Read the Notion "Task" database schema and write the property mapping to the bot notes.
- **T-N1** Create the Multica project and one issue per task from this plan, in Backlog, with briefs.
- **T-N2** On each notification: parse `result`, read the output file, set status and comment, mirror to Notion.
- **T-N3** Daily: list sessions still running (`claude agents`), flag any older than 2 hours without a notification as stuck, and ask Giuseppe.

### 5.9 Failure handling

- A session that dies without notifying: T-N3 flags it, the bot marks the issue `blocked` and comments "no notification, check session".
- A notification with no output file: treated as `FAILED`.
- Two PRs conflicting: the later one rebases onto `calm-ios`; the bot starts a rebase session, never resolves conflicts itself.
- Bypass mode risk: all sessions run in a dedicated worktree. They cannot reach other repos if the brief's file list is respected, and the PR diff is the review point.

## 6. Verification without building on the Mac

- Logic is verified by XCTest on GitHub Actions.
- UI is verified by simulator UI tests on GitHub Actions and by screenshots uploaded as CI artifacts.
- The final proof on a real phone is Giuseppe's manual checklist in T51.
- Server-side facts (statuses, workflows) are verified against the running stack by T00 only, which reads and records.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Free signing expires every 7 days | Weekly re-run of `build-device.sh`, or the paid account (D5) |
| Tailscale off on the phone or the Mac asleep | Clear error banner (T41), README tip |
| API shape drifts after an upstream merge | Fixtures plus tolerant decoding; T00 can be re-run |
| Workflow rules differ from the web (fixed head and tail columns) | T24 ports `useBoard` and its tests; the editor stays on the web |
| Sessions in bypass mode change too much | File allow-list in each brief, PR review, no merge by the bot |
| CI minutes on macOS runners | Path filters, one workflow, cancel superseded runs |
| Unverified Notion mapping | T-N0 before any mirror |

## 8. Out of scope for v1

Editing workflows or columns natively, push notifications, offline writes, App Store or TestFlight release, an iPad layout, agent configuration screens.

## 9. First three steps after approval

1. Giuseppe answers D1 to D8 (a reply of "ok" accepts the recommendations).
2. The bot runs T-N0 and T-N1.
3. The bot starts T00 and T01 in parallel.
