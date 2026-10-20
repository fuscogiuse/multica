-- Calm UI fork: a company groups projects inside one workspace and picks the
-- Claude Code profile (CLAUDE_CONFIG_DIR) agents use for that company's work.
CREATE TABLE IF NOT EXISTS company (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT,
    claude_config_dir TEXT,
    position INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_company_workspace ON company(workspace_id);

ALTER TABLE project ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES company(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_project_company ON project(company_id);
