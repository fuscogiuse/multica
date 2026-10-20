/**
 * Calm UI fork: a company groups projects inside one workspace and names the
 * Claude Code profile (CLAUDE_CONFIG_DIR on the daemon's machine) agents use
 * for that company's issues.
 */
export interface Company {
  id: string;
  workspace_id: string;
  name: string;
  color: string | null;
  claude_config_dir: string | null;
  position: number;
  created_at: string;
  updated_at: string;
}

export interface ListCompaniesResponse {
  companies: Company[];
  total: number;
}

export interface CreateCompanyRequest {
  name: string;
  color?: string | null;
  claude_config_dir?: string | null;
}

export interface UpdateCompanyRequest {
  name?: string;
  color?: string | null;
  claude_config_dir?: string | null;
}
