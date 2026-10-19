/**
 * Shared issue row used by every list-style issue surface on mobile —
 * (tabs)/my-issues, more/issues (workspace-wide), and project detail's
 * related-issues bucket.
 *
 * Layout mirrors web's `packages/views/issues/components/list-row.tsx`
 * (calm UI fork):
 *   [priority circle]  [status?]  title  identifier  …  assignee
 *
 * The leading circle is Todoist-style: an 18pt ring tinted by priority
 * (urgent red, high orange, medium blue, otherwise grey). Issues in the
 * `done` category render a filled green circle with a check. It is a display
 * marker only; tapping it opens the issue like the rest of the row.
 *
 * `showStatus` is opt-in because the grouped lists already carry the status
 * CATEGORY in their section header (rendering the glyph again per-row would be
 * visual noise). Ungrouped surfaces that mix statuses — the pins list — ask for
 * it. New callers should default to false unless they mix multiple statuses
 * inside a single ungrouped list.
 *
 * The `<CustomStatusChip>` is NOT gated on `showStatus`: a section header names
 * a category, so "Code Review" and "QA" both land under In Review and the row
 * is the only place left to tell them apart. It stays silent for built-in
 * statuses, so a workspace without custom statuses renders exactly as before.
 * (MUL-6243)
 *
 * Behavioral parity:
 *   - Same `Issue` type, same `assignee_type`/`assignee_id` semantics
 *     (root CLAUDE.md "Data identity must agree").
 *   - Mirrors web `packages/views/issues/components/list-row.tsx:52`:
 *     render the assignee whenever `assignee_type && assignee_id` are both
 *     truthy — `ActorAvatar` itself handles member / agent / squad rendering
 *     (rounded square + people glyph or `squad.avatar_url` for squads). A
 *     future fourth enum value falls through to ActorAvatar's initials
 *     fallback, which is the real "enum drift downgrades, not crashes"
 *     behavior — earlier whitelist (member/agent only) silently dropped
 *     squad assignees instead.
 */
import { Pressable, View } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import type { Issue, IssuePriority } from "@multica/core/types";
import { Text } from "@/components/ui/text";
import { ActorAvatar } from "@/components/ui/actor-avatar";
import { StatusIcon } from "@/components/ui/status-icon";
import { CustomStatusChip } from "@/components/issue/custom-status-chip";
import { issueColumnCategory } from "@/lib/issue-status";
import { useIssueStatuses } from "@/lib/use-issue-statuses";

interface Props {
  issue: Issue;
  onPress: () => void;
  /** Render the status icon inline at the start of the row. Default: false. */
  showStatus?: boolean;
}

export function IssueRow({ issue, onPress, showStatus = false }: Props) {
  // One catalog read for both the icon's colour and the chip — see the
  // divergence note in `custom-status-chip.tsx`.
  const catalog = useIssueStatuses();
  return (
    <Pressable
      onPress={onPress}
      className="active:bg-secondary px-4 py-3 min-h-11 justify-center"
    >
      <View className="flex-row items-center gap-3">
        <PriorityCircle
          priority={issue.priority}
          done={issueColumnCategory(issue) === "done"}
        />
        {/* The glyph is per CATEGORY, so a custom status draws its category's
            icon rather than falling back to Todo's; the colour is what tells
            two statuses of one category apart. (MUL-6243) */}
        {showStatus ? (
          <StatusIcon
            status={issue.status}
            category={issueColumnCategory(issue)}
            icon={catalog.iconOf(issue.status)} color={catalog.colorOf(issue.status)}
            size={14}
          />
        ) : null}
        <View className="flex-1 flex-row items-center gap-2 min-w-0">
          <Text className="text-base text-foreground shrink" numberOfLines={1}>
            {issue.title}
          </Text>
          <Text className="text-xs text-muted-foreground shrink-0">
            {issue.identifier}
          </Text>
          <CustomStatusChip status={issue.status} catalog={catalog} />
        </View>
        {issue.assignee_type && issue.assignee_id ? (
          <ActorAvatar
            type={issue.assignee_type}
            id={issue.assignee_id}
            size={20}
            showPresence
          />
        ) : null}
      </View>
    </Pressable>
  );
}

// Calm UI: Todoist priority hues (p1 red, p2 orange, p3 blue, p4 grey).
// Fixed hex values on purpose: they match the web list row and read on both
// themes. Low and none fall back to a neutral ring.
const PRIORITY_RING: Partial<Record<IssuePriority, { border: string; fill: string }>> = {
  urgent: { border: "#d1453b", fill: "rgba(209, 69, 59, 0.10)" },
  high: { border: "#eb8909", fill: "rgba(235, 137, 9, 0.10)" },
  medium: { border: "#246fe0", fill: "rgba(36, 111, 224, 0.10)" },
};
const NEUTRAL_RING = "#a8a8a8";
const DONE_FILL = "#058527";
const CIRCLE_SIZE = 18;

function PriorityCircle({ priority, done }: { priority: IssuePriority; done: boolean }) {
  if (done) {
    return (
      <View
        className="items-center justify-center rounded-full"
        style={{ width: CIRCLE_SIZE, height: CIRCLE_SIZE, backgroundColor: DONE_FILL }}
      >
        <Ionicons name="checkmark" size={12} color="#ffffff" />
      </View>
    );
  }
  const ring = PRIORITY_RING[priority];
  return (
    <View
      className="rounded-full"
      style={{
        width: CIRCLE_SIZE,
        height: CIRCLE_SIZE,
        borderWidth: 1.5,
        borderColor: ring?.border ?? NEUTRAL_RING,
        backgroundColor: ring?.fill ?? "transparent",
      }}
    />
  );
}
