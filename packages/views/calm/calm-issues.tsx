"use client";

import { useWorkspacePaths } from "@multica/core/paths";
import { useNavigation } from "../navigation";
import { cn } from "@multica/ui/lib/utils";
import { CalmToday } from "./calm-today";
import { CalmKanban } from "./calm-kanban";
import { CalmList } from "./calm-list";

export type CalmVista = "lista" | "kanban" | "oggi" | "tutti";

export function useCalmVista(): CalmVista {
  const { searchParams } = useNavigation();
  const v = searchParams.get("vista");
  return v === "kanban" || v === "oggi" || v === "tutti" ? v : "lista";
}

/** Issues URL for a view, keeping the current company/project scope. */
export function useCalmHref() {
  const { searchParams } = useNavigation();
  const paths = useWorkspacePaths();
  return (vista: CalmVista, scope?: { company?: string | null; progetto?: string | null }) => {
    const q = new URLSearchParams();
    if (vista !== "lista") q.set("vista", vista);
    const company = scope ? scope.company : searchParams.get("company");
    const progetto = scope ? scope.progetto : searchParams.get("progetto");
    if (company) q.set("company", company);
    if (progetto) q.set("progetto", progetto);
    const s = q.toString();
    return s ? `${paths.issues()}?${s}` : paths.issues();
  };
}

/** Segmented Lista | Kanban | Oggi switch, persisted in ?vista=. */
export function CalmViewToggle({ value }: { value: CalmVista }) {
  const { replace } = useNavigation();
  const href = useCalmHref();
  const opts: { key: CalmVista; label: string }[] = [
    { key: "lista", label: "Lista" },
    { key: "kanban", label: "Kanban" },
    { key: "oggi", label: "Oggi" },
  ];
  return (
    <div role="tablist" aria-label="Vista" className="inline-flex gap-0.5 rounded-lg bg-[#f6f4f1] p-0.5">
      {opts.map((o) => (
        <button
          key={o.key}
          type="button"
          role="tab"
          aria-selected={value === o.key}
          onClick={() => replace(href(o.key))}
          className={cn(
            "inline-flex h-7 items-center rounded-md px-3 text-[13px]",
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
  if (vista === "kanban") return <CalmKanban toggle={toggle} />;
  if (vista === "oggi") return <CalmToday toggle={toggle} />;
  return <CalmList toggle={toggle} />;
}
