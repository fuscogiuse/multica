"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { useUpdateIssue } from "@multica/core/issues";
import { useModalStore } from "@multica/core/modals";
import { useWorkspacePaths } from "@multica/core/paths";
import type { AgentTask, Company, Issue, IssueStatusEntry, Project } from "@multica/core/types";
import { AppLink } from "../navigation";
import { ActorAvatar } from "../common/actor-avatar";
import { cn } from "@multica/ui/lib/utils";
import { useIsMobile } from "@multica/ui/hooks/use-mobile";
import { byPriorityThenDue, ContextLabel, formatDueIt, useBoard, useCalmData } from "./shared";
import { CalmPageHeader } from "./calm-page";

const CLOSED_LIMIT = 8;

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
      className="flex flex-col gap-2 rounded-[10px] bg-white px-3 py-2.5 text-[#202020] no-underline shadow-[0_1px_2px_rgba(0,0,0,0.08)] transition-shadow hover:shadow-[0_2px_8px_rgba(0,0,0,0.10)]"
    >
      <ContextLabel project={project} company={company} />
      <span className="text-sm font-medium leading-snug">{issue.title}</span>
      {running ? (
        <span className="inline-flex items-center gap-1.5 text-xs text-[#058527]">
          <span className="size-1.5 rounded-full bg-[#058527]" />
          Claude sta lavorando
        </span>
      ) : null}
      <div className="flex items-center gap-2.5 text-xs text-[#666666]">
        <span>{issue.identifier}</span>
        {issue.due_date ? <span>{formatDueIt(issue.due_date)}</span> : null}
        <span className="flex-1" />
        {issue.assignee_type && issue.assignee_id ? (
          <ActorAvatar actorType={issue.assignee_type} actorId={issue.assignee_id} size="sm" />
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
  col: IssueStatusEntry;
  issues: Issue[];
  render: (i: Issue) => ReactNode;
  onDropIssue: (id: string) => void;
  className?: string;
  sectionRef?: (el: HTMLElement | null) => void;
  projectId?: string | null;
}) {
  const [over, setOver] = useState(false);
  const [showAll, setShowAll] = useState(false);
  const closed = col.category === "done" || col.category === "closed";
  const visible = closed && !showAll ? issues.slice(0, CLOSED_LIMIT) : issues;
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
        "flex max-h-full shrink-0 snap-start flex-col gap-2 self-start overflow-y-auto rounded-xl bg-[#f6f4f1] p-2.5 transition-colors",
        over && "bg-[#efe9e2] ring-2 ring-[#dc4c3e]/30",
        className,
      )}
    >
      <div className="flex items-center gap-2 px-1 pb-0.5 pt-0.5" title={col.description || undefined}>
        <span className="size-2 rounded-full" style={{ background: col.color }} />
        <h2 className="m-0 flex-1 truncate text-[13px] font-semibold">{col.name}</h2>
        <span className="text-xs text-[#666666]">{issues.length}</span>
      </div>
      {visible.map(render)}
      {visible.length < issues.length ? (
        <button type="button" onClick={() => setShowAll(true)} className="h-8 rounded-lg px-2 text-left text-[13px] text-[#4b4b4b] hover:bg-white/60">
          Mostra tutti ({issues.length})
        </button>
      ) : null}
      <button
        type="button"
        onClick={() =>
          useModalStore
            .getState()
            .open("create-issue", projectId ? { status: col.key, project_id: projectId } : { status: col.key })
        }
        className="h-8 rounded-lg px-2 text-left text-[13px] text-[#4b4b4b] hover:bg-white/60"
      >
        + Aggiungi una card
      </button>
    </section>
  );
}

export function CalmKanban({ toggle }: { toggle: ReactNode }) {
  const { issues, projectById, companyOf, runningByIssue, scope } = useCalmData();
  const board = useBoard();
  const update = useUpdateIssue();
  const isMobile = useIsMobile();
  const [active, setActive] = useState<string | null>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const colEls = useRef(new Map<string, HTMLElement>());

  const byCol = useMemo(() => {
    const m = new Map<string, Issue[]>();
    for (const c of board.columns) m.set(c.key, []);
    for (const i of issues) {
      const c = board.columnOf(i);
      if (c) m.get(c.key)?.push(i);
    }
    for (const c of board.columns) {
      const list = m.get(c.key)!;
      if (c.category === "done" || c.category === "closed") list.sort((a, b) => b.updated_at.localeCompare(a.updated_at));
      else list.sort(byPriorityThenDue);
    }
    return m;
  }, [issues, board]);

  // Phone: keep the active pill in sync with the column snapped into view.
  useEffect(() => {
    const root = scrollerRef.current;
    if (!root) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting && e.intersectionRatio > 0.6) {
            const key = (e.target as HTMLElement).dataset.col;
            if (key) setActive(key);
          }
        }
      },
      { root, threshold: [0.6] },
    );
    colEls.current.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [board.columns]);

  const moveTo = (id: string, col: IssueStatusEntry) => {
    const issue = issues.find((i) => i.id === id);
    if (!issue || issue.status === col.key) return;
    update.mutate({ id, status: col.key });
  };

  const scrollToCol = (key: string) => {
    setActive(key);
    const el = colEls.current.get(key);
    const root = scrollerRef.current;
    if (el && root) root.scrollTo({ left: el.offsetLeft - root.offsetLeft - 22, behavior: "smooth" });
  };

  const activeKey = active ?? board.columns[0]?.key;

  return (
    <div className="flex h-full min-h-0 flex-col bg-[#fcfaf8] font-sans text-[#202020]">
      <CalmPageHeader fallbackTitle="Kanban" toggle={toggle} />

      {/* Phone: one pill per column */}
      <div role="tablist" aria-label="Colonne" className="flex gap-1.5 overflow-x-auto px-[22px] pb-3 md:hidden">
        {board.columns.map((c) => (
          <button
            key={c.key}
            type="button"
            role="tab"
            aria-selected={activeKey === c.key}
            onClick={() => scrollToCol(c.key)}
            className={cn(
              "h-8 shrink-0 rounded-full px-3 text-xs font-semibold",
              activeKey === c.key ? "bg-[#202020] text-white" : "bg-white/70 text-[#4b4b4b] ring-1 ring-black/[0.06]",
            )}
          >
            {c.name} {byCol.get(c.key)?.length || ""}
          </button>
        ))}
      </div>

      <div
        ref={scrollerRef}
        className="flex min-h-0 flex-1 snap-x snap-mandatory gap-2.5 overflow-x-auto scroll-pl-[22px] px-[22px] pb-6 md:snap-none md:gap-3 md:px-8 md:pb-8 md:pt-1"
      >
        {board.columns.map((c) => (
          <Column
            key={c.key}
            col={c}
            issues={byCol.get(c.key) ?? []}
            onDropIssue={(id) => moveTo(id, c)}
            sectionRef={(el) => {
              if (el) colEls.current.set(c.key, el);
              else colEls.current.delete(c.key);
            }}
            className="w-[calc(100vw-76px)] max-w-[300px] md:w-[280px]"
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
