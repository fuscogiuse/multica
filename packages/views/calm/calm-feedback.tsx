"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { createPortal } from "react-dom";
import { MessageSquarePlus, X } from "lucide-react";
import { cn } from "@multica/ui/lib/utils";

// Calm UI fork: feedback mode. Turn it on, click any element of the app and
// leave a note. Notes are kept on this device (and, in the desktop app, also
// written to ~/.multica/calm-feedback.md) so they can be handed to a Claude
// session as a list of fixes.

export interface FeedbackNote {
  id: string;
  createdAt: string;
  page: string;
  element: string;
  text: string;
}

const STORAGE_KEY = "calm-feedback-notes";
const LAYER_ATTR = "data-calm-feedback";

type State = { active: boolean; notes: FeedbackNote[] };

function load(): FeedbackNote[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as FeedbackNote[]) : [];
  } catch {
    return [];
  }
}

let state: State = { active: false, notes: typeof window === "undefined" ? [] : load() };
const listeners = new Set<() => void>();

function setState(next: Partial<State>) {
  state = { ...state, ...next };
  if (next.notes) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state.notes));
    } catch {
      // Storage can be unavailable; notes stay in memory.
    }
    const api = (globalThis as { desktopAPI?: { saveFeedback?: (md: string) => Promise<void> } }).desktopAPI;
    void api?.saveFeedback?.(feedbackMarkdown(state.notes)).catch(() => undefined);
  }
  listeners.forEach((l) => l());
}

export const feedbackStore = {
  subscribe: (l: () => void) => {
    listeners.add(l);
    return () => listeners.delete(l);
  },
  get: () => state,
  toggle: () => setState({ active: !state.active }),
  stop: () => setState({ active: false }),
  add: (note: Omit<FeedbackNote, "id" | "createdAt">) =>
    setState({
      notes: [...state.notes, { ...note, id: crypto.randomUUID(), createdAt: new Date().toISOString() }],
    }),
  remove: (id: string) => setState({ notes: state.notes.filter((n) => n.id !== id) }),
  clear: () => setState({ notes: [] }),
};

export function useFeedback(): State {
  return useSyncExternalStore(feedbackStore.subscribe, feedbackStore.get, feedbackStore.get);
}

export function feedbackMarkdown(notes: FeedbackNote[]): string {
  const lines = ["# Calm Tasks feedback", "", "Fixes requested on the Calm UI, one per item.", ""];
  notes.forEach((n, i) => {
    lines.push(`## ${i + 1}. ${n.page}`);
    lines.push("");
    lines.push(`- Element: ${n.element}`);
    lines.push(`- Note: ${n.text}`);
    lines.push(`- Date: ${n.createdAt}`);
    lines.push("");
  });
  return lines.join("\n");
}

/** Short, human-readable description of the clicked element. */
function describe(el: Element): string {
  const parts: string[] = [];
  let node: Element | null = el;
  for (let depth = 0; node && depth < 4; depth++, node = node.parentElement) {
    const tag = node.tagName.toLowerCase();
    const label = node.getAttribute("aria-label") || node.getAttribute("title");
    parts.unshift(label ? `${tag}[${label}]` : tag);
  }
  const text = (el.textContent ?? "").replace(/\s+/g, " ").trim().slice(0, 80);
  return `${parts.join(" > ")}${text ? ` · "${text}"` : ""}`;
}

function insideLayer(el: EventTarget | null): boolean {
  return el instanceof Element && Boolean(el.closest(`[${LAYER_ATTR}]`));
}

function Composer({ x, y, element, onClose }: { x: number; y: number; element: string; onClose: () => void }) {
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const left = Math.min(x, window.innerWidth - 340);
  const top = Math.min(y + 12, window.innerHeight - 220);
  const save = () => {
    if (!text.trim()) {
      setError("Scrivi un commento");
      return;
    }
    feedbackStore.add({ page: window.location.hash || window.location.pathname, element, text: text.trim() });
    onClose();
  };
  return (
    <div
      {...{ [LAYER_ATTR]: "" }}
      className="fixed z-[1001] flex w-[320px] flex-col gap-2 rounded-xl bg-white p-3 font-sans text-[#202020] shadow-[0_8px_30px_rgba(0,0,0,0.18)] ring-1 ring-black/10"
      style={{ left, top }}
    >
      <p className="m-0 truncate text-[11px] text-[#666666]" title={element}>{element}</p>
      <textarea
        autoFocus
        rows={3}
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          setError(null);
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) save();
          if (e.key === "Escape") onClose();
        }}
        placeholder="Cosa va sistemato qui?"
        className="resize-none rounded-lg border border-black/10 px-2.5 py-2 text-[13px] outline-none focus:border-[#dc4c3e]"
      />
      {error ? <p className="m-0 text-xs text-[#d1453b]">{error}</p> : null}
      <div className="flex justify-end gap-1.5">
        <button type="button" onClick={onClose} className="h-7 rounded-md px-2.5 text-xs text-[#4b4b4b] hover:bg-[#f6f4f1]">
          Annulla
        </button>
        <button type="button" onClick={save} className="h-7 rounded-md bg-[#dc4c3e] px-2.5 text-xs font-semibold text-white">
          Salva
        </button>
      </div>
    </div>
  );
}

function NotesPanel({ onClose }: { onClose: () => void }) {
  const { notes } = useFeedback();
  const [copied, setCopied] = useState(false);
  return (
    <div
      {...{ [LAYER_ATTR]: "" }}
      className="fixed bottom-16 right-4 z-[1001] flex max-h-[60vh] w-[360px] flex-col gap-2 rounded-xl bg-white p-3 font-sans text-[#202020] shadow-[0_8px_30px_rgba(0,0,0,0.18)] ring-1 ring-black/10"
    >
      <div className="flex items-center gap-2">
        <span className="flex-1 text-[13px] font-semibold">Commenti ({notes.length})</span>
        <button type="button" aria-label="Chiudi" onClick={onClose} className="flex size-6 items-center justify-center rounded-md text-[#666666] hover:bg-[#f6f4f1]">
          <X size={14} />
        </button>
      </div>
      <div className="flex min-h-0 flex-col gap-1.5 overflow-y-auto">
        {notes.length === 0 ? <p className="m-0 text-[13px] text-[#666666]">Nessun commento. Clicca un elemento dell'app per aggiungerne uno.</p> : null}
        {notes.map((n) => (
          <div key={n.id} className="group flex gap-2 rounded-lg bg-[#f6f4f1] px-2.5 py-2">
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <span className="text-[13px]">{n.text}</span>
              <span className="truncate text-[11px] text-[#666666]" title={n.element}>{n.page} · {n.element}</span>
            </div>
            <button type="button" aria-label="Elimina" onClick={() => feedbackStore.remove(n.id)} className="flex size-5 shrink-0 items-center justify-center rounded text-[#666666] opacity-0 hover:bg-white group-hover:opacity-100">
              <X size={12} />
            </button>
          </div>
        ))}
      </div>
      <div className="flex gap-1.5">
        <button
          type="button"
          disabled={notes.length === 0}
          onClick={async () => {
            await navigator.clipboard.writeText(feedbackMarkdown(notes));
            setCopied(true);
            window.setTimeout(() => setCopied(false), 1500);
          }}
          className="h-8 flex-1 rounded-lg bg-[#dc4c3e] text-[13px] font-semibold text-white disabled:opacity-40"
        >
          {copied ? "Copiato" : "Copia per Claude"}
        </button>
        <button
          type="button"
          disabled={notes.length === 0}
          onClick={() => window.confirm("Eliminare tutti i commenti?") && feedbackStore.clear()}
          className="h-8 rounded-lg px-3 text-[13px] text-[#4b4b4b] ring-1 ring-black/10 disabled:opacity-40"
        >
          Svuota
        </button>
      </div>
    </div>
  );
}

/** Mount once. Handles hover outline, click capture, composer and the notes panel. */
export function FeedbackLayer() {
  const { active, notes } = useFeedback();
  const [box, setBox] = useState<DOMRect | null>(null);
  const [composer, setComposer] = useState<{ x: number; y: number; element: string } | null>(null);
  const [panel, setPanel] = useState(false);
  const composerOpen = useRef(false);
  composerOpen.current = composer !== null;

  useEffect(() => {
    if (!active) {
      setBox(null);
      setComposer(null);
      return;
    }
    const onMove = (e: MouseEvent) => {
      if (composerOpen.current || insideLayer(e.target)) return;
      const el = e.target instanceof Element ? e.target : null;
      setBox(el ? el.getBoundingClientRect() : null);
    };
    const onClick = (e: MouseEvent) => {
      if (insideLayer(e.target)) return;
      e.preventDefault();
      e.stopPropagation();
      if (composerOpen.current) return;
      const el = e.target instanceof Element ? e.target : null;
      if (el) setComposer({ x: e.clientX, y: e.clientY, element: describe(el) });
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !composerOpen.current) feedbackStore.stop();
    };
    document.addEventListener("mousemove", onMove, true);
    document.addEventListener("click", onClick, true);
    document.addEventListener("keydown", onKey, true);
    return () => {
      document.removeEventListener("mousemove", onMove, true);
      document.removeEventListener("click", onClick, true);
      document.removeEventListener("keydown", onKey, true);
    };
  }, [active]);

  if (typeof document === "undefined") return null;
  return createPortal(
    <>
      {active && box && !composer ? (
        <div
          className="pointer-events-none fixed z-[1000] rounded-md ring-2 ring-[#dc4c3e]"
          style={{ left: box.left - 2, top: box.top - 2, width: box.width + 4, height: box.height + 4 }}
        />
      ) : null}
      {active ? (
        <div
          {...{ [LAYER_ATTR]: "" }}
          className="fixed left-1/2 top-3 z-[1001] flex -translate-x-1/2 items-center gap-2 rounded-full bg-[#202020] py-1.5 pl-4 pr-1.5 font-sans text-[13px] text-white shadow-lg"
        >
          Modalità commento: clicca un elemento
          <button type="button" onClick={() => feedbackStore.stop()} className="h-7 rounded-full bg-white/15 px-3 text-xs font-semibold">
            Fine
          </button>
        </div>
      ) : null}
      {composer ? <Composer {...composer} onClose={() => setComposer(null)} /> : null}
      {active || notes.length > 0 ? (
        <button
          type="button"
          {...{ [LAYER_ATTR]: "" }}
          onClick={() => setPanel((p) => !p)}
          className={cn(
            "fixed bottom-4 right-16 z-[1001] inline-flex h-9 items-center gap-1.5 rounded-full px-3.5 font-sans text-[13px] font-medium shadow-md ring-1 ring-black/10",
            active ? "bg-[#dc4c3e] text-white" : "bg-white text-[#202020]",
          )}
        >
          <MessageSquarePlus size={15} />
          {notes.length}
        </button>
      ) : null}
      {panel ? <NotesPanel onClose={() => setPanel(false)} /> : null}
    </>,
    document.body,
  );
}
