"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
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
import { useActorName } from "@multica/core/workspace";
import type { AgentTask, Issue, TimelineEntry, UpdateIssueRequest } from "@multica/core/types";
import { AppLink, useBackOrReplace } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { ReadonlyContent } from "../editor";
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
import { useIsMobile } from "@multica/ui/hooks/use-mobile";
import {
  CALM,
  formatDueIt,
  minutesSince,
  PRIORITY_IT,
  priorityColor,
  PriorityCircle,
  relativeIt,
  STATUS_DOT,
  statusLabel,
} from "./shared";

const ACTIVE_TASK = new Set<AgentTask["status"]>(["queued", "dispatched", "running", "waiting_local_directory", "deferred"]);

const STATUS_PILL: Record<string, { bg: string; fg: string }> = {
  in_progress: { bg: "rgba(5,133,39,0.10)", fg: "#046b20" },
  in_review: { bg: "rgba(36,111,224,0.10)", fg: "#1d5bba" },
  done: { bg: "rgba(36,111,224,0.10)", fg: "#1d5bba" },
  blocked: { bg: "rgba(209,69,59,0.10)", fg: "#b03a31" },
};

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
            <ActorAvatar actorType={e.actor_type} actorId={e.actor_id} name={e.actor_name} avatarUrl={e.actor_avatar_url} size="lg" />
            <div className="flex min-w-0 flex-1 flex-col gap-1.5 rounded-xl bg-[#f6f4f1] px-3 py-2.5 md:gap-2 md:rounded-[14px] md:border md:border-black/[0.08] md:bg-white md:px-4 md:py-3">
              <div className="flex items-center gap-2 text-[13px] md:text-sm">
                <span className="font-semibold">{who(e)}</span>
                {e.actor_type === "agent" ? (
                  <span className="inline-flex h-5 items-center rounded-md bg-[#f6f4f1] px-[7px] text-[11px] font-semibold text-[#4b4b4b] md:bg-[#f6f4f1]">
                    agente
                  </span>
                ) : null}
                <span className="ml-auto shrink-0 text-xs text-[#666666]">{relativeIt(e.created_at, now)}</span>
              </div>
              <ReadonlyContent content={e.content ?? ""} attachments={e.attachments} className="text-sm leading-relaxed text-[#202020] md:text-[15px]" />
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
      <div className="flex items-center gap-2.5 rounded-xl bg-[#202020] px-3.5 py-3 text-white">
        <span className="size-2 shrink-0 rounded-full bg-[#7ecc49]" />
        <span className="min-w-0 flex-1 truncate text-[13px]">
          {getActorName("agent", t.agent_id)} {t.status === "running" ? "sta lavorando" : "in coda"}
        </span>
        <span className="shrink-0 text-[13px] text-white/70">{minutesSince(t.started_at ?? t.dispatched_at, now)} min</span>
        <button type="button" onClick={() => setOpenId(t.id)} className="h-8 shrink-0 rounded-lg bg-white/[0.12] px-2.5 text-xs font-semibold">
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

/* ---------- Properties ---------- */

function PropRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-h-10 items-center text-sm">
      <span className="w-[110px] shrink-0 text-[#666666]">{label}</span>
      <div className="flex min-w-0 flex-1">{children}</div>
    </div>
  );
}

function Dot({ color }: { color: string }) {
  return <span className="size-[9px] shrink-0 rounded-full" style={{ background: color }} />;
}

const triggerCls =
  "inline-flex min-w-0 max-w-full items-center gap-2 whitespace-nowrap rounded-lg px-1.5 py-1 -ml-1.5 text-left font-medium text-[#202020] hover:bg-black/[0.04]";
const triggerEl = <button type="button" className={triggerCls} />;

function Properties({ issue, onUpdate }: { issue: Issue; onUpdate: (u: Partial<UpdateIssueRequest>) => void }) {
  const { getActorName } = useActorName();
  return (
    <div className="flex flex-col gap-1">
      <PropRow label="Stato">
        <StatusPicker
          status={issue.status}
          onUpdate={onUpdate}
          projectId={issue.project_id}
          issue={issue}
          triggerRender={triggerEl}
          trigger={
            <>
              <Dot color={STATUS_DOT[issue.status] ?? "rgba(0,0,0,0.25)"} />
              {statusLabel(issue)}
            </>
          }
        />
      </PropRow>
      <PropRow label="Priorità">
        <PriorityPicker
          priority={issue.priority}
          onUpdate={onUpdate}
          triggerRender={triggerEl}
          trigger={
            <>
              <Dot color={priorityColor(issue.priority).ring} />
              {PRIORITY_IT[issue.priority]}
            </>
          }
        />
      </PropRow>
      <PropRow label="Assegnato a">
        <AssigneePicker
          assigneeType={issue.assignee_type}
          assigneeId={issue.assignee_id}
          onUpdate={onUpdate}
          triggerRender={triggerEl}
          trigger={
            <>
              {issue.assignee_type && issue.assignee_id ? (
                <>
                  <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="sm" />
                  <span className="truncate">{getActorName(issue.assignee_type, issue.assignee_id)}</span>
                </>
              ) : (
                <span className="text-[#666666]">Nessuno</span>
              )}
            </>
          }
        />
      </PropRow>
      <PropRow label="Progetto">
        <div className="flex min-w-0 flex-1 [&>div]:flex-1">
          <ProjectPicker projectId={issue.project_id} onUpdate={onUpdate} triggerRender={triggerEl} />
        </div>
      </PropRow>
      <PropRow label="Scadenza">
        <DueDatePicker
          dueDate={issue.due_date}
          onUpdate={onUpdate}
          triggerRender={triggerEl}
          trigger={
            <>
              <Dot color="rgba(0,0,0,0.25)" />
              {issue.due_date ? formatDueIt(issue.due_date, true) : <span className="text-[#666666]">Nessuna</span>}
            </>
          }
        />
      </PropRow>
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

function MobileHeader({ issue }: { issue: Issue }) {
  const wsId = useWorkspaceId();
  const paths = useWorkspacePaths();
  const backOrReplace = useBackOrReplace();
  const { data: projects = [] } = useQuery(projectListOptions(wsId));
  const project = projects.find((p) => p.id === issue.project_id);
  const crumb = [project?.title, issue.identifier].filter(Boolean).join(" · ");
  const pill = STATUS_PILL[issue.status] ?? { bg: "#f6f4f1", fg: "#4b4b4b" };
  return (
    <header className="flex items-center gap-2.5 px-3.5 pb-1.5 pt-3">
      <button
        type="button"
        aria-label="Indietro"
        onClick={() => backOrReplace(paths.issues())}
        className="inline-flex size-11 shrink-0 items-center justify-center rounded-xl text-[#202020]"
      >
      <svg width={22} height={22} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M15 18l-6-6 6-6" />
      </svg>
      </button>
      <span className="min-w-0 flex-1 truncate text-sm text-[#666666]">{crumb}</span>
      <span className="mr-2 inline-flex h-7 shrink-0 items-center rounded-full px-3 text-xs font-semibold" style={{ background: pill.bg, color: pill.fg }}>
        {statusLabel(issue)}
      </span>
    </header>
  );
}

function DesktopHeader({ issue, onDone }: { issue: Issue; onDone: () => void }) {
  const wsId = useWorkspaceId();
  const paths = useWorkspacePaths();
  const backOrReplace = useBackOrReplace();
  const { data: projects = [] } = useQuery(projectListOptions(wsId));
  const project = projects.find((p) => p.id === issue.project_id);
  const crumb = [project?.title, issue.identifier].filter(Boolean).join(" · ");
  const done = issue.status === "done";
  return (
    <header className="flex items-center gap-3.5 border-b border-black/[0.08] px-9 py-[18px]">
      <button
        type="button"
        aria-label="Torna alla lista"
        onClick={() => backOrReplace(paths.issues())}
        className="inline-flex size-11 items-center justify-center rounded-xl bg-[#f6f4f1] text-[#202020] hover:bg-[#efe9e2]"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <path d="M15 18l-6-6 6-6" />
        </svg>
      </button>
      <span className="text-sm text-[#666666]">{crumb}</span>
      <div className="flex-1" />
      <AppLink href={`${paths.issueDetail(issue.identifier || issue.id)}?classica=1`} className="text-[13px] text-[#666666] no-underline hover:text-[#202020]">
        Vista completa
      </AppLink>
      <button
        type="button"
        onClick={onDone}
        className={cn(
          "h-11 rounded-xl border px-[18px] text-sm font-medium",
          done ? "border-transparent bg-[#058527] text-white" : "border-black/[0.12] bg-white text-[#202020] hover:bg-[#fcfaf8]",
        )}
      >
        {done ? "Fatto ✓" : "Segna come fatto"}
      </button>
    </header>
  );
}

function Description({ issue }: { issue: Issue }) {
  if (!issue.description?.trim()) return null;
  return (
    <div className="max-w-[720px] text-[15px] leading-relaxed text-[#4b4b4b] md:text-base md:leading-[1.7]">
      <ReadonlyContent content={issue.description} />
    </div>
  );
}

function CalmDetailBody({ issueId }: { issueId: string }) {
  const wsId = useWorkspaceId();
  const { data: issue } = useQuery(issueDetailOptions(wsId, issueId));
  const update = useUpdateIssue();
  const { getActorName } = useActorName();
  const [tab, setTab] = useState<"dettagli" | "attivita">("attivita");
  const user = useAuthStore((s) => s.user);
  const { timeline, loading, submitComment } = useIssueTimeline(issueId, user?.id);
  const isMobile = useIsMobile();

  if (!issue) return <DetailSkeleton />;
  const onUpdate = (u: Partial<UpdateIssueRequest>) => update.mutate({ id: issue.id, ...u });
  const markDone = () => onUpdate({ status: issue.status === "done" ? "todo" : "done" });

  return (
    <div className="flex h-full min-h-0 flex-col bg-white font-sans text-[#202020]">
      {!isMobile ? (
      <div className="flex h-full min-h-0 flex-col">
        <DesktopHeader issue={issue} onDone={markDone} />
        <div className="flex min-h-0 flex-1">
          <section className="flex min-w-0 flex-1 flex-col">
            <div className="flex min-h-0 flex-1 flex-col gap-[22px] overflow-y-auto px-14 pb-8 pt-8">
              <h1 className="m-0 text-[30px] font-semibold leading-tight tracking-[-0.01em]">{issue.title}</h1>
              <Description issue={issue} />
              <SubIssues issueId={issue.id} />
              <div className="h-px max-w-[720px] shrink-0 bg-black/[0.08]" />
              <h2 className="m-0 text-[17px] font-semibold">Attività</h2>
              <div className="max-w-[720px]">
                <Feed timeline={timeline} loading={loading} />
              </div>
            </div>
            <div className="border-t border-black/[0.08] px-14 pb-6 pt-3.5">
              <Composer issueId={issue.id} submitComment={submitComment} />
            </div>
          </section>
          <aside className="flex w-[340px] shrink-0 flex-col gap-[22px] overflow-y-auto border-l border-black/[0.08] bg-[#fcfaf8] px-[26px] py-7 lg:w-[340px]">
            <Properties issue={issue} onUpdate={onUpdate} />
            <div className="h-px shrink-0 bg-black/[0.08]" />
            <Runs issueId={issue.id} />
          </aside>
        </div>
      </div>
      ) : (
      <div className="flex h-full min-h-0 flex-col">
        <MobileHeader issue={issue} />
        <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
          <div className="flex flex-col gap-3.5 px-[22px] pt-1.5">
            <h1 className="m-0 text-[25px] font-semibold leading-tight">{issue.title}</h1>
            <div className="flex flex-wrap items-center gap-2 text-[13px] text-[#666666]">
              {issue.assignee_type && issue.assignee_id ? (
                <span className="inline-flex h-8 items-center gap-1.5 rounded-full border border-black/10 pl-1 pr-3 text-[#202020]">
                  <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="md" />
                  {getActorName(issue.assignee_type, issue.assignee_id)}
                </span>
              ) : null}
              <span className="inline-flex items-center gap-1.5">
                <Dot color={priorityColor(issue.priority).ring} />
                {PRIORITY_IT[issue.priority]}
              </span>
              {issue.due_date ? <span>· {formatDueIt(issue.due_date)}</span> : null}
            </div>
            <Runs issueId={issue.id} compact />
          </div>

          <nav aria-label="Sezioni" className="sticky top-0 z-10 flex gap-[22px] border-b border-black/[0.08] bg-white px-[22px] pt-[18px]">
            {(
              [
                ["dettagli", "Dettagli"],
                ["attivita", "Attività"],
              ] as const
            ).map(([k, label]) => (
              <button
                key={k}
                type="button"
                aria-pressed={tab === k}
                onClick={() => setTab(k)}
                className={cn(
                  "pb-2.5 text-[15px]",
                  tab === k ? "border-b-2 border-[#dc4c3e] pb-2 font-semibold text-[#202020]" : "text-[#666666]",
                )}
              >
                {label}
              </button>
            ))}
          </nav>

          <div className="flex flex-col gap-5 px-[22px] pb-6 pt-4">
            {tab === "attivita" ? (
              <Feed timeline={timeline} loading={loading} />
            ) : (
              <>
                <Description issue={issue} />
                <SubIssues issueId={issue.id} />
                <Properties issue={issue} onUpdate={onUpdate} />
                <button
                  type="button"
                  onClick={markDone}
                  className="h-11 rounded-xl border border-black/[0.12] text-sm font-medium"
                >
                  {issue.status === "done" ? "Riapri" : "Segna come fatto"}
                </button>
                <Runs issueId={issue.id} hideActive />
              </>
            )}
          </div>
        </div>
        <div
          className="border-t border-black/[0.08] bg-white px-3.5 pt-2.5"
          style={{ paddingBottom: "calc(12px + env(safe-area-inset-bottom))" }}
        >
          <Composer issueId={issue.id} submitComment={submitComment} />
        </div>
      </div>
      )}
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
