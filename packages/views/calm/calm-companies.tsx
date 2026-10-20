"use client";

import { useEffect, useMemo, useState, type FormEvent } from "react";
import { useQuery } from "@tanstack/react-query";
import { useWorkspaceId } from "@multica/core/hooks";
import { useWorkspacePaths } from "@multica/core/paths";
import { projectListOptions, useCreateProject } from "@multica/core/projects";
import {
  companyListOptions,
  useCreateCompany,
  useDeleteCompany,
  useSetProjectCompany,
  useUpdateCompany,
} from "@multica/core/companies";
import type { Company, Project } from "@multica/core/types";
import { Dialog, DialogContent, DialogTitle } from "@multica/ui/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@multica/ui/components/ui/dropdown-menu";
import { cn } from "@multica/ui/lib/utils";
import { ChevronRight, MoreHorizontal, Plus, Settings } from "lucide-react";
import { AppLink, useNavigation } from "../navigation";
import { CALM } from "./shared";
import { useCalmHref, useCalmVista } from "./calm-issues";

// Calm UI fork: companies in the sidebar. A company groups projects on the one
// shared board and picks the Claude profile its agents run under.

const COMPANY_COLORS = ["#dc4c3e", "#eb8909", "#058527", "#246fe0", "#7a5af8", "#c2410c", "#0e7490"];

interface ClaudeProfile {
  name: string;
  dir: string;
}

/** Profiles come from the desktop app; the web build has none and falls back to a typed path. */
function useClaudeProfiles(): ClaudeProfile[] {
  const [profiles, setProfiles] = useState<ClaudeProfile[]>([]);
  useEffect(() => {
    const api = (globalThis as { desktopAPI?: { listClaudeProfiles?: () => Promise<ClaudeProfile[]> } }).desktopAPI;
    api?.listClaudeProfiles?.().then(setProfiles).catch(() => setProfiles([]));
  }, []);
  return profiles;
}

function Chevron({ open }: { open: boolean }) {
  return <ChevronRight size={14} strokeWidth={1.75} aria-hidden className={cn("transition-transform", open && "rotate-90")} />;
}

/** Create or edit a company: name, color and Claude profile. */
export function CompanyDialog({
  company,
  open,
  onOpenChange,
}: {
  company?: Company;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const profiles = useClaudeProfiles();
  const create = useCreateCompany();
  const update = useUpdateCompany();
  const remove = useDeleteCompany();
  const [name, setName] = useState("");
  const [color, setColor] = useState(COMPANY_COLORS[0]!);
  const [dir, setDir] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setName(company?.name ?? "");
    setColor(company?.color ?? COMPANY_COLORS[0]!);
    setDir(company?.claude_config_dir ?? "");
    setError(null);
  }, [open, company]);

  const knownDir = profiles.some((p) => p.dir === dir);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError("Scrivi un nome");
      return;
    }
    try {
      const body = { name: name.trim(), color, claude_config_dir: dir.trim() || null };
      if (company) await update.mutateAsync({ id: company.id, ...body });
      else await create.mutateAsync(body);
      onOpenChange(false);
    } catch {
      setError("Non sono riuscito a salvare. Riprova.");
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="grid-cols-[minmax(0,1fr)] gap-3 bg-white p-5 font-sans text-[#202020] sm:max-w-[460px]">
        <DialogTitle className="text-base font-semibold">{company ? "Modifica company" : "Nuova company"}</DialogTitle>
        <form onSubmit={submit} className="flex min-w-0 flex-col gap-4">
          <label className="flex flex-col gap-1.5 text-sm">
            <span className="text-[#666666]">Nome</span>
            <input
              autoFocus
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                setError(null);
              }}
              placeholder="SOLID"
              className="h-9 rounded-lg border border-black/10 px-3 text-sm outline-none focus:border-[#dc4c3e]"
            />
          </label>

          <div className="flex flex-col gap-1.5 text-sm">
            <span className="text-[#666666]">Colore</span>
            <div className="flex gap-2">
              {COMPANY_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  aria-label={`Colore ${c}`}
                  aria-pressed={color === c}
                  onClick={() => setColor(c)}
                  className={cn("size-6 rounded-full ring-offset-2", color === c && "ring-2 ring-[#202020]")}
                  style={{ background: c }}
                />
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-1.5 text-sm">
            <span className="text-[#666666]">Profilo Claude</span>
            <p className="m-0 text-xs text-[#666666]">Gli agenti usano questo profilo per i task dei progetti di questa company.</p>
            {profiles.length > 0 ? (
              <div className="flex max-h-[220px] flex-col gap-0.5 overflow-y-auto rounded-lg border border-black/[0.06] p-1">
                <ProfileOption label="Profilo predefinito del Mac" sub="Nessuna scelta" checked={dir === ""} onSelect={() => setDir("")} />
                {profiles.map((p) => (
                  <ProfileOption key={p.dir} label={p.name} sub={p.dir} checked={dir === p.dir} onSelect={() => setDir(p.dir)} />
                ))}
              </div>
            ) : null}
            <input
              value={dir}
              onChange={(e) => setDir(e.target.value)}
              placeholder="~/.claude-solid"
              className={cn(
                "h-9 min-w-0 rounded-lg border border-black/10 px-3 font-mono text-xs outline-none focus:border-[#dc4c3e]",
                profiles.length > 0 && knownDir && "text-[#666666]",
              )}
            />
            <span className="text-xs text-[#666666]">Puoi anche scrivere a mano la cartella di un profilo.</span>
          </div>

          {error ? <p className="m-0 text-[13px] text-[#d1453b]">{error}</p> : null}

          <div className="flex items-center gap-2">
            {company ? (
              <button
                type="button"
                onClick={async () => {
                  if (!window.confirm(`Eliminare la company "${company.name}"? I progetti restano, senza company.`)) return;
                  await remove.mutateAsync(company.id);
                  onOpenChange(false);
                }}
                className="h-8 rounded-lg px-3 text-[13px] text-[#d1453b] hover:bg-[#fbe4e2]"
              >
                Elimina
              </button>
            ) : null}
            <span className="flex-1" />
            <button type="button" onClick={() => onOpenChange(false)} className="h-8 rounded-lg px-3 text-[13px] text-[#4b4b4b] hover:bg-[#f6f4f1]">
              Annulla
            </button>
            <button type="submit" className="h-8 rounded-lg bg-[#dc4c3e] px-3 text-[13px] font-semibold text-white">
              {company ? "Salva" : "Crea company"}
            </button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function ProfileOption({ label, sub, checked, onSelect }: { label: string; sub: string; checked: boolean; onSelect: () => void }) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={checked}
      className={cn(
        "flex min-w-0 items-center gap-2.5 rounded-md px-2.5 py-1.5 text-left",
        checked ? "bg-[#fbe4e2]" : "hover:bg-[#f6f4f1]",
      )}
    >
      <span className={cn("size-3.5 shrink-0 rounded-full border-2", checked ? "border-[#dc4c3e] bg-[#dc4c3e]" : "border-black/25")} />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="truncate text-[13px] text-[#202020]">{label}</span>
        <span className="truncate font-mono text-[11px] text-[#666666]">{sub}</span>
      </span>
    </button>
  );
}

/** Inline "new project" field inside a company. */
function NewProjectInput({ companyId, onDone }: { companyId: string | null; onDone: () => void }) {
  const createProject = useCreateProject();
  const setCompany = useSetProjectCompany();
  const [title, setTitle] = useState("");
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const t = title.trim();
    if (!t) {
      onDone();
      return;
    }
    const project = await createProject.mutateAsync({ title: t });
    if (companyId) await setCompany.mutateAsync({ projectId: project.id, companyId });
    setTitle("");
    onDone();
  };
  return (
    <form onSubmit={submit} className="px-2 py-1">
      <input
        autoFocus
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onBlur={() => !title.trim() && onDone()}
        onKeyDown={(e) => e.key === "Escape" && onDone()}
        placeholder="Nome progetto, poi Invio"
        className="h-8 w-full rounded-lg border border-black/10 bg-white px-2.5 text-[13px] outline-none focus:border-[#dc4c3e]"
      />
    </form>
  );
}

function ProjectLink({
  project,
  active,
  href,
  companies,
}: {
  project: Project;
  active: boolean;
  href: string;
  companies: Company[];
}) {
  const setCompany = useSetProjectCompany();
  const paths = useWorkspacePaths();
  return (
    <div className={cn("group/project flex h-7 items-center rounded-lg pr-1", active ? "bg-white" : "hover:bg-white/60")}>
      <AppLink
        href={href}
        className={cn(
          "flex min-w-0 flex-1 items-center truncate pl-[26px] text-[13px] no-underline",
          active ? "font-medium text-[#202020]" : "text-[#4b4b4b] hover:text-[#202020]",
        )}
      >
        <span className="truncate">{project.title}</span>
      </AppLink>
      <DropdownMenu>
        <DropdownMenuTrigger
          render={
            <button
              type="button"
              aria-label="Opzioni progetto"
              className="flex size-6 items-center justify-center rounded-md text-[#666666] opacity-0 hover:bg-[#f6f4f1] group-hover/project:opacity-100"
            />
          }
        >
          <MoreHorizontal size={14} strokeWidth={1.75} aria-hidden />
        </DropdownMenuTrigger>
        <DropdownMenuContent className="min-w-52" align="start" side="right">
          <DropdownMenuLabel className="text-xs text-[#666666]">Sposta in</DropdownMenuLabel>
          {companies.map((c) => (
            <DropdownMenuItem key={c.id} onClick={() => setCompany.mutate({ projectId: project.id, companyId: c.id })}>
              <span className="size-2 rounded-full" style={{ background: c.color ?? CALM.primary }} />
              <span className="flex-1 truncate">{c.name}</span>
              {project.company_id === c.id ? <span className="text-[#dc4c3e]">●</span> : null}
            </DropdownMenuItem>
          ))}
          <DropdownMenuItem onClick={() => setCompany.mutate({ projectId: project.id, companyId: null })}>
            Nessuna company
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem render={<AppLink href={paths.projectDetail(project.id)} />}>Apri pagina progetto</DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}

function CompanyGroup({
  company,
  projects,
  activeCompanyId,
  activeProjectId,
  onEdit,
  companies,
}: {
  company: Company | null;
  projects: Project[];
  companies: Company[];
  activeCompanyId: string | null;
  activeProjectId: string | null;
  onEdit?: () => void;
}) {
  const [open, setOpen] = useState(true);
  const [adding, setAdding] = useState(false);
  const href = useCalmHref();
  const vista = useCalmVista();
  const scoped = (scope: { company?: string; progetto?: string }) => href(vista === "tutti" ? "lista" : vista, { company: scope.company ?? null, progetto: scope.progetto ?? null });
  const active = company ? activeCompanyId === company.id && !activeProjectId : false;

  return (
    <div className="flex flex-col">
      <div className={cn("group flex h-8 items-center gap-0.5 rounded-lg pr-1", active && "bg-white")}>
        <button type="button" aria-label={open ? "Chiudi" : "Apri"} onClick={() => setOpen((o) => !o)} className="flex size-6 items-center justify-center text-[#666666]">
          <Chevron open={open} />
        </button>
        {company ? (
          <AppLink href={scoped({ company: company.id })} className="flex min-w-0 flex-1 items-center gap-2 text-[13px] font-medium text-[#202020] no-underline">
            <span className="size-2.5 shrink-0 rounded-full" style={{ background: company.color ?? CALM.primary }} />
            <span className="truncate">{company.name}</span>
          </AppLink>
        ) : (
          <span className="flex-1 truncate text-[13px] text-[#666666]">Senza company</span>
        )}
        {onEdit ? (
          <button type="button" aria-label="Impostazioni company" onClick={onEdit} className="flex size-7 items-center justify-center rounded-md text-[#666666] opacity-0 hover:bg-white group-hover:opacity-100">
            <Settings size={14} strokeWidth={1.75} aria-hidden />
          </button>
        ) : null}
        <button type="button" aria-label="Nuovo progetto" onClick={() => { setOpen(true); setAdding(true); }} className="flex size-7 items-center justify-center rounded-md text-[#666666] opacity-0 hover:bg-white group-hover:opacity-100">
          <Plus size={14} strokeWidth={1.75} aria-hidden />
        </button>
      </div>
      {open ? (
        <div className="flex flex-col">
          {projects.map((p) => (
            <ProjectLink key={p.id} project={p} companies={companies} active={activeProjectId === p.id} href={scoped({ progetto: p.id })} />
          ))}
          {adding ? <NewProjectInput companyId={company?.id ?? null} onDone={() => setAdding(false)} /> : null}
          {company && projects.length === 0 && !adding ? (
            <button type="button" onClick={() => setAdding(true)} className="h-7 rounded-lg pl-[26px] text-left text-[13px] text-[#666666] hover:text-[#202020]">
              + Nuovo progetto
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

/** Sidebar section: every company with its projects, plus "new company". */
export function CompanyNav() {
  const wsId = useWorkspaceId();
  const { searchParams } = useNavigation();
  const { data: companies = [] } = useQuery(companyListOptions(wsId));
  const { data: projects = [] } = useQuery(projectListOptions(wsId));
  const [editing, setEditing] = useState<Company | undefined>();
  const [dialogOpen, setDialogOpen] = useState(false);

  const byCompany = useMemo(() => {
    const m = new Map<string | null, Project[]>();
    for (const p of projects) {
      if (p.status === "cancelled" || p.status === "completed") continue;
      const key = p.company_id && companies.some((c) => c.id === p.company_id) ? p.company_id : null;
      m.set(key, [...(m.get(key) ?? []), p]);
    }
    return m;
  }, [projects, companies]);

  const activeCompanyId = searchParams.get("company");
  const activeProjectId = searchParams.get("progetto");
  const loose = byCompany.get(null) ?? [];

  return (
    <div className="flex flex-col gap-0.5">
      <span className="px-2 pb-1 text-[13px] font-semibold text-[#5f5f5f]">I miei progetti</span>
      {companies.map((c) => (
        <CompanyGroup
          key={c.id}
          company={c}
          projects={byCompany.get(c.id) ?? []}
          companies={companies}
          activeCompanyId={activeCompanyId}
          activeProjectId={activeProjectId}
          onEdit={() => {
            setEditing(c);
            setDialogOpen(true);
          }}
        />
      ))}
      {loose.length > 0 ? (
        <CompanyGroup company={null} projects={loose} companies={companies} activeCompanyId={activeCompanyId} activeProjectId={activeProjectId} />
      ) : null}
      <button
        type="button"
        onClick={() => {
          setEditing(undefined);
          setDialogOpen(true);
        }}
        className="flex h-7 items-center gap-1.5 px-2 text-left text-[13px] text-[#5f5f5f] hover:text-[#202020]"
      >
        <Plus size={14} strokeWidth={1.75} aria-hidden /> Nuova company
      </button>
      <CompanyDialog company={editing} open={dialogOpen} onOpenChange={setDialogOpen} />
    </div>
  );
}
