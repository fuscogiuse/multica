"use client";

import { type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { paths as rootPaths, useCurrentWorkspace, useWorkspacePaths } from "@multica/core/paths";
import { workspaceListOptions } from "@multica/core/workspace";
import { openCreateIssueWithPreference } from "@multica/core/issues/stores/create-mode-store";
import { AppLink, useNavigation } from "../navigation";
import { MulticaIcon } from "@multica/ui/components/common/multica-icon";
import {
  Bell,
  Bot,
  Calendar,
  CalendarDays,
  Check,
  ChevronDown,
  Cpu,
  FolderOpen,
  Inbox,
  LayoutGrid,
  ListChecks,
  MessageSquarePlus,
  Plus,
  PlusCircle,
  Search,
  Settings,
} from "lucide-react";
import { useWorkspaceId } from "@multica/core/hooks";
import { useInboxUnreadCount } from "@multica/core/inbox/queries";
import { useModalStore } from "@multica/core/modals";
import { useSearchStore } from "../search";
import { FeedbackLayer, feedbackStore, useFeedback } from "./calm-feedback";
import { useDueToday } from "./calm-today";
import { cn } from "@multica/ui/lib/utils";
import { CompanyNav } from "./calm-companies";
import { useCalmHref } from "./calm-issues";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@multica/ui/components/ui/dropdown-menu";

export const PlusIcon = ({ size = 18 }: { size?: number }) => <Plus size={size} strokeWidth={1.75} aria-hidden />;

type CalmView = "lista" | "kanban" | "oggi" | "tutti";

function useCalmLocation() {
  const { pathname, searchParams } = useNavigation();
  const paths = useWorkspacePaths();
  const onIssues = pathname === paths.issues();
  const vista = (searchParams.get("vista") as CalmView | null) ?? "lista";
  return { pathname, paths, onIssues, vista };
}

const ICON = { size: 18, strokeWidth: 1.6 } as const;

function NavItem({
  href,
  onClick,
  active,
  icon,
  count,
  countTone = "muted",
  children,
}: {
  href?: string;
  onClick?: () => void;
  active?: boolean;
  icon: ReactNode;
  count?: number;
  countTone?: "muted" | "red";
  children: ReactNode;
}) {
  const cls = cn(
    "flex h-8 w-full items-center gap-2.5 rounded-md px-2 text-left text-sm no-underline transition-colors",
    active ? "bg-[#ffefe5] text-[#c3381e]" : "text-[#202020] hover:bg-black/[0.04]",
  );
  const body = (
    <>
      <span className={cn("flex size-5 shrink-0 items-center justify-center", active ? "text-[#c3381e]" : "text-[#5f5f5f]")}>{icon}</span>
      <span className="min-w-0 flex-1 truncate">{children}</span>
      {count ? <span className={cn("text-xs", countTone === "red" ? "text-[#dc4c3e]" : "text-[#8a8a8a]")}>{count}</span> : null}
    </>
  );
  if (href) {
    return (
      <AppLink href={href} aria-current={active ? "page" : undefined} className={cls}>
        {body}
      </AppLink>
    );
  }
  return (
    <button type="button" onClick={onClick} className={cls}>
      {body}
    </button>
  );
}

const iconButton = "flex size-8 shrink-0 items-center justify-center rounded-md text-[#5f5f5f] hover:bg-black/[0.05] hover:text-[#202020]";

/** Workspace name that doubles as the workspace switcher. */
function WorkspaceSwitcher() {
  const workspace = useCurrentWorkspace();
  const { data: workspaces = [] } = useQuery(workspaceListOptions());
  const { push } = useNavigation();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={<button type="button" className="flex min-w-0 flex-1 items-center gap-2 rounded-md px-1.5 py-1 text-left hover:bg-black/[0.04]" />}
      >
        <div className="flex size-6 shrink-0 items-center justify-center rounded-full bg-[#dc4c3e] text-[11px] font-semibold text-white" aria-hidden>
          {(workspace?.name ?? "C").charAt(0).toUpperCase()}
        </div>
        <span className="min-w-0 truncate text-sm font-semibold">{workspace?.name ?? "Calm Tasks"}</span>
        <ChevronDown size={14} strokeWidth={1.75} className="shrink-0 text-[#8a8a8a]" aria-hidden />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="min-w-56" align="start" side="bottom" sideOffset={4}>
        <DropdownMenuGroup>
          <DropdownMenuLabel className="text-xs text-[#666666]">Workspace</DropdownMenuLabel>
          {workspaces.map((ws) => (
            <DropdownMenuItem key={ws.id} onClick={() => push(rootPaths.workspace(ws.slug).issues())}>
              <span className="flex-1 truncate">{ws.name}</span>
              {ws.id === workspace?.id ? <Check size={14} className="text-[#dc4c3e]" aria-hidden /> : null}
            </DropdownMenuItem>
          ))}
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => push(rootPaths.newWorkspace())}>
          <Plus size={14} aria-hidden />
          Nuovo workspace
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/** Gear menu: everything that is not daily work lives here. */
function SettingsMenu() {
  const paths = useWorkspacePaths();
  const { push } = useNavigation();
  const { active } = useFeedback();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger render={<button type="button" aria-label="Impostazioni" className={iconButton} />}>
        <Settings {...ICON} aria-hidden />
      </DropdownMenuTrigger>
      <DropdownMenuContent className="min-w-52" align="start" side="bottom" sideOffset={4}>
        <DropdownMenuItem onClick={() => push(paths.agents())}>
          <Bot size={15} aria-hidden /> Agenti
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => push(paths.runtimes())}>
          <Cpu size={15} aria-hidden /> Runtime
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => push(paths.projects())}>
          <FolderOpen size={15} aria-hidden /> Tutti i progetti
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => push(`${paths.issues()}?vista=tutti`)}>
          <LayoutGrid size={15} aria-hidden /> Vista completa dei task
        </DropdownMenuItem>
        <DropdownMenuItem onClick={() => push(paths.settings())}>
          <Settings size={15} aria-hidden /> Impostazioni
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => feedbackStore.toggle()}>
          <MessageSquarePlus size={15} aria-hidden /> {active ? "Esci da modalità commento" : "Modalità commento"}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/** Calendar with today's day number, like Todoist's "Today". */
function TodayIcon() {
  return (
    <span className="relative inline-flex size-[18px] items-center justify-center" aria-hidden>
      <Calendar size={18} strokeWidth={1.6} className="absolute inset-0" />
      <span className="relative mt-[5px] text-[8px] font-semibold leading-none">{new Date().getDate()}</span>
    </span>
  );
}

/** Desktop sidebar (≥768px), shaped like Todoist's. Phones get the bottom tab bar. */
export function CalmSidebar({ topSlot }: { topSlot?: ReactNode } = {}) {
  const { pathname, paths, onIssues, vista } = useCalmLocation();
  const href = useCalmHref();
  const wsId = useWorkspaceId();
  const unread = useInboxUnreadCount(wsId);
  const { overdue, dueToday } = useDueToday();
  const { searchParams } = useNavigation();
  const projectScope = searchParams.get("progetto");
  const starts = (p: string) => pathname === p || pathname.startsWith(p + "/");

  return (
    <nav
      aria-label="Navigazione"
      className={cn(
        "hidden w-[260px] shrink-0 flex-col gap-0.5 overflow-y-auto bg-[#fcfaf8] px-3 font-sans text-[#202020] md:flex",
        topSlot ? "pb-4" : "py-4",
      )}
    >
      {topSlot}
      <div className="flex items-center gap-0.5 pb-2">
        <WorkspaceSwitcher />
        <AppLink href={paths.inbox()} aria-label="Notifiche" className={cn(iconButton, "relative")}>
          <Bell {...ICON} aria-hidden />
          {unread > 0 ? <span className="absolute right-1.5 top-1.5 size-2 rounded-full bg-[#dc4c3e] ring-2 ring-[#fcfaf8]" /> : null}
        </AppLink>
        <SettingsMenu />
      </div>

      <button
        type="button"
        onClick={() =>
          projectScope
            ? useModalStore.getState().open("create-issue", { project_id: projectScope })
            : openCreateIssueWithPreference()
        }
        className="mb-1 flex h-9 w-full items-center gap-2 rounded-md px-1.5 text-left text-sm font-semibold text-[#c3381e] hover:bg-black/[0.04]"
      >
        <PlusCircle size={22} strokeWidth={1.75} className="fill-[#dc4c3e] text-white" aria-hidden />
        Aggiungi attività
      </button>

      <NavItem onClick={() => useSearchStore.getState().setOpen(true)} icon={<Search {...ICON} />}>
        Cerca
      </NavItem>
      <NavItem href={paths.inbox()} active={starts(paths.inbox())} icon={<Inbox {...ICON} />} count={unread}>
        In arrivo
      </NavItem>
      <NavItem href={href("oggi", {})} active={onIssues && vista === "oggi"} icon={<TodayIcon />} count={overdue.length + dueToday.length} countTone={overdue.length ? "red" : "muted"}>
        Oggi
      </NavItem>
      <NavItem
        href={href(vista === "kanban" ? "kanban" : "lista", {})}
        active={onIssues && (vista === "lista" || vista === "kanban") && !searchParams.get("company") && !projectScope}
        icon={<ListChecks {...ICON} />}
      >
        Task
      </NavItem>

      <div className="mt-4" />
      <CompanyNav />

      <div className="min-h-6 flex-1" />
      <div className="flex items-center gap-1.5 px-2 pt-2 text-[11px] text-[#8a8a8a]">
        <MulticaIcon className="size-3" />
        basato su Multica
      </div>
      <FeedbackLayer />
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
    { href: paths.inbox(), label: "In arrivo", icon: <Inbox size={20} strokeWidth={1.6} />, active: pathname.startsWith(paths.inbox()) },
    { href: `${paths.issues()}?vista=oggi`, label: "Oggi", icon: <CalendarDays size={20} strokeWidth={1.6} />, active: onIssues && vista === "oggi" },
    { href: paths.issues(), label: "Task", icon: <ListChecks size={20} strokeWidth={1.6} />, active: onIssues && (vista === "lista" || vista === "kanban") },
    { href: paths.agents(), label: "Claude", icon: <Bot size={20} strokeWidth={1.6} />, active: pathname.startsWith(paths.agents()) },
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
