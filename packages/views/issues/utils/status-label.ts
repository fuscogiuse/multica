"use client";

import { useCallback } from "react";
import {
  isBuiltInIssueStatus,
  isIssueStatusCategory,
} from "@multica/core/issue-statuses";
import { useIssueStatuses } from "@multica/core/issue-statuses/hooks";
import { BUILT_IN_STATUS_LABEL } from "@multica/core/issues/config";
import type { BuiltInIssueStatus, IssueStatusCategory } from "@multica/core/types";
import { useT } from "../../i18n";

/**
 * Resolves a status KEY to the label the UI should show (MUL-6243).
 *
 * The catalog carries a `name` for every status including the 7 built-ins, but
 * those built-in names are seeded in English by the server. Rendering them
 * verbatim would turn "进行中" into "In Progress" for every non-English
 * workspace, so built-ins always resolve through i18n and only custom statuses
 * — whose names the workspace authored and which are not translatable — use
 * the catalog's `name`.
 *
 * A key the catalog has never heard of (created seconds ago elsewhere, or a
 * fetch still in flight) falls back to the raw key rather than rendering blank.
 */
export function useStatusLabel(wsId: string) {
  const { t } = useT("issues");
  const { entryOf } = useIssueStatuses(wsId);

  return useCallback(
    (statusKey: string): string => {
      if (isBuiltInIssueStatus(statusKey)) {
        // Calm fork: built-ins can be renamed, so a catalog name that differs
        // from the factory English name wins over the translation.
        const renamed = entryOf(statusKey)?.name;
        if (renamed && renamed !== BUILT_IN_STATUS_LABEL[statusKey as BuiltInIssueStatus]) {
          return renamed;
        }
        return t(($) => $.status[statusKey as BuiltInIssueStatus]);
      }
      const entry = entryOf(statusKey);
      if (entry) return entry.name;
      if (isIssueStatusCategory(statusKey)) {
        return t(($) => $.status_category[statusKey as IssueStatusCategory]);
      }
      return entryOf(statusKey)?.name ?? statusKey;
    },
    [t, entryOf],
  );
}
