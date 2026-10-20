"use client";

import { useState, type ReactNode } from "react";
import { openCreateIssueWithPreference } from "@multica/core/issues/stores/create-mode-store";
import { useModalStore } from "@multica/core/modals";
import { useWorkspacePaths } from "@multica/core/paths";
import { useNavigation } from "../navigation";
import { useCalmData } from "./shared";
import { ColumnsDialog } from "./calm-columns";

/** Small buttons shared by every calm screen. */
export const calmButton =
  "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg px-3 text-[13px] font-medium text-[#4b4b4b] ring-1 ring-black/[0.08] hover:bg-white hover:text-[#202020]";
export const calmPrimaryButton =
  "inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg bg-[#dc4c3e] px-3 text-[13px] font-semibold text-white hover:bg-[#c53f32]";

/** One title row for Lista and Kanban: scope, view switch, columns, new task. */
export function CalmPageHeader({ fallbackTitle, toggle }: { fallbackTitle: string; toggle: ReactNode }) {
  const { projectById, companyById, scope } = useCalmData();
  const { searchParams, replace } = useNavigation();
  const paths = useWorkspacePaths();
  const [columnsOpen, setColumnsOpen] = useState(false);

  const scopeProject = scope.projectId ? projectById.get(scope.projectId) : undefined;
  const scopeCompany = scope.companyId
    ? companyById.get(scope.companyId)
    : scopeProject?.company_id
      ? companyById.get(scopeProject.company_id)
      : undefined;
  const title = scopeProject?.title ?? scopeCompany?.name ?? fallbackTitle;

  const clearScope = () => {
    const vista = searchParams.get("vista");
    replace(vista ? `${paths.issues()}?vista=${vista}` : paths.issues());
  };

  return (
    <header className="flex flex-wrap items-center gap-2.5 px-[22px] pb-3 pt-5 md:px-8 md:pt-6">
      <div className="flex min-w-0 flex-1 items-center gap-2.5">
        {scopeProject && scopeCompany ? (
          <span className="hidden text-[13px] text-[#666666] md:inline">{scopeCompany.name} /</span>
        ) : null}
        <h1 className="m-0 truncate text-xl font-semibold tracking-[-0.01em]">{title}</h1>
        {scopeProject || scopeCompany ? (
          <button type="button" onClick={clearScope} aria-label="Mostra tutto" className="h-6 rounded-full px-2 text-xs text-[#666666] ring-1 ring-black/[0.08] hover:text-[#202020]">
            Mostra tutto ✕
          </button>
        ) : null}
      </div>
      {toggle}
      <button type="button" onClick={() => setColumnsOpen(true)} className={`${calmButton} hidden md:inline-flex`}>
        Colonne
      </button>
      <button
        type="button"
        onClick={() =>
          scope.projectId
            ? useModalStore.getState().open("create-issue", { project_id: scope.projectId })
            : openCreateIssueWithPreference()
        }
        className={`${calmPrimaryButton} hidden md:inline-flex`}
      >
        + Nuovo task
      </button>
      <ColumnsDialog open={columnsOpen} onOpenChange={setColumnsOpen} />
    </header>
  );
}
