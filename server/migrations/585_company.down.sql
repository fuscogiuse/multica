DROP INDEX IF EXISTS idx_project_company;
ALTER TABLE project DROP COLUMN IF EXISTS company_id;
DROP TABLE IF EXISTS company;
