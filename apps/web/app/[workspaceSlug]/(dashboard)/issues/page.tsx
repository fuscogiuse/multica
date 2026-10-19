"use client";

import { Suspense } from "react";
import { IssuesPage } from "@multica/views/issues/components";
import { ErrorBoundary } from "@multica/ui/components/common/error-boundary";
import { useIssueViewUrlSync } from "../../../../platform/use-issue-view-url-sync";
import { CalmIssues, useCalmVista } from "@/components/calm/calm-issues";

function IssueViewUrlSync() {
  // useSearchParams requires a Suspense boundary in the app router.
  useIssueViewUrlSync({ scope_type: "workspace" });
  return null;
}

export default function Page() {
  const vista = useCalmVista();
  // ?vista=tutti keeps Multica's full issues surface (filters, saved views,
  // table, gantt). Lista and Kanban are the calm screens.
  if (vista === "tutti") {
    return (
      <ErrorBoundary>
        <Suspense fallback={null}>
          <IssueViewUrlSync />
        </Suspense>
        <IssuesPage />
      </ErrorBoundary>
    );
  }
  return (
    <ErrorBoundary>
      <CalmIssues vista={vista} />
    </ErrorBoundary>
  );
}
