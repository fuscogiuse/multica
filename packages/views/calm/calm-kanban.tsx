"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { useWorkspaceId } from "@multica/core/hooks";
import { useUpdateIssue } from "@multica/core/issues";
import { openCreateIssueWithPreference } from "@multica/core/issues/stores/create-mode-store";
import { useModalStore } from "@multica/core/modals";
import { useWorkspacePaths } from "@multica/core/paths";
import { agentListOptions } from "@multica/core/workspace";
import type { AgentTask, Company, Issue, IssueStatus, Project } from "@multica/core/types";
import { AppLink, useNavigation } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { cn } from "@multica/ui/lib/utils";
import { useIsMobile } from "@multica/ui/hooks/use-mobile";
import {
  byPriorityThenDue,
  calmColumn,
  CALM,
  ContextLabel,
  formatDueIt,
  type CalmColumn,
  useCalmData,
} from "./shared";

const COLUMNS: { key: CalmColumn; name: string; dot: string; status: IssueStatus }[] = [
  { key: "todo", name: "Da fare", dot: "rgba(0,0,0,0.25)", status: "todo" },
  { key: "doing", name: "In corso", dot: CALM.green, status: "in_progress" },
  { key: "review", name: "In revisione", dot: CALM.red, status: "in_review" },
  { key: "done", name: "Fatto", dot: CALM.blue, status: "done" },
];

const DONE_LIMIT = 8;

function KanbanCard({
  issue,
  project,
  company,
  running,
  draggable,
}: {
  issue: Issue;
  project?: Project;
  company?: Company;
  running?: AgentTask;
  draggable: boolean;
}) {
  const paths = useWorkspacePaths();
  return (
    <AppLink
      href={paths.issueDetail(issue.identifier || issue.id)}
      draggable={draggable}
      onDragStart={(e) => {
        e.dataTransfer.setData("text/calm-issue", issue.id);
        e.dataTransfer.effectAllowed = "move";
      }}
      className="flex flex-col gap-3 rounded-xl bg-white px-4 py-3.5 text-[#202020] no-underline shadow-[0_1px_2px_rgba(0,0,0,0.08)] transition-shadow hover:shadow-[0_2px_8px_rgba(0,0,0,0.10)]"
    >
      <ContextLabel project={project} company={company} />
      <span className="text-[15px] font-medium leading-snug">{issue.title}</span>
      {running ? (
        <span className="inline-flex items-center gap-2 text-xs text-[#058527]">
          <span className="size-[7px] rounded-full bg-[#058527]" />
          Claude sta lavorando
        </span>
      ) : null}
      <div className="flex items-center gap-3 text-xs text-[#666666]">
        <span>{issue.identifier}</span>
        {issue.due_date ? <span>{formatDueIt(issue.due_date)}</span> : null}
        <span className="flex-1" />
        {issue.assignee_type && issue.assignee_id ? (
          <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="md" />
        ) : null}
      </div>
    </AppLink>
  );
}

function Column({
  col,
  issues,
  render,
  onDropIssue,
  className,
  sectionRef,
  projectId,
}: {
  col: (typeof COLUMNS)[number];
  issues: Issue[];
  render: (i: Issue) => ReactNode;
  onDropIssue: (id: string) => void;
  className?: string;
  sectionRef?: (el: HTMLElement | null) => void;
  projectId?: string | null;
}) {
  const [over, setOver] = useState(false);
  const [showAll, setShowAll] = useState(false);
  const visible = col.key === "done" && !showAll ? issues.slice(0, DONE_LIMIT) : issues;
  return (
    <section
      ref={sectionRef}
      data-col={col.key}
      onDragOver={(e) => {
        if (!e.dataTransfer.types.includes("text/calm-issue")) return;
        e.preventDefault();
        setOver(true);
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        setOver(false);
        const id = e.dataTransfer.getData("text/calm-issue");
        if (id) onDropIssue(id);
      }}
      className={cn(
        "flex max-h-full shrink-0 snap-start flex-col gap-2.5 self-start overflow-y-auto rounded-2xl bg-[#f6f4f1] p-3 transition-colors md:p-3.5",
        over && "bg-[#efe9e2] ring-2 ring-[#dc4c3e]/30",
        className,
      )}
    >
      <div className="flex items-center gap-2.5 px-1.5 pb-1.5 pt-1">
        <span className="size-2.5 rounded-full" style={{ background: col.dot }} />
        <h2 className="m-0 flex-1 text-[15px] font-semibold">{col.name}</h2>
        <span className="text-[13px] text-[#666666]">{issues.length}</span>
      </div>
      {visible.map(render)}
      {visible.length < issues.length ? (
        <button type="button" onClick={() => setShowAll(true)} className="h-10 rounded-[10px] px-2 text-left text-sm text-[#4b4b4b] hover:bg-white/60">
          Mostra tutti ({issues.length})
        </button>
      ) : null}
      <button
        type="button"
        onClick={() => useModalStore.getState().open("create-issue", projectId ? { status: col.status, project_id: projectId } : { status: col.status })}
        className="h-11 rounded-[10px] px-2 text-left text-sm text-[#4b4b4b] hover:bg-white/60"
      >
        + Aggiungi una card
      </button>
    </section>
  );
}

export function CalmKanban({ toggle }: { toggle: ReactNode }) {
  const wsId = useWorkspaceId();
  const { issues, projectById, companyById, companyOf, scope, runningByIssue } = useCalmData();
  const { replace } = useNavigation();
  const paths = useWorkspacePaths();
  const scopeProject = scope.projectId ? projectById.get(scope.projectId) : undefined;
  const scopeCompany = scope.companyId
    ? companyById.get(scope.companyId)
    : scopeProject?.company_id
      ? companyById.get(scopeProject.company_id)
      : undefined;
  const scopeTitle = scopeProject?.title ?? scopeCompany?.name;
  const { data: agents = [] } = useQuery(agentListOptions(wsId));
  const update = useUpdateIssue();
  const isMobile = useIsMobile();
  const [agentFilter, setAgentFilter] = useState<string | null>(null);
  const [active, setActive] = useState<CalmColumn>("todo");
  const scrollerRef = useRef<HTMLDivElement>(null);
  const colEls = useRef(new Map<CalmColumn, HTMLElement>());

  const byCol = useMemo(() => {
    const m: Record<CalmColumn, Issue[]> = { todo: [], doing: [], review: [], done: [] };
    for (const i of issues) {
      if (agentFilter && !(i.assignee_type === "agent" && i.assignee_id === agentFilter)) continue;
      const c = calmColumn(i);
      if (c) m[c].push(i);
    }
    m.todo.sort(byPriorityThenDue);
    m.doing.sort(byPriorityThenDue);
    m.review.sort(byPriorityThenDue);
    m.done.sort((a, b) => b.updated_at.localeCompare(a.updated_at));
    return m;
  }, [issues, agentFilter]);

  // Phone: keep the active pill in sync with the column snapped into view.
  useEffect(() => {
    const root = scrollerRef.current;
    if (!root) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting && e.intersectionRatio > 0.6) {
            const key = (e.target as HTMLElement).dataset.col as CalmColumn | undefined;
            if (key) setActive(key);
          }
        }
      },
      { root, threshold: [0.6] },
    );
    colEls.current.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  const moveTo = (id: string, col: (typeof COLUMNS)[number]) => {
    const issue = issues.find((i) => i.id === id);
    if (!issue || calmColumn(issue) === col.key) return;
    update.mutate({ id, status: col.status });
  };

  const scrollToCol = (key: CalmColumn) => {
    setActive(key);
    const el = colEls.current.get(key);
    const root = scrollerRef.current;
    if (el && root) root.scrollTo({ left: el.offsetLeft - root.offsetLeft - 22, behavior: "smooth" });
  };

  const liveAgents = agents.filter((a) => !a.archived_at);

  return (
    <div className="flex h-full min-h-0 flex-col bg-[#fcfaf8] font-sans text-[#202020]">
      <header className="flex flex-wrap items-center gap-3.5 px-[22px] pb-3 pt-6 md:px-8 md:pb-2 md:pt-6">
        <h1 className="m-0 flex-1 text-[30px] font-semibold tracking-[-0.01em] md:flex-none md:text-2xl">
          {scopeTitle ?? "Kanban"}
        </h1>
        {scopeTitle ? (
          <button
            type="button"
            onClick={() => replace(`${paths.issues()}?vista=kanban`)}
            className="h-8 rounded-full bg-white px-3 text-[13px] text-[#4b4b4b] ring-1 ring-black/[0.06] hover:text-[#202020]"
          >
            {scopeProject && scopeCompany ? `${scopeCompany.name} · ` : ""}Mostra tutto ✕
          </button>
        ) : null}
        <div className="md:ml-4">{toggle}</div>
        <div className="hidden flex-1 md:block" />
        {liveAgents.length > 0 ? (
          <div className="hidden items-center gap-2 md:flex">
            <span className="mr-1 text-sm text-[#4b4b4b]">Filtra per account</span>
            {liveAgents.slice(0, 6).map((a) => (
              <button
                key={a.id}
                type="button"
                aria-label={a.name}
                aria-pressed={agentFilter === a.id}
                title={a.name}
                onClick={() => setAgentFilter((f) => (f === a.id ? null : a.id))}
                className={cn(
                  "rounded-full border-2 transition-opacity",
                  agentFilter === a.id ? "border-[#dc4c3e]" : "border-white",
                  agentFilter && agentFilter !== a.id && "opacity-40",
                )}
              >
                <ActorAvatar actorType="agent" actorId={a.id} size="lg" />
              </button>
            ))}
          </div>
        ) : null}
        <button
          type="button"
          onClick={() =>
            scope.projectId
              ? useModalStore.getState().open("create-issue", { project_id: scope.projectId })
              : openCreateIssueWithPreference()
          }
          className="hidden h-11 rounded-xl bg-[#dc4c3e] px-[18px] text-sm font-semibold text-white md:inline-flex md:items-center"
        >
          + Nuovo task
        </button>
      </header>

      {/* Phone: one pill per column */}
      <div role="tablist" aria-label="Colonne" className="flex gap-2 overflow-x-auto px-[22px] pb-3.5 md:hidden">
        {COLUMNS.map((c) => (
          <button
            key={c.key}
            type="button"
            role="tab"
            aria-selected={active === c.key}
            onClick={() => scrollToCol(c.key)}
            className={cn(
              "h-9 shrink-0 rounded-full px-3.5 text-[13px] font-semibold",
              active === c.key ? "bg-[#202020] text-white" : "bg-white/70 text-[#4b4b4b] ring-1 ring-black/[0.06]",
            )}
          >
            {c.name} {byCol[c.key].length || ""}
          </button>
        ))}
      </div>

      <div
        ref={scrollerRef}
        className="flex min-h-0 flex-1 snap-x snap-mandatory gap-3 overflow-x-auto scroll-pl-[22px] px-[22px] pb-6 md:snap-none md:gap-4 md:px-8 md:pb-8 md:pt-2"
      >
        {COLUMNS.map((c) => (
          <Column
            key={c.key}
            col={c}
            issues={byCol[c.key]}
            onDropIssue={(id) => moveTo(id, c)}
            sectionRef={(el) => {
              if (el) colEls.current.set(c.key, el);
              else colEls.current.delete(c.key);
            }}
            className="w-[calc(100vw-76px)] max-w-[330px] md:w-[330px]"
            projectId={scope.projectId}
            render={(i) => (
              <KanbanCard
                key={i.id}
                issue={i}
                project={i.project_id ? projectById.get(i.project_id) : undefined}
                company={companyOf(i)}
                running={runningByIssue.get(i.id)}
                draggable={!isMobile}
              />
            )}
          />
        ))}
        <div className="w-px shrink-0" aria-hidden />
      </div>
    </div>
  );
}
