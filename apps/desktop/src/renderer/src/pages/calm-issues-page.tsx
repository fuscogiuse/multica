import { IssuesPage } from "@multica/views/issues/components";
import { CalmIssues, useCalmVista } from "@multica/views/calm";

/** Calm UI fork: Lista and Kanban are the calm screens; ?vista=tutti keeps Multica's full issues surface. */
export function CalmIssuesPage() {
  const vista = useCalmVista();
  if (vista === "tutti") return <IssuesPage />;
  return <CalmIssues vista={vista} />;
}
