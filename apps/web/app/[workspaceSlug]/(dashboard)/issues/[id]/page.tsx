"use client";

import { use } from "react";
import { useNavigation } from "@multica/views/navigation";
import { ErrorBoundary } from "@multica/ui/components/common/error-boundary";
import { CalmIssueDetail } from "@/components/calm/calm-issue-detail";

export default function IssueDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  // ?classica=1 opens Multica's full issue detail (editing, PRs, wakeups…).
  const classic = useNavigation().searchParams.get("classica") === "1";
  return (
    <ErrorBoundary resetKeys={[id]}>
      <CalmIssueDetail routeId={id} classic={classic} />
    </ErrorBoundary>
  );
}
