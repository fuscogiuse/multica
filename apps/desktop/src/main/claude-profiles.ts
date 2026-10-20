import { ipcMain } from "electron";
import { mkdir, readdir, readFile, stat, writeFile } from "fs/promises";
import { homedir } from "os";
import { join } from "path";

// Calm UI fork: lists the Claude Code profiles on this Mac so a company can
// pick one. A profile is a CLAUDE_CONFIG_DIR: ~/.claude (default), any
// ~/.claude-<name> folder, and the CLI folders of context-switcher profiles.

export interface ClaudeProfile {
  name: string;
  dir: string;
}

async function isDir(p: string): Promise<boolean> {
  try {
    return (await stat(p)).isDirectory();
  } catch {
    return false;
  }
}

function tomlString(src: string, key: string): string | null {
  const m = src.match(new RegExp(`^\\s*${key}\\s*=\\s*"([^"]*)"`, "m"));
  return m ? m[1]! : null;
}

export async function listClaudeProfiles(): Promise<ClaudeProfile[]> {
  const home = homedir();
  const out: ClaudeProfile[] = [];
  const seen = new Set<string>();
  const add = (name: string, dir: string) => {
    if (seen.has(dir)) return;
    seen.add(dir);
    out.push({ name, dir });
  };

  if (await isDir(join(home, ".claude"))) add("Default", join(home, ".claude"));

  const entries = await readdir(home).catch(() => [] as string[]);
  for (const entry of entries.sort()) {
    if (!entry.startsWith(".claude-")) continue;
    const dir = join(home, entry);
    if (!(await isDir(dir))) continue;
    const raw = entry.slice(".claude-".length);
    add(raw.charAt(0).toUpperCase() + raw.slice(1), dir);
  }

  const switcherRoot = join(home, ".context-switcher-claude", "profiles");
  const profiles = await readdir(switcherRoot).catch(() => [] as string[]);
  for (const profile of profiles.sort()) {
    try {
      const toml = await readFile(join(switcherRoot, profile, "profile.toml"), "utf-8");
      const dir = tomlString(toml, "cli_config_dir");
      if (dir && (await isDir(dir))) add(`${tomlString(toml, "name") ?? profile} (switcher)`, dir);
    } catch {
      // Not a profile folder.
    }
  }
  return out;
}

/** Feedback notes from the calm feedback mode, kept where a Claude session can read them. */
export const FEEDBACK_PATH = join(homedir(), ".multica", "calm-feedback.md");

export function setupClaudeProfiles(): void {
  ipcMain.handle("calm:list-claude-profiles", () => listClaudeProfiles());
  ipcMain.handle("calm:save-feedback", async (_event, markdown: unknown) => {
    if (typeof markdown !== "string") return;
    await mkdir(join(homedir(), ".multica"), { recursive: true });
    await writeFile(FEEDBACK_PATH, markdown.slice(0, 1_000_000), "utf-8");
  });
}
