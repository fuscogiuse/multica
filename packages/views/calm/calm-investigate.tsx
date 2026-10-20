"use client";

import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";
import { api } from "@multica/core/api";
import { useWorkspaceId } from "@multica/core/hooks";
import { agentListOptions } from "@multica/core/workspace";
import type { Issue } from "@multica/core/types";
import { cn } from "@multica/ui/lib/utils";
import { useCalmData } from "./shared";

// Calm UI fork: hand a task to the "Indagine" agent, same as the iOS swipe.
// The agent runs with the Claude profile of the task's company, researches on
// its own and answers in a comment with a ready-to-apply solution. It never
// acts live.

const BRIEF = [
  "Indaga questo task e preparami una soluzione pronta da applicare.",
  "Non eseguire nulla dal vivo: niente invii, pubblicazioni o modifiche a campagne, siti e account.",
  "Riporta in un commento: cosa hai capito, la soluzione passo per passo, il materiale pronto da copiare, come verificarla, rischi e domande.",
].join("\n");

export function useInvestigate() {
  const wsId = useWorkspaceId();
  const qc = useQueryClient();
  const { projectById, companyOf } = useCalmData();
  const [pending, setPending] = useState<string | null>(null);

  const investigate = async (issue: Issue) => {
    const project = issue.project_id ? projectById.get(issue.project_id) : undefined;
    if (!project || !companyOf(issue)) {
      toast.error(
        `Questo task non ha un'area (è in ${project?.title ?? "nessun progetto"}), quindi l'AI non sa quale profilo Claude usare. Spostalo in un cliente di un'area e riprova.`,
      );
      return;
    }
    setPending(issue.id);
    try {
      const agents = await qc.fetchQuery(agentListOptions(wsId));
      const agent = agents.find((a) => !a.archived_at && a.name.trim().toLowerCase() === "indagine");
      if (!agent) {
        toast.error("Manca l'agente «Indagine». Crealo da ingranaggio › Agenti.");
        return;
      }
      await api.createComment(issue.id, `[@${agent.name}](mention://agent/${agent.id}) ${BRIEF}`);
      await qc.invalidateQueries({ predicate: (q) => JSON.stringify(q.queryKey).includes(issue.id) });
      toast.success(`Indagine avviata su «${issue.title}». La risposta arriva nei commenti.`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Non sono riuscito ad avviare l'indagine.");
    } finally {
      setPending(null);
    }
  };

  return { investigate, pending };
}

/** Small "AI" button. `label` shows the text; otherwise it is an icon with a tooltip. */
export function InvestigateButton({
  issue,
  label,
  className,
}: {
  issue: Issue;
  label?: string;
  className?: string;
}) {
  const { investigate, pending } = useInvestigate();
  const busy = pending === issue.id;
  return (
    <button
      type="button"
      title="Indaga con AI (agente Indagine)"
      aria-label="Indaga con AI"
      disabled={busy}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        void investigate(issue);
      }}
      className={cn(
        "inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg text-[#7a5af8] hover:bg-[#f1edff] disabled:opacity-50",
        label ? "h-8 px-3 text-[13px] font-medium ring-1 ring-[#7a5af8]/30" : "size-7",
        className,
      )}
    >
      <Sparkles size={15} strokeWidth={1.75} aria-hidden className={cn(busy && "animate-pulse")} />
      {label ? <span>{busy ? "Avvio…" : label}</span> : null}
    </button>
  );
}
