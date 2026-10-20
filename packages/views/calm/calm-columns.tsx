"use client";

import { useEffect, useState } from "react";
import {
  useArchiveIssueStatus,
  useCreateIssueStatus,
  useUpdateIssueStatus,
} from "@multica/core/issue-statuses";
import type { IssueStatusCategory, IssueStatusEntry } from "@multica/core/types";
import { Dialog, DialogContent, DialogTitle } from "@multica/ui/components/ui/dialog";
import { cn } from "@multica/ui/lib/utils";
import { useBoard } from "./shared";

// Calm UI fork: every status is a board column. The description is the
// instruction agents read to decide where an issue belongs.

const COLORS = ["#6b7280", "#dc4c3e", "#eb8909", "#058527", "#246fe0", "#7a5af8", "#0e7490"];

const CATEGORY_IT: Record<IssueStatusCategory, string> = {
  unstarted: "Da iniziare",
  started: "In lavorazione",
  done: "Completata",
  closed: "Chiusa",
};

const fieldCls =
  "w-full rounded-lg border border-black/10 bg-white px-2.5 text-[13px] text-[#202020] outline-none focus:border-[#dc4c3e]";

function ArrowButton({ dir, disabled, onClick }: { dir: "up" | "down"; disabled: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-label={dir === "up" ? "Sposta su" : "Sposta giù"}
      disabled={disabled}
      onClick={onClick}
      className="flex size-6 items-center justify-center rounded-md text-[#666666] hover:bg-[#f6f4f1] disabled:opacity-30"
    >
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d={dir === "up" ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6"} />
      </svg>
    </button>
  );
}

function ColumnRow({
  entry,
  first,
  last,
  onMove,
}: {
  entry: IssueStatusEntry;
  first: boolean;
  last: boolean;
  onMove: (dir: -1 | 1) => void;
}) {
  const update = useUpdateIssueStatus();
  const archive = useArchiveIssueStatus();
  const [name, setName] = useState(entry.name);
  const [desc, setDesc] = useState(entry.description);
  const [open, setOpen] = useState(false);
  useEffect(() => {
    setName(entry.name);
    setDesc(entry.description);
  }, [entry.name, entry.description]);
  const hidden = Boolean(entry.board_hidden);

  const saveName = () => {
    const t = name.trim();
    if (t && t !== entry.name) update.mutate({ id: entry.id, name: t });
    else setName(entry.name);
  };
  const saveDesc = () => {
    if (desc !== entry.description) update.mutate({ id: entry.id, description: desc.slice(0, 256) });
  };

  return (
    <div className={cn("flex flex-col gap-2 rounded-xl px-2 py-2", open ? "bg-[#f6f4f1]" : "hover:bg-[#fcfaf8]")}>
      <div className="flex items-center gap-1.5">
        <div className="flex flex-col">
          <ArrowButton dir="up" disabled={first} onClick={() => onMove(-1)} />
          <ArrowButton dir="down" disabled={last} onClick={() => onMove(1)} />
        </div>
        <span className="size-2.5 shrink-0 rounded-full" style={{ background: entry.color }} />
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          onBlur={saveName}
          onKeyDown={(e) => e.key === "Enter" && (e.target as HTMLInputElement).blur()}
          aria-label="Nome colonna"
          className={cn("h-8 min-w-0 flex-1 rounded-lg bg-transparent px-1.5 text-sm font-medium outline-none focus:bg-white", hidden && "text-[#999999]")}
        />
        <button
          type="button"
          onClick={() => update.mutate({ id: entry.id, board_hidden: !hidden })}
          className={cn("h-7 shrink-0 rounded-md px-2 text-xs", hidden ? "text-[#666666] ring-1 ring-black/10" : "text-[#4b4b4b] hover:bg-white")}
        >
          {hidden ? "Nascosta" : "Visibile"}
        </button>
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          aria-expanded={open}
          className="h-7 shrink-0 rounded-md px-2 text-xs text-[#4b4b4b] hover:bg-white"
        >
          {open ? "Chiudi" : "Istruzioni"}
        </button>
      </div>
      {!open && entry.description ? (
        <p className="m-0 truncate pl-[52px] text-xs text-[#666666]">{entry.description}</p>
      ) : null}
      {open ? (
        <div className="flex flex-col gap-2 pl-[52px] pr-1">
          <textarea
            value={desc}
            onChange={(e) => setDesc(e.target.value)}
            onBlur={saveDesc}
            rows={3}
            maxLength={256}
            placeholder="Quando va qui un task? L'agente legge questa istruzione per decidere dove spostarlo."
            className={cn(fieldCls, "resize-none py-2 leading-relaxed")}
          />
          <div className="flex items-center gap-1.5">
            {COLORS.map((c) => (
              <button
                key={c}
                type="button"
                aria-label={`Colore ${c}`}
                onClick={() => update.mutate({ id: entry.id, color: c })}
                className={cn("size-5 rounded-full ring-offset-1", entry.color.toLowerCase() === c && "ring-2 ring-[#202020]")}
                style={{ background: c }}
              />
            ))}
            <span className="flex-1" />
            <span className="text-[11px] text-[#666666]">{CATEGORY_IT[entry.category]}</span>
            {!entry.is_system ? (
              <button
                type="button"
                onClick={() => {
                  if (window.confirm(`Archiviare la colonna "${entry.name}"?`)) archive.mutate(entry.id);
                }}
                className="h-7 rounded-md px-2 text-xs text-[#d1453b] hover:bg-[#fbe4e2]"
              >
                Archivia
              </button>
            ) : null}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function NewColumn({ nextPosition }: { nextPosition: number }) {
  const create = useCreateIssueStatus();
  const update = useUpdateIssueStatus();
  const [name, setName] = useState("");
  const [category, setCategory] = useState<IssueStatusCategory>("started");
  const [error, setError] = useState<string | null>(null);
  const submit = async () => {
    const t = name.trim();
    if (!t) {
      setError("Scrivi un nome");
      return;
    }
    try {
      const created = await create.mutateAsync({ name: t, category, color: COLORS[4]! });
      await update.mutateAsync({ id: created.id, position: nextPosition });
      setName("");
      setError(null);
    } catch {
      setError("Non sono riuscito a creare la colonna. Prova un altro nome.");
    }
  };
  return (
    <div className="flex flex-col gap-1.5 border-t border-black/[0.08] pt-3">
      <div className="flex items-center gap-2">
        <input
          value={name}
          onChange={(e) => {
            setName(e.target.value);
            setError(null);
          }}
          onKeyDown={(e) => e.key === "Enter" && submit()}
          placeholder="Nuova colonna"
          className={cn(fieldCls, "h-8 flex-1")}
        />
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value as IssueStatusCategory)}
          aria-label="Tipo di colonna"
          className={cn(fieldCls, "h-8 w-auto")}
        >
          {(Object.keys(CATEGORY_IT) as IssueStatusCategory[]).map((c) => (
            <option key={c} value={c}>
              {CATEGORY_IT[c]}
            </option>
          ))}
        </select>
        <button type="button" onClick={submit} className="h-8 rounded-lg bg-[#dc4c3e] px-3 text-[13px] font-semibold text-white">
          Aggiungi
        </button>
      </div>
      {error ? <p className="m-0 text-xs text-[#d1453b]">{error}</p> : null}
      <p className="m-0 text-[11px] text-[#666666]">Il tipo dice a Multica se un task in questa colonna è ancora aperto o chiuso.</p>
    </div>
  );
}

export function ColumnsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const board = useBoard();
  const update = useUpdateIssueStatus();
  const rows = board.all.slice().sort((a, b) => a.position - b.position);

  // Rewrites every position 1..n in the new order, so ties never block a move.
  const move = (index: number, dir: -1 | 1) => {
    const target = index + dir;
    if (target < 0 || target >= rows.length) return;
    const next = rows.slice();
    [next[index], next[target]] = [next[target]!, next[index]!];
    next.forEach((entry, i) => {
      if (entry.position !== i + 1) update.mutate({ id: entry.id, position: i + 1 });
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="grid-cols-[minmax(0,1fr)] gap-3 bg-white p-5 font-sans text-[#202020] sm:max-w-[520px]">
        <div>
          <DialogTitle className="text-base font-semibold">Colonne</DialogTitle>
          <p className="m-0 mt-1 text-[13px] text-[#666666]">
            Rinominale, riordinale e scrivi un'istruzione per ognuna. Gli agenti la usano per scegliere dove spostare i task.
          </p>
        </div>
        <div className="flex max-h-[60vh] flex-col gap-0.5 overflow-y-auto">
          {rows.map((entry, i) => (
            <ColumnRow key={entry.id} entry={entry} first={i === 0} last={i === rows.length - 1} onMove={(d) => move(i, d)} />
          ))}
        </div>
        <NewColumn nextPosition={rows.length + 1} />
      </DialogContent>
    </Dialog>
  );
}
