// Calm Tasks MCP connector.
//
// Lets a remote assistant (Grok Bot) control the self-hosted Calm Tasks
// workspace with the owner's own account: tasks, comments, columns,
// projects, companies, workflows and settings. Every call goes to the local
// Multica API with the owner's personal access token, so the assistant can do
// anything the owner can do in the app.
//
// Only this server is published (through Tailscale Funnel); the app itself
// stays private on the tailnet. Requests must carry CALM_MCP_KEY.

import { createServer } from "node:http";
import { appendFileSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { timingSafeEqual } from "node:crypto";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

const API_URL = (process.env.CALM_API_URL || "http://127.0.0.1:8080").replace(/\/$/, "");
const TOKEN = process.env.CALM_TOKEN || "";
const WORKSPACE = process.env.CALM_WORKSPACE_SLUG || "";
const KEY = process.env.CALM_MCP_KEY || "";
const PORT = Number(process.env.CALM_MCP_PORT || 8765);
const RATE_PER_MIN = Number(process.env.CALM_MCP_RATE || 120);
const LOG_DIR = join(homedir(), ".multica");
const LOG_FILE = join(LOG_DIR, "calm-mcp.log");

if (!TOKEN || !KEY || !WORKSPACE) {
  console.error("calm-mcp: CALM_TOKEN, CALM_MCP_KEY and CALM_WORKSPACE_SLUG are required");
  process.exit(1);
}
if (KEY.length < 32) {
  console.error("calm-mcp: CALM_MCP_KEY must be at least 32 characters");
  process.exit(1);
}

mkdirSync(LOG_DIR, { recursive: true });
function log(line) {
  try {
    appendFileSync(LOG_FILE, `${new Date().toISOString()} ${line}\n`);
  } catch {
    // Logging must never break a request.
  }
}

// ---------- Multica API ----------

async function api(method, path, { body, query } = {}) {
  if (!path.startsWith("/api/")) throw new Error("path must start with /api/");
  const url = new URL(API_URL + path);
  for (const [k, v] of Object.entries(query || {})) {
    if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
  }
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "X-Workspace-Slug": WORKSPACE,
      ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  log(`api ${method} ${url.pathname} -> ${res.status}`);
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const msg = typeof data === "object" && data && "error" in data ? data.error : text;
    throw new Error(`${method} ${path} failed (${res.status}): ${msg}`);
  }
  return data;
}

const ok = (data) => ({ content: [{ type: "text", text: JSON.stringify(data ?? { ok: true }, null, 2) }] });
const fail = (err) => ({ isError: true, content: [{ type: "text", text: String(err?.message || err) }] });
const run = (fn) => async (args) => {
  try {
    return ok(await fn(args));
  } catch (err) {
    return fail(err);
  }
};

// ---------- Tools ----------

function buildServer() {
  const server = new McpServer({ name: "calm-tasks", version: "0.1.0" });

  server.registerTool(
    "calm_api",
    {
      title: "Call any Calm Tasks API",
      description:
        "Full control of the Calm Tasks app (a Multica fork). Calls any endpoint under /api/ as the owner. " +
        "Useful endpoints: GET/POST /api/issues, GET/PUT/DELETE /api/issues/{id}, GET/POST /api/issues/{id}/comments, " +
        "GET /api/issues/search?q=, GET/POST /api/projects, PUT /api/projects/{id}, PUT /api/projects/{id}/company, " +
        "GET/POST /api/companies, PATCH/DELETE /api/companies/{id}, GET/POST /api/issue-statuses, PATCH /api/issue-statuses/{id}, " +
        "GET/POST /api/issue-workflows, PATCH /api/issue-workflows/{id}, POST /api/projects/{id}/workflow, " +
        "GET /api/agents, GET /api/labels, GET /api/me, GET /api/inbox. Issue ids accept the UUID or the identifier (e.g. SLD-12).",
      inputSchema: {
        method: z.enum(["GET", "POST", "PUT", "PATCH", "DELETE"]),
        path: z.string().describe("Path starting with /api/, e.g. /api/issues/SLD-2"),
        query: z.record(z.string(), z.union([z.string(), z.number(), z.boolean()])).optional(),
        body: z.any().optional().describe("JSON body for POST/PUT/PATCH"),
      },
    },
    run(({ method, path, query, body }) => api(method, path, { query, body })),
  );

  server.registerTool(
    "list_tasks",
    {
      title: "List tasks",
      description: "List tasks. Filter by project, priority or open tasks only. Use search_tasks for text search.",
      inputSchema: {
        project_id: z.string().optional(),
        open_only: z.boolean().optional(),
        priority: z.enum(["urgent", "high", "medium", "low", "none"]).optional(),
        limit: z.number().int().min(1).max(200).optional(),
      },
    },
    run((q) => api("GET", "/api/issues", { query: q })),
  );

  server.registerTool(
    "search_tasks",
    {
      title: "Search tasks",
      description: "Search tasks by title, description or comments.",
      inputSchema: { q: z.string(), limit: z.number().int().min(1).max(50).optional() },
    },
    run((q) => api("GET", "/api/issues/search", { query: q })),
  );

  server.registerTool(
    "get_task",
    {
      title: "Get task with comments",
      description: "Get one task and its comments. id is the UUID or identifier like SLD-12.",
      inputSchema: { id: z.string() },
    },
    run(async ({ id }) => {
      const issue = await api("GET", `/api/issues/${encodeURIComponent(id)}`);
      const comments = await api("GET", `/api/issues/${encodeURIComponent(issue.id ?? id)}/comments`);
      return { issue, comments };
    }),
  );

  server.registerTool(
    "create_task",
    {
      title: "Create task",
      description:
        "Create a task. status is a column key (see list_columns). priority: urgent, high, medium, low, none. due_date: YYYY-MM-DD.",
      inputSchema: {
        title: z.string(),
        description: z.string().optional(),
        project_id: z.string().optional(),
        status: z.string().optional(),
        priority: z.enum(["urgent", "high", "medium", "low", "none"]).optional(),
        due_date: z.string().optional(),
        assignee_type: z.enum(["member", "agent"]).optional(),
        assignee_id: z.string().optional(),
      },
    },
    run((body) => api("POST", "/api/issues", { body })),
  );

  server.registerTool(
    "update_task",
    {
      title: "Update task",
      description:
        "Change a task: title, description, status (move column), priority, due_date, project_id, assignee. Only sent fields change.",
      inputSchema: {
        id: z.string(),
        title: z.string().optional(),
        description: z.string().optional(),
        status: z.string().optional(),
        priority: z.enum(["urgent", "high", "medium", "low", "none"]).optional(),
        due_date: z.string().nullable().optional(),
        project_id: z.string().nullable().optional(),
        assignee_type: z.enum(["member", "agent"]).nullable().optional(),
        assignee_id: z.string().nullable().optional(),
      },
    },
    run(({ id, ...body }) => api("PUT", `/api/issues/${encodeURIComponent(id)}`, { body })),
  );

  server.registerTool(
    "comment_task",
    {
      title: "Comment on task",
      description: "Add a comment to a task. Markdown is supported. parent_id replies to a comment.",
      inputSchema: { id: z.string(), content: z.string(), parent_id: z.string().optional() },
    },
    run(({ id, content, parent_id }) =>
      api("POST", `/api/issues/${encodeURIComponent(id)}/comments`, { body: { content, parent_id } }),
    ),
  );

  server.registerTool(
    "delete_task",
    {
      title: "Delete task",
      description: "Delete a task permanently.",
      inputSchema: { id: z.string() },
      annotations: { destructiveHint: true },
    },
    run(({ id }) => api("DELETE", `/api/issues/${encodeURIComponent(id)}`)),
  );

  server.registerTool(
    "list_projects",
    {
      title: "List companies and projects",
      description: "List companies (areas) and their projects (clients), with ids.",
      inputSchema: {},
    },
    run(async () => {
      const [companies, projects] = await Promise.all([api("GET", "/api/companies"), api("GET", "/api/projects")]);
      return { companies: companies?.companies ?? companies, projects: projects?.projects ?? projects };
    }),
  );

  server.registerTool(
    "list_columns",
    {
      title: "List columns and workflows",
      description: "List all status columns (keys, names, instructions) and the workflows that give each project its own columns.",
      inputSchema: {},
    },
    run(async () => {
      const [statuses, workflows] = await Promise.all([api("GET", "/api/issue-statuses"), api("GET", "/api/issue-workflows")]);
      return { statuses, workflows };
    }),
  );

  return server;
}

// ---------- HTTP ----------

function keyFrom(req, url) {
  const auth = req.headers.authorization || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  if (req.headers["x-api-key"]) return String(req.headers["x-api-key"]).trim();
  return url.searchParams.get("key") || "";
}

function validKey(candidate) {
  const a = Buffer.from(candidate);
  const b = Buffer.from(KEY);
  return a.length === b.length && timingSafeEqual(a, b);
}

const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  recent.push(now);
  hits.set(ip, recent);
  return recent.length > RATE_PER_MIN;
}

async function readBody(req) {
  const chunks = [];
  let size = 0;
  for await (const c of req) {
    size += c.length;
    if (size > 2_000_000) throw new Error("body too large");
    chunks.push(c);
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  return raw ? JSON.parse(raw) : undefined;
}

const http = createServer(async (req, res) => {
  const url = new URL(req.url || "/", "http://localhost");
  const ip = String(req.headers["x-forwarded-for"] || req.socket.remoteAddress || "?").split(",")[0].trim();

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" }).end("ok");
    return;
  }
  if (url.pathname !== "/mcp") {
    res.writeHead(404).end();
    return;
  }
  if (rateLimited(ip)) {
    log(`rate-limited ${ip}`);
    res.writeHead(429).end();
    return;
  }
  if (!validKey(keyFrom(req, url))) {
    log(`unauthorized ${ip} ${req.method}`);
    res.writeHead(401, { "Content-Type": "application/json" }).end(JSON.stringify({ error: "unauthorized" }));
    return;
  }

  try {
    const body = req.method === "POST" ? await readBody(req) : undefined;
    // Stateless: a fresh server and transport per request.
    const server = buildServer();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
    res.on("close", () => {
      transport.close();
      server.close();
    });
    await server.connect(transport);
    if (body && body.method === "tools/call") log(`tool ${body.params?.name} from ${ip}`);
    await transport.handleRequest(req, res, body);
  } catch (err) {
    log(`error ${String(err?.message || err)}`);
    if (!res.headersSent) res.writeHead(500, { "Content-Type": "application/json" }).end(JSON.stringify({ error: "internal error" }));
  }
});

http.listen(PORT, "127.0.0.1", () => {
  log(`listening on 127.0.0.1:${PORT} -> ${API_URL} (workspace ${WORKSPACE})`);
  console.log(`calm-mcp listening on http://127.0.0.1:${PORT}/mcp`);
});
