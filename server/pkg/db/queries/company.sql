-- name: ListCompanies :many
SELECT * FROM company
WHERE workspace_id = $1
ORDER BY position, created_at;

-- name: GetCompanyInWorkspace :one
SELECT * FROM company
WHERE id = $1 AND workspace_id = $2;

-- name: CreateCompany :one
INSERT INTO company (workspace_id, name, color, claude_config_dir, position)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateCompany :one
UPDATE company SET
    name = COALESCE(sqlc.narg('name'), name),
    color = CASE WHEN sqlc.arg('color_set')::boolean THEN sqlc.narg('color') ELSE color END,
    claude_config_dir = CASE WHEN sqlc.arg('claude_config_dir_set')::boolean THEN sqlc.narg('claude_config_dir') ELSE claude_config_dir END,
    updated_at = now()
WHERE id = $1 AND workspace_id = $2
RETURNING *;

-- name: DeleteCompany :exec
DELETE FROM company WHERE id = $1 AND workspace_id = $2;

-- name: SetProjectCompany :one
UPDATE project SET company_id = sqlc.narg('company_id'), updated_at = now()
WHERE id = $1 AND workspace_id = $2
RETURNING *;

-- name: GetCompanyClaudeConfigDirForProject :one
SELECT c.claude_config_dir FROM project p
JOIN company c ON c.id = p.company_id
WHERE p.id = $1;
