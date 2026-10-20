"use client";

import { useMemo, useState, type ReactNode } from "react";
import type { Issue, IssueStatusEntry } from "@multica/core/types";
import { cn } from "@multica/ui/lib/utils";
import { byPriorityThenDue, useBoard, useCalmData } from "./shared";
import { QuickAdd, TaskRow, useComplete } from "./calm-today";
import { CalmPageHeader } from "./calm-page";

// Calm UI fork: the default screen. Every board column is a section of one
// Todoist-style list; closed columns start folded.

const CLOSED_PREVIEW = 5;

function Section({
  col,
  issues,
  render,
}: {
  col: IssueStatusEntry;
  issues: Issue[];
  render: (i: Issue) => ReactNode;
}) {
  const closed = col.category === "done" || col.category === "closed";
  const [open, setOpen] = useState(!closed);
  const [showAll, setShowAll] = useState(false);
  const visible = closed && !showAll ? issues.slice(0, CLOSED_PREVIEW) : issues;
  return (
    <section className="flex flex-col">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        title={col.description || undefined}
        className="flex h-9 items-center gap-2 border-b border-black/[0.08] text-left"
      >
        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#666666" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden className={cn("transition-transform", open && "rotate-90")}>
          <path d="M9 6l6 6-6 6" />
        </svg>
        <span className="size-2 rounded-full" style={{ background: col.color }} />
        <span className="text-[13px] font-semibold text-[#202020]">{col.name}</span>
        <span className="text-xs text-[#666666]">{issues.length}</span>
      </button>
      {open ? (
        <>
          {visible.map(render)}
          {issues.length === 0 ? <p className="m-0 py-2.5 pl-6 text-[13px] text-[#999999]">Nessun task</p> : null}
          {visible.length < issues.length ? (
            <button type="button" onClick={() => setShowAll(true)} className="h-8 self-start pl-6 text-[13px] text-[#4b4b4b] hover:text-[#202020]">
              Mostra tutti ({issues.length})
            </button>
          ) : null}
        </>
      ) : null}
    </section>
  );
}

export function CalmList({ toggle }: { toggle: ReactNode }) {
  const { issues, projectById, companyOf, runningByIssue, scope, loading } = useCalmData();
  const board = useBoard();
  const { completing, complete } = useComplete();

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

  const firstOpen = board.columns.find((c) => c.category === "unstarted") ?? board.columns[0];

  const row = (i: Issue) => (
    <TaskRow
      key={i.id}
      issue={i}
      project={i.project_id ? projectById.get(i.project_id) : undefined}
      companyName={scope.companyId || scope.projectId ? undefined : companyOf(i)?.name}
      running={runningByIssue.get(i.id)}
      completing={completing.has(i.id)}
      onComplete={() => complete(i.id)}
      hideStatus
    />
  );

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto bg-white font-sans text-[#202020]">
      <CalmPageHeader fallbackTitle="Lista" toggle={toggle} />
      <div className="mx-auto flex w-full max-w-[860px] flex-col gap-5 px-[22px] pb-10 md:px-8">
        <QuickAdd projectId={scope.projectId} status={firstOpen?.key ?? "todo"} className="lg:w-full" />
        {loading || !board.ready ? (
          <div className="flex flex-col gap-2">
            {[0, 1, 2].map((k) => (
              <div key={k} className="h-10 animate-pulse rounded-lg bg-[#f6f4f1]" />
            ))}
          </div>
        ) : (
          board.columns.map((c) => <Section key={c.key} col={c} issues={byCol.get(c.key) ?? []} render={row} />)
        )}
      </div>
    </div>
  );
}
