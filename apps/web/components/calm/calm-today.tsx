"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useCreateIssue, useUpdateIssue } from "@multica/core/issues";
import { useWorkspacePaths } from "@multica/core/paths";
import { useActorName } from "@multica/core/workspace";
import type { AgentTask, Issue, Project } from "@multica/core/types";
import { AppLink } from "@multica/views/navigation";
import { ActorAvatar } from "@multica/views/common/actor-avatar";
import { cn } from "@multica/ui/lib/utils";
import {
  byPriorityThenDue,
  calmColumn,
  formatDueIt,
  isOpen,
  minutesSince,
  PriorityCircle,
  relativeIt,
  RunningDot,
  statusLabel,
  useCalmData,
} from "./shared";
import { PlusIcon } from "./calm-shell";

const NUM_WORDS = ["Niente", "Una cosa", "Due cose", "Tre cose"];

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
function useComplete() {
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
    <span className="inline-flex h-8 max-w-[180px] shrink-0 items-center gap-2 rounded-full bg-[#f6f4f1] pl-1 pr-3 text-[13px] text-[#4b4b4b]">
      <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="md" />
      <span className="truncate">{name}</span>
    </span>
  );
}

function TaskRow({
  issue,
  project,
  running,
  completing,
  onComplete,
}: {
  issue: Issue;
  project?: Project;
  running?: AgentTask;
  completing: boolean;
  onComplete: () => void;
}) {
  const paths = useWorkspacePaths();
  const meta = [project?.title, issue.identifier, issue.due_date ? formatDueIt(issue.due_date) : null].filter(Boolean);
  return (
    <AppLink
      href={paths.issueDetail(issue.identifier || issue.id)}
      className={cn(
        "flex items-start gap-3.5 border-b border-black/[0.08] py-4 text-[#202020] no-underline transition-opacity duration-300 md:items-center md:gap-4 md:px-1.5",
        completing && "opacity-40",
      )}
    >
      <span className="pt-px md:pt-0">
        <PriorityCircle priority={issue.priority} done={completing} onComplete={onComplete} label={`Completa "${issue.title}"`} />
      </span>
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <span className={cn("text-base font-medium leading-snug md:text-[17px]", completing && "line-through")}>{issue.title}</span>
        <span className="flex min-w-0 items-center gap-2.5 text-[13px] text-[#666666] md:gap-3.5">
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
      <span className="hidden w-[110px] shrink-0 text-right text-[13px] text-[#666666] md:inline">{statusLabel(issue)}</span>
    </AppLink>
  );
}

function QuickAdd() {
  const create = useCreateIssue();
  const [title, setTitle] = useState("");
  const submit = () => {
    const t = title.trim();
    if (!t) return;
    create.mutate({ title: t, status: "todo" }, { onSuccess: () => setTitle("") });
  };
  return (
    <label className="flex h-12 w-full items-center gap-2.5 rounded-xl border border-black/[0.08] bg-[#f6f4f1] px-4 lg:w-[420px]">
      <span className="text-[#666666]"><PlusIcon /></span>
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
        className="min-w-0 flex-1 border-0 bg-transparent text-[15px] text-[#202020] outline-none placeholder:text-[#666666]"
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
    <div className="flex flex-col gap-3.5 rounded-[18px] bg-[#202020] p-6 text-white">
      <span className="text-sm text-white/70">Adesso</span>
      <AppLink href={paths.issueDetail(issue.identifier || issue.id)} className="text-[22px] font-medium leading-tight text-white no-underline hover:underline">
        {issue.title}
      </AppLink>
      <span className="text-5xl font-normal tabular-nums tracking-[-0.02em]">{mm}:{ss}</span>
      <button
        type="button"
        onClick={() => {
          setNow(Date.now());
          setEndsAt(endsAt ? null : Date.now() + 25 * 60_000);
        }}
        className="h-11 rounded-xl bg-[#dc4c3e] text-[15px] font-semibold text-white active:scale-[0.98]"
      >
        {endsAt ? "Ferma focus" : "Inizia focus"}
      </button>
    </div>
  );
}

function SectionTitle({ children, className }: { children: ReactNode; className?: string }) {
  return <h2 className={cn("mb-1.5 mt-2 text-[15px] font-semibold text-[#202020]", className)}>{children}</h2>;
}

export function CalmToday({ toggle }: { toggle: ReactNode }) {
  const { issues, projectById, runningByIssue, agentName, loading } = useCalmData();
  const { completing, complete } = useComplete();
  const paths = useWorkspacePaths();
  const now = useNow();
  const [showLater, setShowLater] = useState(false);

  const { focus, withClaude, later, openCount, recent } = useMemo(() => {
    const open = issues.filter(isOpen);
    const withClaude = open.filter((i) => runningByIssue.has(i.id));
    const candidates = open
      .filter((i) => i.status !== "backlog" && !runningByIssue.has(i.id))
      .sort(byPriorityThenDue);
    const focus = candidates.slice(0, 3);
    const shown = new Set([...focus, ...withClaude].map((i) => i.id));
    const later = open.filter((i) => !shown.has(i.id)).sort(byPriorityThenDue);
    const recent = [...issues].sort((a, b) => b.updated_at.localeCompare(a.updated_at)).slice(0, 3);
    return { focus, withClaude, later, openCount: open.length, recent };
  }, [issues, runningByIssue]);

  const laterGroups = useMemo(() => {
    const groups: { key: string; label: string; items: Issue[] }[] = [
      { key: "doing", label: "In corso", items: [] },
      { key: "review", label: "In revisione", items: [] },
      { key: "todo", label: "Da fare", items: [] },
      { key: "backlog", label: "Backlog", items: [] },
    ];
    for (const i of later) {
      const key = i.status === "backlog" ? "backlog" : calmColumn(i);
      groups.find((g) => g.key === key)?.items.push(i);
    }
    return groups.filter((g) => g.items.length > 0);
  }, [later]);

  const top = focus[0];
  const heading = `${greeting(now)}. ${NUM_WORDS[focus.length] ?? "Tre cose"} per oggi.`;

  const row = (i: Issue) => (
    <TaskRow
      key={i.id}
      issue={i}
      project={i.project_id ? projectById.get(i.project_id) : undefined}
      running={runningByIssue.get(i.id)}
      completing={completing.has(i.id)}
      onComplete={() => complete(i.id)}
    />
  );

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto bg-white font-sans text-[#202020]">
      {/* Header */}
      <header className="flex flex-col gap-4 px-[22px] pb-2.5 pt-6 md:px-14 md:pb-5 md:pt-9 lg:flex-row lg:items-center">
        <div className="flex min-w-0 flex-1 items-start gap-3">
          <div className="min-w-0 flex-1">
            <h1 className="m-0 text-[30px] font-semibold leading-tight tracking-[-0.01em] md:text-[34px] md:font-medium md:tracking-[-0.02em]">
              <span className="md:hidden">Oggi</span>
              <span className="hidden md:inline">{heading}</span>
            </h1>
            <p className="mt-1 text-sm text-[#666666] md:mt-1.5 md:text-[15px]">
              <span className="hidden md:inline">{todayLine(now)} · </span>
              {focus.length} task in focus · {openCount} aperti
            </p>
          </div>
          <div className="lg:hidden">{toggle}</div>
        </div>
        <div className="hidden items-center gap-3 md:flex">
          <QuickAdd />
        </div>
      </header>

      {/* Phone: compact "Adesso" card */}
      {top ? (
        <div className="mx-[22px] mb-1.5 mt-2.5 flex items-center gap-3 rounded-[14px] bg-[#f6f4f1] px-4 py-3.5 md:hidden">
          <div className="flex min-w-0 flex-1 flex-col gap-0.5">
            <span className="text-[13px] text-[#666666]">Adesso</span>
            <span className="truncate text-[15px] font-semibold">{top.title}</span>
          </div>
          <AppLink
            href={paths.issueDetail(top.identifier || top.id)}
            className="inline-flex h-11 shrink-0 items-center rounded-xl bg-[#dc4c3e] px-4 text-sm font-semibold text-white no-underline"
          >
            Inizia focus
          </AppLink>
        </div>
      ) : null}

      <div className="flex min-h-0 flex-1 gap-8 px-[22px] pb-10 pt-1.5 md:px-14 md:pt-2">
        <section className="flex min-w-0 flex-1 flex-col">
          <SectionTitle className="hidden md:block">Focus di oggi</SectionTitle>
          {loading ? (
            <div className="flex flex-col gap-3 py-4">
              {[0, 1, 2].map((k) => (
                <div key={k} className="h-14 animate-pulse rounded-xl bg-[#f6f4f1]" />
              ))}
            </div>
          ) : focus.length === 0 ? (
            <p className="py-6 text-[15px] text-[#666666]">Niente in programma. Respira, oppure aggiungi un task.</p>
          ) : (
            focus.map(row)
          )}

          <SectionTitle className="mt-6 text-sm text-[#4b4b4b] md:mt-[26px] md:text-[15px] md:text-[#202020]">
            Con Claude adesso
          </SectionTitle>
          {withClaude.length === 0 ? (
            <p className="py-2 text-sm text-[#666666]">Nessun agente al lavoro in questo momento.</p>
          ) : (
            withClaude.map((i) => {
              const t = runningByIssue.get(i.id)!;
              return (
                <AppLink
                  key={i.id}
                  href={paths.issueDetail(i.identifier || i.id)}
                  className="flex items-center gap-3 rounded-[14px] py-3 text-[15px] text-[#4b4b4b] no-underline hover:bg-[#fcfaf8] md:gap-[18px] md:px-[22px] md:py-3.5"
                >
                  <RunningDot className="mx-[7px]" />
                  <span className="min-w-0 flex-1 truncate">{i.title}</span>
                  <span className="shrink-0 text-xs text-[#666666] md:rounded-md md:bg-[#f6f4f1] md:px-2 md:py-1 md:font-mono">
                    {agentName(t.agent_id)} · {minutesSince(t.started_at ?? t.dispatched_at, now.getTime())} min
                  </span>
                  <span className="hidden w-[110px] shrink-0 text-right text-[13px] text-[#666666] md:inline">in esecuzione</span>
                </AppLink>
              );
            })
          )}

          {later.length > 0 ? (
            <button
              type="button"
              onClick={() => setShowLater((v) => !v)}
              aria-expanded={showLater}
              className="mt-3 h-11 self-start rounded-xl text-sm text-[#4b4b4b] md:mt-[18px] md:border md:border-dashed md:border-black/20 md:px-[18px] md:hover:bg-[#fcfaf8]"
            >
              {showLater ? "Nascondi" : `Mostra più tardi (${later.length} ${later.length === 1 ? "task nascosto" : "task nascosti"})`}
            </button>
          ) : null}

          {showLater
            ? laterGroups.map((g) => (
                <div key={g.key} className="mt-4">
                  <SectionTitle className="text-sm text-[#4b4b4b]">
                    {g.label} <span className="font-normal text-[#666666]">{g.items.length}</span>
                  </SectionTitle>
                  {g.items.map(row)}
                </div>
              ))
            : null}
        </section>

        {/* Desktop right column */}
        <aside className="hidden w-[300px] shrink-0 flex-col gap-4 lg:flex">
          {top ? <FocusTimer issue={top} /> : null}
          {recent.length > 0 ? (
            <div className="flex flex-col gap-3 rounded-[18px] bg-[#f6f4f1] p-[22px] text-sm text-[#4b4b4b]">
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
