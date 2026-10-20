-- Calm UI fork: every status is a board column the user can rename, describe
-- (the description is the instruction agents read) and hide from the board.
ALTER TABLE issue_status ADD COLUMN IF NOT EXISTS board_hidden BOOLEAN NOT NULL DEFAULT FALSE;

-- Italian names and a board order for built-ins that still carry the seeded
-- English defaults. Positions are only compared within a category upstream,
-- so a global order does not change Multica's own grouping.
UPDATE issue_status SET name = 'Da fare', position = 1,
  description = CASE WHEN description = 'Queued for work. Moving an issue here starts the assigned agent.' THEN 'Pronto da iniziare. Spostarlo qui avvia l''agente assegnato.' ELSE description END
  WHERE is_system AND key = 'todo' AND name = 'Todo';
UPDATE issue_status SET name = 'In corso', position = 2,
  description = CASE WHEN description = 'Actively being worked on.' THEN 'Ci stai lavorando adesso.' ELSE description END
  WHERE is_system AND key = 'in_progress' AND name = 'In Progress';
UPDATE issue_status SET name = 'In revisione', position = 3,
  description = CASE WHEN description = 'Work delivered, waiting on human review. Finalizes the autopilot run.' THEN 'Lavoro consegnato, aspetta la revisione di Giuseppe.' ELSE description END
  WHERE is_system AND key = 'in_review' AND name = 'In Review';
UPDATE issue_status SET name = 'Fatto', position = 4,
  description = CASE WHEN description = 'Completed.' THEN 'Completato.' ELSE description END
  WHERE is_system AND key = 'done' AND name = 'Done';
UPDATE issue_status SET name = 'Backlog', position = 5, board_hidden = TRUE,
  description = CASE WHEN description = 'Parked. Assigning an issue here never starts an agent run.' THEN 'In attesa. Qui l''agente non parte.' ELSE description END
  WHERE is_system AND key = 'backlog' AND name = 'Backlog';
UPDATE issue_status SET name = 'Bloccato', position = 6, board_hidden = TRUE,
  description = CASE WHEN description = 'Stalled on an external dependency.' THEN 'Fermo per una dipendenza esterna.' ELSE description END
  WHERE is_system AND key = 'blocked' AND name = 'Blocked';
UPDATE issue_status SET name = 'Annullato', position = 7, board_hidden = TRUE,
  description = CASE WHEN description = 'Decided not to do.' THEN 'Deciso di non farlo.' ELSE description END
  WHERE is_system AND key = 'cancelled' AND name = 'Cancelled';
