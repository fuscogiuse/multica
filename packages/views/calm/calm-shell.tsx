"use client";

import { type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { paths as rootPaths, useCurrentWorkspace, useWorkspacePaths } from "@multica/core/paths";
import { workspaceListOptions } from "@multica/core/workspace";
import { openCreateIssueWithPreference } from "@multica/core/issues/stores/create-mode-store";
import { AppLink, useNavigation } from "../navigation";
import { MulticaIcon } from "@multica/ui/components/common/multica-icon";
import { cn } from "@multica/ui/lib/utils";
import { CompanyNav } from "./calm-companies";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@multica/ui/components/ui/dropdown-menu";

/* Icons drawn to match the mockup (1.8 stroke, round caps). */
function Svg({ children, size = 18 }: { children: ReactNode; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      {children}
    </svg>
  );
}
export const SunIcon = ({ size }: { size?: number }) => (
  <Svg size={size}><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></Svg>
);
export const ListIcon = ({ size }: { size?: number }) => (
  <Svg size={size}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" /></Svg>
);
export const BoardIcon = ({ size }: { size?: number }) => (
  <Svg size={size}><rect x="3" y="4" width="5" height="16" rx="1.5" /><rect x="10" y="4" width="5" height="10" rx="1.5" /><rect x="17" y="4" width="4" height="13" rx="1.5" /></Svg>
);
export const PeopleIcon = ({ size }: { size?: number }) => (
  <Svg size={size}><circle cx="9" cy="8" r="3.5" /><circle cx="17" cy="9" r="2.5" /><path d="M3 19c0-3 2.7-5 6-5s6 2 6 5M15 14.5c3 0 6 1.5 6 4.5" /></Svg>
);
export const PlusIcon = ({ size }: { size?: number }) => (
  <Svg size={size}><path d="M12 5v14M5 12h14" /></Svg>
);

type CalmView = "lista" | "kanban" | "tutti";

function useCalmLocation() {
  const { pathname, searchParams } = useNavigation();
  const paths = useWorkspacePaths();
  const onIssues = pathname === paths.issues();
  const vista = (searchParams.get("vista") as CalmView | null) ?? "lista";
  return { pathname, paths, onIssues, vista };
}

function NavItem({ href, active, icon, children }: { href: string; active: boolean; icon: ReactNode; children: ReactNode }) {
  return (
    <AppLink
      href={href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex h-11 items-center gap-3 rounded-[10px] px-3 text-[15px] no-underline transition-colors",
        active
          ? "bg-white font-semibold text-[#202020] shadow-[0_1px_2px_0_rgba(0,0,0,0.05)]"
          : "font-medium text-[#4b4b4b] hover:bg-white/60 hover:text-[#202020]",
      )}
    >
      {icon}
      {children}
    </AppLink>
  );
}

function SmallLink({ href, active, children }: { href: string; active?: boolean; children: ReactNode }) {
  return (
    <AppLink
      href={href}
      className={cn(
        "flex h-8 items-center rounded-lg px-3 text-[13px] no-underline transition-colors",
        active ? "bg-white text-[#202020]" : "text-[#666666] hover:bg-white/60 hover:text-[#202020]",
      )}
    >
      {children}
    </AppLink>
  );
}

/** Brand block that doubles as the workspace switcher. */
function WorkspaceSwitcher() {
  const workspace = useCurrentWorkspace();
  const { data: workspaces = [] } = useQuery(workspaceListOptions());
  const { push } = useNavigation();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <button
            type="button"
            className="flex w-full items-center gap-2.5 rounded-[10px] px-2.5 py-1.5 text-left hover:bg-white/60"
          />
        }
      >
        <div className="size-7 shrink-0 rounded-[9px] bg-[#dc4c3e]" aria-hidden />
        <div className="flex min-w-0 flex-1 flex-col">
          <span className="text-[19px] font-medium leading-tight tracking-[-0.02em]">Calm Tasks</span>
          {workspace?.name ? <span className="truncate text-xs text-[#666666]">{workspace.name}</span> : null}
        </div>
        <Svg size={14}><path d="M7 10l5 5 5-5" /></Svg>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="min-w-56" align="start" side="bottom" sideOffset={4}>
        <DropdownMenuGroup>
          <DropdownMenuLabel className="text-xs text-[#666666]">Workspace</DropdownMenuLabel>
          {workspaces.map((ws) => (
            <DropdownMenuItem key={ws.id} onClick={() => push(rootPaths.workspace(ws.slug).issues())}>
              <span className="flex-1 truncate">{ws.name}</span>
              {ws.id === workspace?.id ? <span className="text-[#dc4c3e]">●</span> : null}
            </DropdownMenuItem>
          ))}
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => push(rootPaths.newWorkspace())}>
          <PlusIcon size={14} />
          Nuovo workspace
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/** Desktop sidebar (≥768px). Hidden on phones, which get the bottom tab bar. */
export function CalmSidebar({ topSlot }: { topSlot?: ReactNode } = {}) {
  const { pathname, paths, onIssues, vista } = useCalmLocation();
  const starts = (p: string) => pathname === p || pathname.startsWith(p + "/");

  return (
    <nav
      aria-label="Navigazione"
      className={cn(
        "hidden w-[248px] shrink-0 flex-col gap-1.5 overflow-y-auto px-[18px] font-sans text-[#202020] md:flex",
        topSlot ? "pb-7" : "py-7",
      )}
    >
      {topSlot}
      <div className="pb-6">
        <WorkspaceSwitcher />
      </div>

      <NavItem href={paths.issues()} active={onIssues && vista === "lista"} icon={<SunIcon />}>
        Oggi
      </NavItem>
      <NavItem href={`${paths.issues()}?vista=kanban`} active={onIssues && vista === "kanban"} icon={<BoardIcon />}>
        Kanban
      </NavItem>
      <NavItem href={`${paths.issues()}?vista=tutti`} active={onIssues && vista === "tutti"} icon={<ListIcon />}>
        Tutti i task
      </NavItem>

      <div className="mx-2.5 my-[18px] h-px bg-black/[0.08]" />
      <CompanyNav />

      <div className="mx-2.5 my-[18px] h-px bg-black/[0.08]" />
      <SmallLink href={paths.inbox()} active={starts(paths.inbox())}>Inbox</SmallLink>
      <SmallLink href={paths.projects()} active={starts(paths.projects())}>Progetti</SmallLink>
      <SmallLink href={paths.agents()} active={pathname === paths.agents()}>Agenti</SmallLink>
      <SmallLink href={paths.runtimes()} active={starts(paths.runtimes())}>Runtime</SmallLink>
      <SmallLink href={paths.settings()} active={starts(paths.settings())}>Impostazioni</SmallLink>

      <div className="min-h-6 flex-1" />
      <div className="rounded-[14px] bg-white p-3.5 text-[13px] leading-relaxed text-[#4b4b4b]">
        Modalità calma attiva. Vedi solo 3 task alla volta.
      </div>
      <div className="flex items-center gap-1.5 px-3 pt-3 text-[11px] text-[#666666]">
        <MulticaIcon className="size-3" />
        basato su Multica
      </div>
    </nav>
  );
}

/** True on routes that own the full phone screen (issue detail has its own composer). */
export function useHidesMobileBar(): boolean {
  const { pathname, paths } = useCalmLocation();
  return pathname.startsWith(paths.issues() + "/");
}

/** Phone chrome (<768px): bottom tab bar plus the red "+" button. */
export function CalmMobileBar() {
  const { pathname, paths, onIssues, vista } = useCalmLocation();
  const hidden = useHidesMobileBar();
  if (hidden) return null;

  const tabs = [
    { href: paths.issues(), label: "Lista", icon: <ListIcon size={22} />, active: onIssues && vista !== "kanban" },
    { href: `${paths.issues()}?vista=kanban`, label: "Kanban", icon: <BoardIcon size={22} />, active: onIssues && vista === "kanban" },
    { href: paths.agents(), label: "Claude", icon: <PeopleIcon size={22} />, active: pathname.startsWith(paths.agents()) },
  ];

  return (
    <div className="md:hidden">
      <button
        type="button"
        aria-label="Nuovo task"
        onClick={() => openCreateIssueWithPreference()}
        className="fixed right-[22px] z-40 inline-flex size-14 items-center justify-center rounded-full bg-[#dc4c3e] text-white shadow-[0_8px_24px_-8px_rgba(0,0,0,0.35)] active:scale-95"
        style={{ bottom: "calc(84px + env(safe-area-inset-bottom))" }}
      >
        <PlusIcon size={24} />
      </button>
      <nav
        aria-label="Schede"
        className="fixed inset-x-0 bottom-0 z-40 flex justify-around border-t border-black/[0.08] bg-white px-[18px] pt-2"
        style={{ paddingBottom: "calc(10px + env(safe-area-inset-bottom))" }}
      >
        {tabs.map((t) => (
          <AppLink
            key={t.label}
            href={t.href}
            aria-current={t.active ? "page" : undefined}
            className={cn(
              "flex min-h-[48px] w-[72px] flex-col items-center gap-1 text-[11px] no-underline",
              t.active ? "font-semibold text-[#dc4c3e]" : "text-[#666666]",
            )}
          >
            {t.icon}
            {t.label}
          </AppLink>
        ))}
      </nav>
    </div>
  );
}
