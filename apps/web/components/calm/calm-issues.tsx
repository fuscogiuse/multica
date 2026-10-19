"use client";

import { useWorkspacePaths } from "@multica/core/paths";
import { useNavigation } from "@multica/views/navigation";
import { cn } from "@multica/ui/lib/utils";
import { CalmToday } from "./calm-today";
import { CalmKanban } from "./calm-kanban";

export type CalmVista = "lista" | "kanban" | "tutti";

export function useCalmVista(): CalmVista {
  const { searchParams } = useNavigation();
  const v = searchParams.get("vista");
  return v === "kanban" || v === "tutti" ? v : "lista";
}

/** Segmented Lista | Kanban switch, persisted in ?vista=. */
export function CalmViewToggle({ value }: { value: CalmVista }) {
  const { replace } = useNavigation();
  const paths = useWorkspacePaths();
  const opts: { key: CalmVista; label: string }[] = [
    { key: "lista", label: "Lista" },
    { key: "kanban", label: "Kanban" },
  ];
  return (
    <div role="tablist" aria-label="Vista" className="inline-flex gap-1 rounded-xl bg-[#f6f4f1] p-1">
      {opts.map((o) => (
        <button
          key={o.key}
          type="button"
          role="tab"
          aria-selected={value === o.key}
          onClick={() => replace(o.key === "lista" ? paths.issues() : `${paths.issues()}?vista=${o.key}`)}
          className={cn(
            "inline-flex h-9 items-center rounded-[9px] px-4 text-sm",
            value === o.key ? "bg-white font-semibold text-[#202020] shadow-[0_1px_2px_rgba(0,0,0,0.06)]" : "font-medium text-[#4b4b4b]",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function CalmIssues({ vista }: { vista: Exclude<CalmVista, "tutti"> }) {
  const toggle = <CalmViewToggle value={vista} />;
  return vista === "kanban" ? <CalmKanban toggle={toggle} /> : <CalmToday toggle={toggle} />;
}
