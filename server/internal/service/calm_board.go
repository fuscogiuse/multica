package service

// Calm UI fork: the board follows the agent. When a run starts on a task that
// is still waiting (unstarted category: backlog, todo, drafts), the task moves
// to in_progress ("AI working"). When the last run on it finishes and the task
// is still in_progress, it moves to in_review ("Need you") so the owner sees
// the answer is ready. Agents that move the task themselves are left alone.
//
// These writes go through UpdateIssueStatus directly, like the stuck-issue
// reset in task failure handling, so they never trigger a workflow handoff.

import (
	"context"
	"log/slog"

	"github.com/multica-ai/multica/server/internal/issuestatus"
	"github.com/multica-ai/multica/server/internal/issueworkflow"
	"github.com/multica-ai/multica/server/internal/util"
	db "github.com/multica-ai/multica/server/pkg/db/generated"
)

const (
	calmWorkingStatus = "in_progress"
	calmReviewStatus  = "in_review"
)

// calmWorkflowHas reports whether the issue's project workflow lists status.
// Issues outside a project, or a failed lookup, use the whole catalog.
func (s *TaskService) calmWorkflowHas(ctx context.Context, issue db.Issue, status string) bool {
	def, _, err := issueworkflow.ForProject(ctx, s.Queries, issue.WorkspaceID, issue.ProjectID)
	if err != nil || def == nil {
		return true
	}
	return def.Has(status)
}

func (s *TaskService) calmMoveIssue(ctx context.Context, task db.AgentTaskQueue, issue db.Issue, to string) {
	updated, err := s.Queries.UpdateIssueStatus(ctx, db.UpdateIssueStatusParams{
		SourceTaskID: task.ID,
		ID:           issue.ID,
		Status:       to,
		WorkspaceID:  issue.WorkspaceID,
	})
	if err != nil {
		slog.Warn("calm board: move issue failed", "issue_id", util.UUIDToString(issue.ID), "to", to, "error", err)
		return
	}
	s.broadcastIssueUpdated(ctx, updated, issue.Status)
}

// calmOnTaskStarted moves a waiting task to "AI working".
func (s *TaskService) calmOnTaskStarted(ctx context.Context, task db.AgentTaskQueue) {
	if !task.IssueID.Valid {
		return
	}
	issue, err := s.Queries.GetIssue(ctx, task.IssueID)
	if err != nil {
		return
	}
	if issuestatus.Category(ctx, s.Queries, issue.WorkspaceID, issue.Status) != issuestatus.CategoryUnstarted {
		return
	}
	if !s.calmWorkflowHas(ctx, issue, calmWorkingStatus) {
		return
	}
	s.calmMoveIssue(ctx, task, issue, calmWorkingStatus)
}

// calmOnTaskCompleted moves a task the agent left in "AI working" to "Need you".
func (s *TaskService) calmOnTaskCompleted(ctx context.Context, task db.AgentTaskQueue) {
	if !task.IssueID.Valid {
		return
	}
	issue, err := s.Queries.GetIssue(ctx, task.IssueID)
	if err != nil || issue.Status != calmWorkingStatus {
		return
	}
	if active, err := s.Queries.HasActiveTaskForIssue(ctx, task.IssueID); err != nil || active {
		return
	}
	if !s.calmWorkflowHas(ctx, issue, calmReviewStatus) {
		return
	}
	s.calmMoveIssue(ctx, task, issue, calmReviewStatus)
}
