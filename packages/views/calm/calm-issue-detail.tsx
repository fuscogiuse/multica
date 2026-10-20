"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useWorkspaceId } from "@multica/core/hooks";
import { useAuthStore } from "@multica/core/auth";
import { useWorkspacePaths } from "@multica/core/paths";
import { useCanonicalIssue } from "@multica/core/issues/canonical-id";
import {
  childIssuesOptions,
  issueDetailOptions,
  issueTasksOptions,
  useUpdateIssue,
} from "@multica/core/issues";
import { projectListOptions } from "@multica/core/projects";
import { companyListOptions } from "@multica/core/companies";
import { useActorName } from "@multica/core/workspace";
import type { AgentTask, Company, Issue, TimelineEntry, UpdateIssueRequest } from "@multica/core/types";
import { AppLink, useBackOrReplace } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { ContentEditor, ReadonlyContent, TitleEditor } from "../editor";
import { useIssueTimeline } from "../issues/hooks";
import {
  AssigneePicker,
  CommentInput,
  DueDatePicker,
  IssueDetailRoute,
  PriorityPicker,
  StatusPicker,
} from "../issues/components";
import { ProjectPicker } from "../projects/components";
import { TranscriptButton } from "../common/task-transcript";
import { cn } from "@multica/ui/lib/utils";
import {
  CALM,
  useBoard,
  formatDueIt,
  minutesSince,
  PRIORITY_IT,
  priorityColor,
  PriorityCircle,
  relativeIt,
} from "./shared";

const ACTIVE_TASK = new Set<AgentTask["status"]>(["queued", "dispatched", "running", "waiting_local_directory", "deferred"]);

function useTick(ms = 30_000) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), ms);
    return () => clearInterval(id);
  }, [ms]);
  return now;
}

/* ---------- Activity wording (Italian one-liners) ---------- */

const STATUS_WORD: Record<string, string> = {
  backlog: "Backlog",
  todo: "Da fare",
  in_progress: "In corso",
  in_review: "In revisione",
  blocked: "Bloccato",
  done: "Fatto",
  cancelled: "Annullato",
};

function activityText(entry: TimelineEntry, actorName: (t: string, id: string) => string): string {
  const d = (entry.details ?? {}) as Record<string, string | undefined>;
  const st = (s?: string) => (s ? STATUS_WORD[s] ?? s : "?");
  switch (entry.action) {
    case "created":
      return "ha creato il task";
    case "status_changed":
      return `ha spostato lo stato da ${st(d.from)} a ${st(d.to)}`;
    case "priority_changed":
      return `ha cambiato la priorità in ${PRIORITY_IT[(d.to ?? "none") as keyof typeof PRIORITY_IT] ?? d.to}`;
    case "assignee_changed":
      if (d.to_id && d.to_type) return `l’ha assegnato a ${actorName(d.to_type, d.to_id)}`;
      return "ha rimosso l’assegnatario";
    case "due_date_changed":
      return d.to ? `ha impostato la scadenza a ${formatDueIt(d.to)}` : "ha rimosso la scadenza";
    case "start_date_changed":
      return d.to ? `ha impostato l’inizio a ${formatDueIt(d.to)}` : "ha rimosso la data di inizio";
    case "title_changed":
      return `ha rinominato il task in “${d.to ?? "?"}”`;
    case "description_updated":
      return "ha aggiornato la descrizione";
    case "task_completed":
      return "ha completato un’esecuzione";
    case "task_failed":
      return "ha avuto un’esecuzione fallita";
    default:
      return (entry.action ?? "").replace(/_/g, " ");
  }
}

/* ---------- Timeline ---------- */

function Feed({ timeline, loading }: { timeline: TimelineEntry[]; loading: boolean }) {
  const user = useAuthStore((s) => s.user);
  const { getActorName } = useActorName();
  const now = useTick();

  const { items, replies } = useMemo(() => {
    const replies = new Map<string, TimelineEntry[]>();
    const items: TimelineEntry[] = [];
    for (const e of timeline) {
      if (e.type === "comment" && e.deleted_at && !e.content) continue;
      if (e.type === "comment" && e.parent_id) {
        const arr = replies.get(e.parent_id) ?? [];
        arr.push(e);
        replies.set(e.parent_id, arr);
      } else {
        items.push(e);
      }
    }
    return { items, replies };
  }, [timeline]);

  const who = (e: TimelineEntry) =>
    e.actor_type === "member" && e.actor_id === user?.id ? "Tu" : e.actor_name ?? getActorName(e.actor_type, e.actor_id);

  if (loading) {
    return (
      <div className="flex flex-col gap-3">
        {[0, 1, 2].map((k) => (
          <div key={k} className="h-12 animate-pulse rounded-xl bg-[#f6f4f1]" />
        ))}
      </div>
    );
  }
  if (items.length === 0) return <p className="text-sm text-[#666666]">Ancora nessuna attività.</p>;

  return (
    <div className="flex flex-col gap-3 md:gap-3.5">
      {items.map((e) =>
        e.type === "activity" ? (
          <div key={e.id} className="flex items-center gap-2 text-xs text-[#666666] md:gap-2.5 md:pl-1.5 md:text-[13px]">
            <ActorAvatar actorType={e.actor_type} actorId={e.actor_id} name={e.actor_name} avatarUrl={e.actor_avatar_url} size="xs" />
            <span className="min-w-0 flex-1">
              <strong className="font-semibold text-[#4b4b4b]">{who(e)}</strong> {activityText(e, getActorName)}
            </span>
            <span className="shrink-0">{relativeIt(e.created_at, now)}</span>
          </div>
        ) : (
          <div key={e.id} id={`comment-${e.id}`} className="flex gap-2.5 md:gap-3">
            <ActorAvatar actorType={e.actor_type} actorId={e.actor_id} name={e.actor_name} avatarUrl={e.actor_avatar_url} size="md" />
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <div className="flex items-center gap-2 text-[13px]">
                <span className="font-semibold">{who(e)}</span>
                {e.actor_type === "agent" ? (
                  <span className="inline-flex h-5 items-center rounded-md bg-[#f6f4f1] px-[7px] text-[11px] font-semibold text-[#4b4b4b] md:bg-[#f6f4f1]">
                    agente
                  </span>
                ) : null}
                <span className="ml-auto shrink-0 text-xs text-[#666666]">{relativeIt(e.created_at, now)}</span>
              </div>
              <ReadonlyContent content={e.content ?? ""} attachments={e.attachments} className="text-sm leading-relaxed text-[#202020]" />
              {(replies.get(e.id) ?? []).map((r) => (
                <div key={r.id} id={`comment-${r.id}`} className="mt-1 flex gap-2.5 border-t border-black/[0.06] pt-2.5">
                  <ActorAvatar actorType={r.actor_type} actorId={r.actor_id} name={r.actor_name} avatarUrl={r.actor_avatar_url} size="md" />
                  <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <span className="text-[13px]">
                      <strong className="font-semibold">{who(r)}</strong>
                      {r.actor_type === "agent" ? <span className="ml-1.5 text-[11px] font-semibold text-[#4b4b4b]">agente</span> : null}
                      <span className="text-[#666666]"> · {relativeIt(r.created_at, now)}</span>
                    </span>
                    <ReadonlyContent content={r.content ?? ""} attachments={r.attachments} className="text-sm leading-normal text-[#4b4b4b]" />
                  </div>
                </div>
              ))}
            </div>
          </div>
        ),
      )}
    </div>
  );
}

/* ---------- Composer ---------- */

type SubmitComment = ReturnType<typeof useIssueTimeline>["submitComment"];

function Composer({ issueId, submitComment }: { issueId: string; submitComment: SubmitComment }) {
  return (
    <div className="md:max-w-[720px]">
      <CommentInput key={issueId} issueId={issueId} onSubmit={submitComment} />
    </div>
  );
}

/* ---------- Agent runs ---------- */

function Runs({ issueId, compact, hideActive }: { issueId: string; compact?: boolean; hideActive?: boolean }) {
  const { data: tasks = [] } = useQuery(issueTasksOptions(issueId));
  const { getActorName } = useActorName();
  const [openId, setOpenId] = useState<string | null>(null);
  const now = useTick();

  const sorted = useMemo(
    () => [...tasks].sort((a, b) => (b.started_at ?? b.dispatched_at ?? "").localeCompare(a.started_at ?? a.dispatched_at ?? "")),
    [tasks],
  );
  const active = sorted.filter((t) => ACTIVE_TASK.has(t.status));
  const done = sorted.filter((t) => !ACTIVE_TASK.has(t.status));

  const transcript = (t: AgentTask) => (
    <TranscriptButton
      task={t}
      agentName={getActorName("agent", t.agent_id)}
      isLive={ACTIVE_TASK.has(t.status)}
      renderButton={false}
      open={openId === t.id}
      onOpenChange={(o) => setOpenId(o ? t.id : null)}
    />
  );

  if (compact) {
    const t = active[0];
    if (!t) return null;
    return (
      <div className="flex items-center gap-2.5 rounded-lg bg-[#202020] px-3 py-2 text-white">
        <span className="size-2 shrink-0 rounded-full bg-[#7ecc49]" />
        <span className="min-w-0 flex-1 truncate text-[13px]">
          {getActorName("agent", t.agent_id)} {t.status === "running" ? "sta lavorando" : "in coda"}
        </span>
        <span className="shrink-0 text-[13px] text-white/70">{minutesSince(t.started_at ?? t.dispatched_at, now)} min</span>
        <button type="button" onClick={() => setOpenId(t.id)} className="h-7 shrink-0 rounded-md bg-white/[0.12] px-2.5 text-xs font-semibold">
          Trascrizione
        </button>
        {transcript(t)}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2.5">
      <span className="text-sm font-semibold">Esecuzioni dell’agente</span>
      {sorted.length === 0 ? <span className="text-[13px] text-[#666666]">Nessuna esecuzione per ora.</span> : null}
      {(hideActive ? [] : active).map((t) => (
        <div key={t.id} className="flex flex-col gap-2.5 rounded-[14px] bg-[#202020] p-3.5 text-white">
          <div className="flex items-center gap-2 text-[13px]">
            <span className="size-2 rounded-full bg-[#7ecc49]" />
            <span className="min-w-0 flex-1 truncate font-semibold">
              {getActorName("agent", t.agent_id)} {t.status === "running" ? "sta lavorando" : "è in coda"}
            </span>
            <span className="shrink-0 text-white/70">{minutesSince(t.started_at ?? t.dispatched_at, now)} min</span>
          </div>
          <button type="button" onClick={() => setOpenId(t.id)} className="h-10 rounded-[10px] bg-white/[0.12] text-[13px] font-semibold">
            Vedi trascrizione
          </button>
          {transcript(t)}
        </div>
      ))}
      {done.slice(0, 6).map((t, idx) => {
        const n = done.length - idx;
        const ok = t.status === "completed";
        const word = ok ? "completata" : t.status === "failed" ? "fallita" : "annullata";
        return (
          <button
            key={t.id}
            type="button"
            onClick={() => setOpenId(t.id)}
            className="flex min-h-9 items-center gap-2.5 rounded-lg text-left text-[13px] text-[#4b4b4b] hover:bg-black/[0.03]"
          >
            <span className="size-2 shrink-0 rounded-full" style={{ background: ok ? CALM.green : t.status === "failed" ? CALM.red : "rgba(0,0,0,0.25)" }} />
            <span className="min-w-0 flex-1 truncate">
              Esecuzione {n} · {word}
            </span>
            <span className="shrink-0 text-[#666666]">{relativeIt(t.completed_at ?? t.started_at, now)}</span>
            {transcript(t)}
          </button>
        );
      })}
    </div>
  );
}

/* ---------- Properties (one row of pills) ---------- */

function Dot({ color }: { color: string }) {
  return <span className="size-[9px] shrink-0 rounded-full" style={{ background: color }} />;
}

const pillCls =
  "inline-flex h-7 min-w-0 max-w-full items-center gap-1.5 whitespace-nowrap rounded-full bg-[#f6f4f1] px-2.5 text-xs text-[#202020] hover:bg-[#efe9e2]";
const pillEl = <button type="button" className={pillCls} />;

function PropertyPills({
  issue,
  onUpdate,
  company,
}: {
  issue: Issue;
  onUpdate: (u: Partial<UpdateIssueRequest>) => void;
  company?: Company;
}) {
  const { getActorName } = useActorName();
  const board = useBoard();
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <StatusPicker
        status={issue.status}
        onUpdate={onUpdate}
        projectId={issue.project_id}
        issue={issue}
        triggerRender={pillEl}
        trigger={
          <>
            <Dot color={board.colorOf(issue.status)} />
            {board.nameOf(issue.status)}
          </>
        }
      />
      <PriorityPicker
        priority={issue.priority}
        onUpdate={onUpdate}
        triggerRender={pillEl}
        trigger={
          <>
            <Dot color={priorityColor(issue.priority).ring} />
            {issue.priority === "none" ? "Priorità" : PRIORITY_IT[issue.priority]}
          </>
        }
      />
      <DueDatePicker
        dueDate={issue.due_date}
        onUpdate={onUpdate}
        triggerRender={pillEl}
        trigger={issue.due_date ? formatDueIt(issue.due_date) : <span className="text-[#666666]">Scadenza</span>}
      />
      <AssigneePicker
        assigneeType={issue.assignee_type}
        assigneeId={issue.assignee_id}
        onUpdate={onUpdate}
        triggerRender={pillEl}
        trigger={
          issue.assignee_type && issue.assignee_id ? (
            <>
              <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="xs" />
              <span className="truncate">{getActorName(issue.assignee_type, issue.assignee_id)}</span>
            </>
          ) : (
            <span className="text-[#666666]">Assegna</span>
          )
        }
      />
      <div className="flex min-w-0 [&>div]:min-w-0">
        <ProjectPicker projectId={issue.project_id} onUpdate={onUpdate} triggerRender={pillEl} />
      </div>
      {company ? (
        <span className={cn(pillCls, "cursor-default hover:bg-[#f6f4f1]")} title={company.claude_config_dir ?? "Profilo predefinito"}>
          <span className="size-2 rounded-full" style={{ background: company.color ?? CALM.primary }} />
          Profilo Claude: {company.name}
        </span>
      ) : null}
    </div>
  );
}

/* ---------- Sub-issues ---------- */

function SubIssues({ issueId }: { issueId: string }) {
  const wsId = useWorkspaceId();
  const paths = useWorkspacePaths();
  const update = useUpdateIssue();
  const { data: children = [] } = useQuery(childIssuesOptions(wsId, issueId));
  if (children.length === 0) return null;
  const doneCount = children.filter((c) => c.status === "done").length;
  return (
    <div className="flex max-w-[720px] flex-col gap-0.5">
      <span className="mb-1.5 text-sm font-semibold">
        Sotto-task · {doneCount} di {children.length}
      </span>
      {children.map((c) => {
        const done = c.status === "done";
        return (
          <div key={c.id} className="flex min-h-[38px] items-center gap-3 text-[15px]">
            <PriorityCircle
              priority={c.priority}
              done={done}
              size={18}
              onComplete={() => update.mutate({ id: c.id, status: done ? "todo" : "done" })}
              label={done ? `Riapri "${c.title}"` : `Completa "${c.title}"`}
            />
            <AppLink
              href={paths.issueDetail(c.identifier || c.id)}
              className={cn("min-w-0 flex-1 truncate no-underline", done ? "text-[#666666]" : "text-[#202020]")}
            >
              {c.title}
            </AppLink>
          </div>
        );
      })}
    </div>
  );
}

/* ---------- Page ---------- */

function Header({ issue, onDone, crumb }: { issue: Issue; onDone: () => void; crumb: string }) {
  const paths = useWorkspacePaths();
  const backOrReplace = useBackOrReplace();
  const done = issue.status === "done";
  return (
    <header className="flex items-center gap-2 px-3.5 py-2.5 md:gap-3 md:px-6 md:py-3">
      <button
        type="button"
        aria-label="Indietro"
        onClick={() => backOrReplace(paths.issues())}
        className="inline-flex size-8 shrink-0 items-center justify-center rounded-lg text-[#202020] hover:bg-[#f6f4f1]"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M15 18l-6-6 6-6" />
        </svg>
      </button>
      <span className="min-w-0 flex-1 truncate text-[13px] text-[#666666]">{crumb}</span>
      <AppLink
        href={`${paths.issueDetail(issue.identifier || issue.id)}?classica=1`}
        className="hidden text-[13px] text-[#666666] no-underline hover:text-[#202020] md:inline"
      >
        Vista completa
      </AppLink>
      <button
        type="button"
        onClick={onDone}
        className={cn(
          "h-8 shrink-0 rounded-lg border px-3 text-[13px] font-medium",
          done ? "border-transparent bg-[#058527] text-white" : "border-black/[0.12] bg-white text-[#202020] hover:bg-[#fcfaf8]",
        )}
      >
        {done ? "Fatto ✓" : "Segna come fatto"}
      </button>
    </header>
  );
}

/** Notion-like body: edits save on their own after a short pause. */
function ContentBlock({ issue }: { issue: Issue }) {
  const update = useUpdateIssue();
  const inFlight = useRef(false);
  const pending = useRef<{ markdown: string; base: string } | null>(null);

  const save = (markdown: string, base: string) => {
    if (inFlight.current) {
      pending.current = { markdown, base };
      return;
    }
    inFlight.current = true;
    update.mutate(
      { id: issue.id, description: markdown, description_base: base },
      {
        onSettled: () => {
          inFlight.current = false;
          const next = pending.current;
          pending.current = null;
          if (next) save(next.markdown, markdown);
        },
      },
    );
  };

  return (
    <div className="calm-content text-sm leading-[1.7] text-[#202020]">
      <ContentEditor
        key={issue.id}
        value={issue.description ?? ""}
        placeholder="Scrivi qui i dettagli. # per un titolo, - per una lista, [] per una checklist."
        onUpdate={(md, base) => save(md, base)}
        debounceMs={1200}
        flushPendingOnUnmount
        currentIssueId={issue.id}
      />
    </div>
  );
}

function TitleBlock({ issue, onDone }: { issue: Issue; onDone: () => void }) {
  const update = useUpdateIssue();
  return (
    <div className="flex items-start gap-3">
      <div className="pt-[7px] md:pt-2">
        <PriorityCircle
          priority={issue.priority}
          done={issue.status === "done"}
          size={20}
          onComplete={onDone}
          label={issue.status === "done" ? "Riapri" : "Segna come fatto"}
        />
      </div>
      <TitleEditor
        key={`title-${issue.id}`}
        defaultValue={issue.title}
        placeholder="Titolo"
        className="w-full text-[22px] font-semibold leading-tight tracking-[-0.01em] md:text-2xl"
        onBlur={(value) => {
          const t = value.trim();
          if (t && t !== issue.title) update.mutate({ id: issue.id, title: t, title_base: issue.title });
        }}
      />
    </div>
  );
}

function CalmDetailBody({ issueId }: { issueId: string }) {
  const wsId = useWorkspaceId();
  const { data: issue } = useQuery(issueDetailOptions(wsId, issueId));
  const { data: projects = [] } = useQuery(projectListOptions(wsId));
  const { data: companies = [] } = useQuery(companyListOptions(wsId));
  const update = useUpdateIssue();
  const user = useAuthStore((s) => s.user);
  const { timeline, loading, submitComment } = useIssueTimeline(issueId, user?.id);

  if (!issue) return <DetailSkeleton />;
  const project = projects.find((p) => p.id === issue.project_id);
  const company = project?.company_id ? companies.find((c) => c.id === project.company_id) : undefined;
  const crumb = [company?.name, project?.title, issue.identifier].filter(Boolean).join("  /  ");
  const onUpdate = (u: Partial<UpdateIssueRequest>) => update.mutate({ id: issue.id, ...u });
  const markDone = () => onUpdate({ status: issue.status === "done" ? "todo" : "done" });

  return (
    <div className="flex h-full min-h-0 flex-col bg-white font-sans text-[#202020]">
      <Header issue={issue} onDone={markDone} crumb={crumb} />
      <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
        <article className="mx-auto flex w-full max-w-[720px] flex-col gap-4 px-[22px] pb-10 pt-3 md:px-10 md:pt-8">
          <TitleBlock issue={issue} onDone={markDone} />
          <div className="md:pl-8">
            <PropertyPills issue={issue} onUpdate={onUpdate} company={company} />
          </div>
          <div className="md:pl-8">
            <Runs issueId={issue.id} compact />
          </div>
          <div className="md:pl-8">
            <ContentBlock issue={issue} />
          </div>
          <div className="md:pl-8">
            <SubIssues issueId={issue.id} />
          </div>

          <div className="mt-4 h-px bg-black/[0.08] md:ml-8" />

          <section className="flex flex-col gap-4 md:pl-8">
            <h2 className="m-0 text-[13px] font-medium text-[#666666]">Commenti</h2>
            <Feed timeline={timeline} loading={loading} />
            <Composer issueId={issue.id} submitComment={submitComment} />
          </section>

          <details className="group md:pl-8">
            <summary className="cursor-pointer list-none text-[13px] text-[#666666] hover:text-[#202020]">
              Esecuzioni dell’agente
            </summary>
            <div className="pt-3">
              <Runs issueId={issue.id} hideActive />
            </div>
          </details>
        </article>
      </div>
    </div>
  );
}

function DetailSkeleton() {
  return (
    <div className="flex flex-col gap-4 p-8">
      <div className="h-8 w-2/3 animate-pulse rounded-lg bg-[#f6f4f1]" />
      <div className="h-4 w-1/2 animate-pulse rounded bg-[#f6f4f1]" />
      <div className="h-24 animate-pulse rounded-xl bg-[#f6f4f1]" />
    </div>
  );
}

function NotFound() {
  const paths = useWorkspacePaths();
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 p-8 text-center font-sans">
      <p className="text-lg font-medium text-[#202020]">Task non trovato</p>
      <AppLink href={paths.issues()} className="text-sm text-[#dc4c3e]">
        Torna alla lista
      </AppLink>
    </div>
  );
}

export function CalmIssueDetail({ routeId, classic }: { routeId: string; classic?: boolean }) {
  const wsId = useWorkspaceId();
  const { canonicalId, isResolving, notFound } = useCanonicalIssue(wsId, routeId);
  if (classic) return <IssueDetailRoute routeId={routeId} />;
  if (isResolving) return <DetailSkeleton />;
  if (notFound || !canonicalId) return <NotFound />;
  return <CalmDetailBody key={canonicalId} issueId={canonicalId} />;
}
