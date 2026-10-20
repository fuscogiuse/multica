package handler

// Calm UI fork: companies group projects inside one workspace. Each company
// names the Claude Code profile (a CLAUDE_CONFIG_DIR on the daemon's machine)
// that agents run under when they work on that company's issues.

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"unicode/utf8"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/multica-ai/multica/server/internal/logger"
	db "github.com/multica-ai/multica/server/pkg/db/generated"
	"github.com/multica-ai/multica/server/pkg/protocol"
)

type CompanyResponse struct {
	ID              string  `json:"id"`
	WorkspaceID     string  `json:"workspace_id"`
	Name            string  `json:"name"`
	Color           *string `json:"color"`
	ClaudeConfigDir *string `json:"claude_config_dir"`
	Position        int32   `json:"position"`
	CreatedAt       string  `json:"created_at"`
	UpdatedAt       string  `json:"updated_at"`
}

func companyToResponse(c db.Company) CompanyResponse {
	return CompanyResponse{
		ID:              uuidToString(c.ID),
		WorkspaceID:     uuidToString(c.WorkspaceID),
		Name:            c.Name,
		Color:           textToPtr(c.Color),
		ClaudeConfigDir: textToPtr(c.ClaudeConfigDir),
		Position:        c.Position,
		CreatedAt:       timestampToString(c.CreatedAt),
		UpdatedAt:       timestampToString(c.UpdatedAt),
	}
}

type CreateCompanyRequest struct {
	Name            string  `json:"name"`
	Color           *string `json:"color"`
	ClaudeConfigDir *string `json:"claude_config_dir"`
}

type UpdateCompanyRequest struct {
	Name            *string `json:"name"`
	Color           *string `json:"color"`
	ClaudeConfigDir *string `json:"claude_config_dir"`
}

type SetProjectCompanyRequest struct {
	CompanyID *string `json:"company_id"`
}

const maxCompanyNameLen = 64

func validateCompanyName(raw string) (string, error) {
	name := strings.TrimSpace(raw)
	if name == "" {
		return "", errors.New("name is required")
	}
	if utf8.RuneCountInString(name) > maxCompanyNameLen {
		return "", errors.New("name must be 64 characters or fewer")
	}
	return name, nil
}

// normalizeOptionalColor accepts nil or empty as "no color".
func normalizeOptionalColor(c *string) (pgtype.Text, error) {
	if c == nil || strings.TrimSpace(*c) == "" {
		return pgtype.Text{}, nil
	}
	norm, err := normalizeColor(*c)
	if err != nil {
		return pgtype.Text{}, err
	}
	return strToText(norm), nil
}

// normalizeConfigDir trims the path; empty means "use the daemon default".
func normalizeConfigDir(p *string) pgtype.Text {
	if p == nil {
		return pgtype.Text{}
	}
	v := strings.TrimSpace(sanitizeNullBytes(*p))
	if v == "" {
		return pgtype.Text{}
	}
	return strToText(v)
}

func (h *Handler) ListCompanies(w http.ResponseWriter, r *http.Request) {
	wsUUID, ok := parseUUIDOrBadRequest(w, h.resolveWorkspaceID(r), "workspace id")
	if !ok {
		return
	}
	rows, err := h.Queries.ListCompanies(r.Context(), wsUUID)
	if err != nil {
		slog.Warn("ListCompanies failed", append(logger.RequestAttrs(r), "error", err)...)
		writeError(w, http.StatusInternalServerError, "failed to list companies")
		return
	}
	resp := make([]CompanyResponse, len(rows))
	for i, c := range rows {
		resp[i] = companyToResponse(c)
	}
	writeJSON(w, http.StatusOK, map[string]any{"companies": resp, "total": len(resp)})
}

func (h *Handler) CreateCompany(w http.ResponseWriter, r *http.Request) {
	var req CreateCompanyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	name, err := validateCompanyName(req.Name)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	color, err := normalizeOptionalColor(req.Color)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	workspaceID := h.resolveWorkspaceID(r)
	wsUUID, ok := parseUUIDOrBadRequest(w, workspaceID, "workspace id")
	if !ok {
		return
	}
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	existing, _ := h.Queries.ListCompanies(r.Context(), wsUUID)
	company, err := h.Queries.CreateCompany(r.Context(), db.CreateCompanyParams{
		WorkspaceID:     wsUUID,
		Name:            name,
		Color:           color,
		ClaudeConfigDir: normalizeConfigDir(req.ClaudeConfigDir),
		Position:        int32(len(existing)),
	})
	if err != nil {
		slog.Warn("CreateCompany failed", append(logger.RequestAttrs(r), "error", err)...)
		writeError(w, http.StatusInternalServerError, "failed to create company")
		return
	}
	resp := companyToResponse(company)
	h.publish(protocol.EventCompanyChanged, workspaceID, "member", userID, map[string]any{"company": resp})
	writeJSON(w, http.StatusCreated, resp)
}

func (h *Handler) UpdateCompany(w http.ResponseWriter, r *http.Request) {
	var req UpdateCompanyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	workspaceID := h.resolveWorkspaceID(r)
	wsUUID, ok := parseUUIDOrBadRequest(w, workspaceID, "workspace id")
	if !ok {
		return
	}
	idUUID, ok := parseUUIDOrBadRequest(w, chi.URLParam(r, "id"), "company id")
	if !ok {
		return
	}
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	params := db.UpdateCompanyParams{ID: idUUID, WorkspaceID: wsUUID}
	if req.Name != nil {
		name, err := validateCompanyName(*req.Name)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		params.Name = strToText(name)
	}
	if req.Color != nil {
		color, err := normalizeOptionalColor(req.Color)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		params.ColorSet = true
		params.Color = color
	}
	if req.ClaudeConfigDir != nil {
		params.ClaudeConfigDirSet = true
		params.ClaudeConfigDir = normalizeConfigDir(req.ClaudeConfigDir)
	}
	company, err := h.Queries.UpdateCompany(r.Context(), params)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "company not found")
			return
		}
		slog.Warn("UpdateCompany failed", append(logger.RequestAttrs(r), "error", err)...)
		writeError(w, http.StatusInternalServerError, "failed to update company")
		return
	}
	resp := companyToResponse(company)
	h.publish(protocol.EventCompanyChanged, workspaceID, "member", userID, map[string]any{"company": resp})
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) DeleteCompany(w http.ResponseWriter, r *http.Request) {
	workspaceID := h.resolveWorkspaceID(r)
	wsUUID, ok := parseUUIDOrBadRequest(w, workspaceID, "workspace id")
	if !ok {
		return
	}
	idUUID, ok := parseUUIDOrBadRequest(w, chi.URLParam(r, "id"), "company id")
	if !ok {
		return
	}
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.Queries.DeleteCompany(r.Context(), db.DeleteCompanyParams{ID: idUUID, WorkspaceID: wsUUID}); err != nil {
		slog.Warn("DeleteCompany failed", append(logger.RequestAttrs(r), "error", err)...)
		writeError(w, http.StatusInternalServerError, "failed to delete company")
		return
	}
	h.publish(protocol.EventCompanyChanged, workspaceID, "member", userID, map[string]any{"company_id": uuidToString(idUUID)})
	w.WriteHeader(http.StatusNoContent)
}

// SetProjectCompany moves a project into a company, or out of every company
// when company_id is null or empty.
func (h *Handler) SetProjectCompany(w http.ResponseWriter, r *http.Request) {
	var req SetProjectCompanyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	workspaceID := h.resolveWorkspaceID(r)
	wsUUID, ok := parseUUIDOrBadRequest(w, workspaceID, "workspace id")
	if !ok {
		return
	}
	projectUUID, ok := parseUUIDOrBadRequest(w, chi.URLParam(r, "id"), "project id")
	if !ok {
		return
	}
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	var companyUUID pgtype.UUID
	if req.CompanyID != nil && *req.CompanyID != "" {
		id, ok := parseUUIDOrBadRequest(w, *req.CompanyID, "company_id")
		if !ok {
			return
		}
		if _, err := h.Queries.GetCompanyInWorkspace(r.Context(), db.GetCompanyInWorkspaceParams{ID: id, WorkspaceID: wsUUID}); err != nil {
			writeError(w, http.StatusNotFound, "company not found")
			return
		}
		companyUUID = id
	}
	project, err := h.Queries.SetProjectCompany(r.Context(), db.SetProjectCompanyParams{
		ID: projectUUID, WorkspaceID: wsUUID, CompanyID: companyUUID,
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "project not found")
			return
		}
		slog.Warn("SetProjectCompany failed", append(logger.RequestAttrs(r), "error", err)...)
		writeError(w, http.StatusInternalServerError, "failed to set project company")
		return
	}
	resp := projectToResponse(project)
	resp.IssueCount, resp.DoneCount = h.loadProjectIssueStats(r.Context(), wsUUID, project.ID)
	resp.ResourceCount = h.loadProjectResourceCount(r.Context(), project.ID)
	h.publish(protocol.EventProjectUpdated, workspaceID, "member", userID, map[string]any{"project": resp})
	writeJSON(w, http.StatusOK, resp)
}
