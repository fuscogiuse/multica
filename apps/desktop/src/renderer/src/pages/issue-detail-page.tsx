import { useParams } from "react-router-dom";
import { CalmIssueDetail } from "@multica/views/calm";
import { useNavigation } from "@multica/views/navigation";
import { useWorkspaceId } from "@multica/core/hooks";
import { useCanonicalIssue } from "@multica/core/issues/canonical-id";
import { useDocumentTitle } from "@/hooks/use-document-title";

export function IssueDetailPage({ onDelete }: { onDelete?: () => void }) {
  const { id } = useParams<{ id: string }>();
  const wsId = useWorkspaceId();
  // `id` may be an identifier (`MUL-123`); resolving here means the title
  // watches the same UUID-keyed entry realtime events patch. Shares its
  // queries with the IssueDetailRoute below, so it costs no extra request.
  const { issue } = useCanonicalIssue(wsId, id ?? "");
  // ?classica=1 opens Multica's full issue detail (editing, PRs, wakeups…).
  const classic = useNavigation().searchParams.get("classica") === "1";

  useDocumentTitle(issue ? `${issue.identifier}: ${issue.title}` : "Issue");

  if (!id) return null;
  // Render errors bubble to the root route errorElement (DesktopRouteErrorPage),
  // which contains the crash inside the tab content pane. No page-level boundary
  // here — a whole-page wrapper duplicates the route-level error UI.
  void onDelete;
  return <CalmIssueDetail routeId={id} classic={classic} />;
}
