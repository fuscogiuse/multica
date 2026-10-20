# Calm Tasks MCP connector

Lets a remote assistant (Grok Bot) control this Calm Tasks workspace with the
owner's account: tasks, comments, columns, projects, companies, workflows and
settings. The app stays private on the tailnet; only this connector is
published, through Tailscale Funnel, and every request must carry the
connector key.

## Setup

1. In the app, Settings > Tokens: create a personal access token.
2. Run `bash tools/calm-mcp/setup.sh` and paste the token when asked.
   It writes `~/.multica/calm-mcp.env` (mode 600), installs the LaunchAgent
   `ai.calm-tasks.mcp` and runs `tailscale funnel --bg --https=8443`.
3. In the assistant, add an MCP connector:
   - URL: `https://<mac>.<tailnet>.ts.net:8443/mcp`
   - API key: `CALM_MCP_KEY` from `~/.multica/calm-mcp.env`
     (sent as `Authorization: Bearer`, `X-API-Key` or `?key=`).

## Tools

`calm_api` (any `/api/` endpoint), `list_tasks`, `search_tasks`, `get_task`,
`create_task`, `update_task`, `comment_task`, `delete_task`, `list_projects`,
`list_columns`.

## Safety

- Anyone with the key can do anything the owner can. Keep it out of chats and git.
- Rate limit: 120 requests per minute per client (`CALM_MCP_RATE`).
- Log: `~/.multica/calm-mcp.log` (method, path, status; no bodies).
- Emergency stop: `bash tools/calm-mcp/stop.sh` closes the public entry.
- Rotate the key: delete `~/.multica/calm-mcp.env` and run `setup.sh` again;
  revoke the token in Settings > Tokens.
