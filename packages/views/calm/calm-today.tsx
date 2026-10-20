"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useCreateIssue, useUpdateIssue } from "@multica/core/issues";
import { useWorkspacePaths } from "@multica/core/paths";
import { useActorName } from "@multica/core/workspace";
import type { AgentTask, Issue, Project } from "@multica/core/types";
import { AppLink } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { cn } from "@multica/ui/lib/utils";
import {
  byPriorityThenDue,
  formatDueIt,
  isOpen,
  minutesSince,
  PriorityCircle,
  relativeIt,
  RunningDot,
  statusLabel,
  useCalmData,
} from "./shared";
import { Plus } from "lucide-react";


function greeting(d: Date) {
  const h = d.getHours();
  if (h < 5) return "Buonanotte";
  if (h < 13) return "Buongiorno";
  if (h < 18) return "Buon pomeriggio";
  return "Buonasera";
}

function todayLine(d: Date) {
  const s = d.toLocaleDateString("it-IT", { weekday: "long", day: "numeric", month: "long" });
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** Minute-resolution clock so greetings and "N min" labels stay fresh. */
function useNow(intervalMs = 30_000) {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}

/** Completing fills the circle, lets the row fade, then writes status=done. */
export function useComplete() {
  const update = useUpdateIssue();
  const [completing, setCompleting] = useState<Set<string>>(new Set());
  const complete = (id: string) => {
    setCompleting((s) => new Set(s).add(id));
    window.setTimeout(() => {
      update.mutate(
        { id, status: "done" },
        {
          onSettled: () =>
            setCompleting((s) => {
              const n = new Set(s);
              n.delete(id);
              return n;
            }),
        },
      );
    }, 450);
  };
  return { completing, complete };
}

function AssigneeChip({ issue, compact }: { issue: Issue; compact?: boolean }) {
  const { getActorName } = useActorName();
  if (!issue.assignee_type || !issue.assignee_id) return null;
  const name = getActorName(issue.assignee_type, issue.assignee_id);
  if (compact) return <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="sm" />;
  return (
    <span className="inline-flex h-6 max-w-[160px] shrink-0 items-center gap-1.5 rounded-full bg-[#f6f4f1] pl-0.5 pr-2.5 text-xs text-[#4b4b4b]">
      <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="sm" />
      <span className="truncate">{name}</span>
    </span>
  );
}

export function TaskRow({
  issue,
  project,
  companyName,
  running,
  completing,
  onComplete,
  hideStatus,
}: {
  issue: Issue;
  project?: Project;
  companyName?: string;
  running?: AgentTask;
  completing: boolean;
  onComplete: () => void;
  hideStatus?: boolean;
}) {
  const paths = useWorkspacePaths();
  const meta = [companyName, project?.title, issue.identifier, issue.due_date ? formatDueIt(issue.due_date) : null].filter(Boolean);
  return (
    <AppLink
      href={paths.issueDetail(issue.identifier || issue.id)}
      className={cn(
        "flex items-start gap-3 border-b border-black/[0.06] py-2.5 text-[#202020] no-underline transition-opacity duration-300 hover:bg-[#fcfaf8] md:items-center md:px-1.5",
        completing && "opacity-40",
      )}
    >
      <span className="pt-px md:pt-0">
        <PriorityCircle priority={issue.priority} done={completing} size={18} onComplete={onComplete} label={`Completa "${issue.title}"`} />
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className={cn("text-sm leading-snug", completing && "line-through")}>{issue.title}</span>
        <span className="flex min-w-0 items-center gap-2.5 text-xs text-[#666666]">
          {meta.map((m, i) => (
            <span key={i} className="truncate">{m}</span>
          ))}
          {running ? (
            <span className="inline-flex items-center gap-1.5 text-[#058527]">
              <RunningDot />
              in esecuzione
            </span>
          ) : null}
          <span className="flex-1 md:hidden" />
          <span className="md:hidden"><AssigneeChip issue={issue} compact /></span>
        </span>
      </div>
      <span className="hidden md:inline-flex"><AssigneeChip issue={issue} /></span>
      {hideStatus ? null : <span className="hidden w-[100px] shrink-0 text-right text-xs text-[#666666] md:inline">{statusLabel(issue)}</span>}
    </AppLink>
  );
}

export function QuickAdd({ projectId, status = "todo", className }: { projectId?: string | null; status?: string; className?: string }) {
  const create = useCreateIssue();
  const [title, setTitle] = useState("");
  const submit = () => {
    const t = title.trim();
    if (!t) return;
    create.mutate({ title: t, status, ...(projectId ? { project_id: projectId } : {}) }, { onSuccess: () => setTitle("") });
  };
  return (
    <label className={cn("flex h-9 w-full items-center gap-2 rounded-lg border border-black/[0.08] bg-[#f6f4f1] px-3 lg:w-[340px]", className)}>
      <span className="text-[#666666]"><Plus size={15} strokeWidth={1.75} aria-hidden /></span>
      <span className="sr-only">Nuovo task</span>
      <input
        type="text"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.nativeEvent.isComposing) submit();
        }}
        disabled={create.isPending}
        placeholder="Aggiungi un task… premi Invio"
        className="min-w-0 flex-1 border-0 bg-transparent text-[13px] text-[#202020] outline-none placeholder:text-[#666666]"
      />
    </label>
  );
}

function FocusTimer({ issue }: { issue: Issue }) {
  const paths = useWorkspacePaths();
  const [endsAt, setEndsAt] = useState<number | null>(null);
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!endsAt) return;
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [endsAt]);
  const left = endsAt ? Math.max(0, endsAt - now) : 25 * 60_000;
  const mm = String(Math.floor(left / 60_000)).padStart(2, "0");
  const ss = String(Math.floor((left % 60_000) / 1000)).padStart(2, "0");
  return (
    <div className="flex flex-col gap-2.5 rounded-xl bg-[#202020] p-4 text-white">
      <span className="text-xs text-white/70">Adesso</span>
      <AppLink href={paths.issueDetail(issue.identifier || issue.id)} className="text-[15px] font-medium leading-snug text-white no-underline hover:underline">
        {issue.title}
      </AppLink>
      <span className="text-[32px] font-normal leading-none tabular-nums tracking-[-0.02em]">{mm}:{ss}</span>
      <button
        type="button"
        onClick={() => {
          setNow(Date.now());
          setEndsAt(endsAt ? null : Date.now() + 25 * 60_000);
        }}
        className="h-8 rounded-lg bg-[#dc4c3e] text-[13px] font-semibold text-white active:scale-[0.98]"
      >
        {endsAt ? "Ferma focus" : "Inizia focus"}
      </button>
    </div>
  );
}

function SectionTitle({ children, className }: { children: ReactNode; className?: string }) {
  return <h2 className={cn("mb-1 mt-2 text-[13px] font-semibold text-[#202020]", className)}>{children}</h2>;
}

function localISO(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

/** Open tasks due today or earlier. Shared with the sidebar badge. */
export function useDueToday() {
  const { issues } = useCalmData();
  const now = useNow();
  const today = localISO(now);
  return useMemo(() => {
    const open = issues.filter(isOpen);
    const overdue = open.filter((i) => i.due_date && i.due_date < today).sort(byPriorityThenDue);
    const dueToday = open.filter((i) => i.due_date === today).sort(byPriorityThenDue);
    return { overdue, dueToday, today };
  }, [issues, today]);
}

export function CalmToday() {
  const { issues, projectById, companyOf, runningByIssue, agentName, loading } = useCalmData();
  const { completing, complete } = useComplete();
  const { overdue, dueToday } = useDueToday();
  const paths = useWorkspacePaths();
  const now = useNow();

  const withClaude = useMemo(() => issues.filter((i) => isOpen(i) && runningByIssue.has(i.id)), [issues, runningByIssue]);
  const recent = useMemo(() => [...issues].sort((a, b) => b.updated_at.localeCompare(a.updated_at)).slice(0, 3), [issues]);
  const top = overdue[0] ?? dueToday[0];
  const total = overdue.length + dueToday.length;

  const row = (i: Issue) => (
    <TaskRow
      key={i.id}
      issue={i}
      project={i.project_id ? projectById.get(i.project_id) : undefined}
      companyName={companyOf(i)?.name}
      running={runningByIssue.get(i.id)}
      completing={completing.has(i.id)}
      onComplete={() => complete(i.id)}
    />
  );

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto bg-white font-sans text-[#202020]">
      <header className="flex flex-col gap-3 px-[22px] pb-2 pt-5 md:px-8 md:pb-3 md:pt-6 lg:flex-row lg:items-center">
        <div className="min-w-0 flex-1">
          <h1 className="m-0 text-xl font-semibold leading-tight tracking-[-0.01em]">Oggi</h1>
          <p className="m-0 mt-0.5 text-[13px] text-[#666666]">
            {todayLine(now)} · {total === 0 ? "niente in scadenza" : `${total} ${total === 1 ? "task" : "task"} da chiudere`}
          </p>
        </div>
      </header>

      <div className="flex min-h-0 flex-1 gap-6 px-[22px] pb-10 pt-1 md:px-8">
        <section className="flex min-w-0 flex-1 flex-col">
          {loading ? (
            <div className="flex flex-col gap-2 py-2">
              {[0, 1, 2].map((k) => (
                <div key={k} className="h-10 animate-pulse rounded-lg bg-[#f6f4f1]" />
              ))}
            </div>
          ) : (
            <>
              {overdue.length > 0 ? (
                <>
                  <SectionTitle className="text-[#d1453b]">In ritardo</SectionTitle>
                  {overdue.map(row)}
                </>
              ) : null}
              <SectionTitle className={overdue.length > 0 ? "mt-6" : undefined}>
                {greeting(now)}, ecco oggi
              </SectionTitle>
              {dueToday.length === 0 ? (
                <p className="py-3 text-sm text-[#666666]">Nessun task in scadenza oggi.</p>
              ) : (
                dueToday.map(row)
              )}
            </>
          )}

          <SectionTitle className="mt-6">Con Claude adesso</SectionTitle>
          {withClaude.length === 0 ? (
            <p className="py-2 text-sm text-[#666666]">Nessun agente al lavoro in questo momento.</p>
          ) : (
            withClaude.map((i) => {
              const t = runningByIssue.get(i.id)!;
              return (
                <AppLink
                  key={i.id}
                  href={paths.issueDetail(i.identifier || i.id)}
                  className="flex items-center gap-3 rounded-lg py-2 text-sm text-[#4b4b4b] no-underline hover:bg-[#fcfaf8] md:px-1.5"
                >
                  <RunningDot className="mx-[5px]" />
                  <span className="min-w-0 flex-1 truncate">{i.title}</span>
                  <span className="shrink-0 text-xs text-[#666666]">
                    {agentName(t.agent_id)} · {minutesSince(t.started_at ?? t.dispatched_at, now.getTime())} min
                  </span>
                </AppLink>
              );
            })
          )}
        </section>

        <aside className="hidden w-[260px] shrink-0 flex-col gap-3 lg:flex">
          {top ? <FocusTimer issue={top} /> : null}
          {recent.length > 0 ? (
            <div className="flex flex-col gap-2 rounded-xl bg-[#f6f4f1] p-4 text-[13px] text-[#4b4b4b]">
              <span className="font-semibold text-[#202020]">Ultimi aggiornamenti</span>
              {recent.map((i) => (
                <AppLink key={i.id} href={paths.issueDetail(i.identifier || i.id)} className="text-[#4b4b4b] no-underline hover:text-[#202020]">
                  “{i.title}” · {statusLabel(i).toLowerCase()} · {relativeIt(i.updated_at, now.getTime())}
                </AppLink>
              ))}
            </div>
          ) : null}
        </aside>
      </div>
    </div>
  );
}
