"use client";

import type { ReactNode } from "react";
import { SidebarProvider, SidebarInset } from "@multica/ui/components/ui/sidebar";
import { cn } from "@multica/ui/lib/utils";
import { ModalRegistry } from "../modals/registry";
import { SourceBackfillModal } from "../onboarding";
import { AppSidebar } from "./app-sidebar";
import { DashboardGuard } from "./dashboard-guard";
import { NavigationProgress } from "./navigation-progress";
import { WorkspacePresencePrefetch } from "./workspace-presence-prefetch";
import { GlobalShortcuts } from "./global-shortcuts";

interface DashboardLayoutProps {
  children: ReactNode;
  /** Rendered inside SidebarInset (e.g. ChatWindow, ChatFab — absolute-positioned overlays) */
  extra?: ReactNode;
  /** Rendered inside sidebar header as a search trigger */
  searchSlot?: ReactNode;
  /** Loading indicator */
  loadingIndicator?: ReactNode;
  /**
   * Replaces the default AppSidebar. Lets an app ship its own navigation
   * chrome while keeping the guard, providers and modal registry.
   */
  sidebar?: ReactNode;
  /** Extra classes for the main inset (the page panel next to the sidebar). */
  insetClassName?: string;
  /** Extra classes for the outer shell that holds sidebar and inset. */
  shellClassName?: string;
}

export function DashboardLayout({
  children,
  extra,
  searchSlot,
  loadingIndicator,
  sidebar,
  insetClassName,
  shellClassName,
}: DashboardLayoutProps) {
  return (
    <DashboardGuard
      loadingFallback={
        <div className="flex h-svh items-center justify-center">
          {loadingIndicator}
        </div>
      }
    >
      <SidebarProvider className={cn("h-svh bg-app-shell", shellClassName)}>
        <GlobalShortcuts />
        <WorkspacePresencePrefetch />
        {sidebar ?? <AppSidebar searchSlot={searchSlot} />}
        <SidebarInset className={cn("relative overflow-hidden", insetClassName)}>
          <NavigationProgress />
          {children}
          <ModalRegistry />
          <SourceBackfillModal />
          {extra}
        </SidebarInset>
      </SidebarProvider>
    </DashboardGuard>
  );
}
