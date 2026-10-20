# API contract used by the app

All calls go to the Multica server. Headers: `Authorization: Bearer <token>` and `X-Workspace-ID: <workspace id>`. Keys are snake_case on the wire; the app decodes them with `convertFromSnakeCase`. Real responses, sanitised, are in `../Fixtures/`.

| Need | Call | Response |
|---|---|---|
| Flags | `GET /api/config` | `{ feature_flags: { project_workflows_v1: bool, ... } }` |
| Send login code | `POST /auth/send-code` `{ email }` | any body; the self-host server prints the code in its log |
| Verify code | `POST /auth/verify-code` `{ email, code }` | `{ token, user }` |
| Workspaces | `GET /api/workspaces` | plain array of `{ id, name, slug, issue_prefix }` |
| Companies | `GET /api/companies` | `{ companies: [{ id, name, color, position }], total }` |
| Projects | `GET /api/projects` | `{ projects: [{ id, title, workflow_id, company_id, ... }], total }` |
| Status catalog | `GET /api/issue-statuses?include_archived=true` | `{ statuses: [{ id, key, name, category, color, position, board_hidden, archived_at, is_system }], categories }` |
| Workflows | `GET /api/issue-workflows` | `{ workflows: [{ id, name, is_default, steps: [{ status_key, handler, instructions }], project_ids }] }` |
| Issues | `GET /api/issues?limit=100&offset=N&include_closed=true` | `{ issues: [...], total }`; the server caps `limit` at 100, so the app pages |
| Update issue | `PUT /api/issues/{id}` | the updated issue. Send only changed keys. `"due_date": null` clears the date |
| Create issue | `POST /api/issues` `{ title, status, priority, project_id, due_date }` | the new issue |
| Comments | `GET/POST /api/issues/{id}/comments` | array of comments; POST `{ content, type: "comment" }` |
| Live updates | `GET /ws?workspace_id=<id>` | first frame `{"type":"auth","payload":{"token":"..."}}`, answer `{"type":"auth_ack"}`, then events |

Category values on the wire are legacy names (`backlog`, `todo`, `in_progress`, `in_review`, `blocked`, `done`, `cancelled`) for the built-ins and `unstarted`, `started`, `done`, `closed` for custom statuses. The app collapses them (`BoardResolver.normalizeCategory`).
