"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { useWorkspaceId } from "@multica/core/hooks";
import { issueListOptions, issueStatusCategory } from "@multica/core/issues";
import { projectListOptions } from "@multica/core/projects";
import { agentListOptions } from "@multica/core/workspace";
import { agentTaskSnapshotOptions } from "@multica/core/agents";
import { companyListOptions } from "@multica/core/companies";
import type { AgentTask, Company, Issue, IssuePriority, Project } from "@multica/core/types";
import { useNavigation } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { cn } from "@multica/ui/lib/utils";

// Calm UI palette. The calm screens are a light, Todoist-like surface, so they
// use these fixed values instead of the theme tokens.
export const CALM = {
  ink: "#202020",
  muted: "#666666",
  soft: "#4b4b4b",
  primary: "#dc4c3e",
  warm: "#fcfaf8",
  sand: "#f6f4f1",
  green: "#058527",
  blue: "#246fe0",
  orange: "#eb8909",
  red: "#d1453b",
  line: "rgba(0,0,0,0.08)",
};

const PROJECT_TINTS = ["#f3e6dc", "#e3ecf5", "#e6f0e8", "#efe8f3", "#f4efdc", "#fbe4e2", "#e2f1f1"];
export function projectTint(id: string): string {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) | 0;
  return PROJECT_TINTS[Math.abs(h) % PROJECT_TINTS.length]!;
}

export const PRIORITY_IT: Record<IssuePriority, string> = {
  urgent: "Urgente",
  high: "Alta",
  medium: "Media",
  low: "Bassa",
  none: "Nessuna",
};

export const PRIORITY_RANK: Record<IssuePriority, number> = {
  urgent: 0,
  high: 1,
  medium: 2,
  low: 3,
  none: 4,
};

export function priorityColor(p: IssuePriority): { ring: string; fill: string } {
  switch (p) {
    case "urgent":
    case "high":
      return { ring: CALM.red, fill: "rgba(209,69,59,0.10)" };
    case "medium":
      return { ring: CALM.orange, fill: "rgba(235,137,9,0.10)" };
    case "low":
      return { ring: CALM.blue, fill: "rgba(36,111,224,0.10)" };
    default:
      return { ring: "rgba(0,0,0,0.30)", fill: "transparent" };
  }
}

const STATUS_IT: Record<string, string> = {
  backlog: "Backlog",
  todo: "Da fare",
  in_progress: "In corso",
  in_review: "In revisione",
  blocked: "Bloccato",
  done: "Fatto",
  cancelled: "Annullato",
};

export function statusLabel(issue: Pick<Issue, "status" | "status_name">): string {
  return STATUS_IT[issue.status] ?? issue.status_name ?? issue.status;
}

export const STATUS_DOT: Record<string, string> = {
  backlog: "rgba(0,0,0,0.25)",
  todo: "rgba(0,0,0,0.25)",
  in_progress: CALM.green,
  in_review: CALM.blue,
  blocked: CALM.red,
  done: CALM.blue,
  cancelled: "rgba(0,0,0,0.25)",
};

/** Kanban column a status belongs to. Cancelled issues are hidden. */
export type CalmColumn = "todo" | "doing" | "review" | "done";
export function calmColumn(issue: Issue): CalmColumn | null {
  switch (issue.status) {
    case "backlog":
    case "todo":
      return "todo";
    case "in_progress":
    case "blocked":
      return "doing";
    case "in_review":
      return "review";
    case "done":
      return "done";
    case "cancelled":
      return null;
  }
  const cat = issueStatusCategory(issue);
  if (cat === "unstarted") return "todo";
  if (cat === "started") return "doing";
  if (cat === "done") return "done";
  return null;
}

export function isOpen(issue: Issue): boolean {
  const col = calmColumn(issue);
  return col === "todo" || col === "doing" || col === "review";
}

export function byPriorityThenDue(a: Issue, b: Issue): number {
  const p = PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority];
  if (p !== 0) return p;
  if (a.due_date && b.due_date) return a.due_date.localeCompare(b.due_date);
  if (a.due_date) return -1;
  if (b.due_date) return 1;
  return b.updated_at.localeCompare(a.updated_at);
}

const EMPTY_ISSUES: Issue[] = [];
const EMPTY_PROJECTS: Project[] = [];
const EMPTY_TASKS: AgentTask[] = [];
const EMPTY_COMPANIES: Company[] = [];

/** Kanban/Oggi scope from the URL: ?company=<id> and/or ?progetto=<id>. */
export function useCalmScope() {
  const { searchParams } = useNavigation();
  return {
    companyId: searchParams.get("company"),
    projectId: searchParams.get("progetto"),
  };
}

/** Everything the calm list/board screens read, in one place. */
export function useCalmData() {
  const wsId = useWorkspaceId();
  const issuesQ = useQuery(issueListOptions(wsId));
  const projectsQ = useQuery(projectListOptions(wsId));
  const snapshotQ = useQuery(agentTaskSnapshotOptions(wsId));
  const agentsQ = useQuery(agentListOptions(wsId));
  const companiesQ = useQuery(companyListOptions(wsId));
  const scope = useCalmScope();

  const allIssues = issuesQ.data ?? EMPTY_ISSUES;
  const companies = companiesQ.data ?? EMPTY_COMPANIES;
  const projects = projectsQ.data ?? EMPTY_PROJECTS;
  const tasks = snapshotQ.data ?? EMPTY_TASKS;

  const projectById = useMemo(() => {
    const m = new Map<string, Project>();
    for (const p of projects) m.set(p.id, p);
    return m;
  }, [projects]);

  const companyById = useMemo(() => {
    const m = new Map<string, Company>();
    for (const c of companies) m.set(c.id, c);
    return m;
  }, [companies]);

  const companyOf = useMemo(() => {
    return (issue: Issue): Company | undefined => {
      const p = issue.project_id ? projectById.get(issue.project_id) : undefined;
      return p?.company_id ? companyById.get(p.company_id) : undefined;
    };
  }, [projectById, companyById]);

  // One board for every company; the URL scope narrows it.
  const issues = useMemo(() => {
    if (!scope.companyId && !scope.projectId) return allIssues;
    return allIssues.filter((i) => {
      if (scope.projectId) return i.project_id === scope.projectId;
      return companyOf(i)?.id === scope.companyId;
    });
  }, [allIssues, scope.companyId, scope.projectId, companyOf]);

  const runningByIssue = useMemo(() => {
    const m = new Map<string, AgentTask>();
    for (const t of tasks) {
      if (t.status === "running" && t.issue_id) m.set(t.issue_id, t);
    }
    return m;
  }, [tasks]);

  const agentName = useMemo(() => {
    const m = new Map<string, string>();
    for (const a of agentsQ.data ?? []) m.set(a.id, a.name);
    return (id: string) => m.get(id) ?? "Agente";
  }, [agentsQ.data]);

  return {
    issues,
    projects,
    projectById,
    companies,
    companyById,
    companyOf,
    scope,
    runningByIssue,
    agentName,
    loading: issuesQ.isLoading,
  };
}

/** Round Todoist priority circle. Clicking it completes the task. */
export function PriorityCircle({
  priority,
  done,
  size = 22,
  onComplete,
  label,
}: {
  priority: IssuePriority;
  done?: boolean;
  size?: number;
  onComplete?: () => void;
  label?: string;
}) {
  const c = priorityColor(priority);
  const style = done
    ? { width: size, height: size, borderColor: CALM.green, background: CALM.green }
    : { width: size, height: size, borderColor: c.ring, background: c.fill };
  if (!onComplete) {
    return <span aria-hidden className="inline-block shrink-0 rounded-full border-2" style={style} />;
  }
  return (
    <button
      type="button"
      aria-label={label ?? "Segna come fatto"}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        onComplete();
      }}
      className="group/circle relative inline-flex shrink-0 items-center justify-center rounded-full border-2 transition-transform active:scale-90"
      style={style}
    >
      <svg
        width={size - 10}
        height={size - 10}
        viewBox="0 0 24 24"
        fill="none"
        stroke={done ? "#fff" : c.ring}
        strokeWidth="3"
        strokeLinecap="round"
        strokeLinejoin="round"
        className={cn("transition-opacity", done ? "opacity-100" : "opacity-0 group-hover/circle:opacity-100")}
        aria-hidden
      >
        <path d="M5 12l5 5L20 7" />
      </svg>
    </button>
  );
}

export function ProjectLabel({ project, className }: { project: Project | undefined; className?: string }) {
  if (!project) return null;
  return (
    <span
      className={cn("inline-flex h-[22px] max-w-full items-center self-start truncate rounded-md px-2.5 text-xs font-medium text-[#202020]", className)}
      style={{ background: projectTint(project.id) }}
    >
      <span className="truncate">{project.title}</span>
    </span>
  );
}

/** Small "Company · Progetto" label for cards and rows. */
export function ContextLabel({
  project,
  company,
  className,
}: {
  project: Project | undefined;
  company: Company | undefined;
  className?: string;
}) {
  if (!project && !company) return null;
  return (
    <span className={cn("inline-flex max-w-full items-center gap-1.5 self-start truncate text-xs", className)}>
      {company ? (
        <span className="inline-flex h-[22px] items-center gap-1.5 rounded-md bg-[#f6f4f1] px-2 font-medium text-[#202020]">
          <span className="size-2 shrink-0 rounded-full" style={{ background: company.color ?? CALM.primary }} />
          <span className="truncate">{company.name}</span>
        </span>
      ) : null}
      {project ? (
        <span className="inline-flex h-[22px] items-center truncate rounded-md px-2 font-medium text-[#202020]" style={{ background: projectTint(project.id) }}>
          <span className="truncate">{project.title}</span>
        </span>
      ) : null}
    </span>
  );
}

export function AssigneeAvatar({ issue, size = "md" }: { issue: Issue; size?: "sm" | "md" | "lg" }) {
  if (!issue.assignee_type || !issue.assignee_id) return null;
  return <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size={size} />;
}

export function RunningDot({ className }: { className?: string }) {
  return (
    <span className={cn("relative inline-flex size-2 shrink-0", className)} aria-hidden>
      <span className="absolute inset-0 animate-ping rounded-full bg-[#058527] opacity-40" />
      <span className="relative inline-flex size-2 rounded-full bg-[#058527]" />
    </span>
  );
}

export function relativeIt(iso: string | null | undefined, now = Date.now()): string {
  if (!iso) return "";
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "";
  const s = Math.max(0, Math.round((now - t) / 1000));
  if (s < 60) return "adesso";
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min fa`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} h fa`;
  const d = Math.round(h / 24);
  if (d === 1) return "ieri";
  if (d < 7) return `${d} giorni fa`;
  return new Date(iso).toLocaleDateString("it-IT", { day: "numeric", month: "short" });
}

export function minutesSince(iso: string | null | undefined, now = Date.now()): number {
  if (!iso) return 0;
  return Math.max(0, Math.round((now - new Date(iso).getTime()) / 60000));
}

/** "2026-10-19" → "lun 19 ott" without timezone drift. */
export function formatDueIt(date: string | null | undefined, long = false): string {
  if (!date) return "";
  const [y, m, d] = date.split("-").map(Number);
  if (!y || !m || !d) return date;
  const dt = new Date(y, m - 1, d);
  return dt.toLocaleDateString("it-IT", long
    ? { weekday: "long", day: "numeric", month: "short" }
    : { weekday: "short", day: "numeric", month: "short" });
}
