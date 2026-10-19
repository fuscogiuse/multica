"use client";

import { Suspense } from "react";
import { usePathname } from "next/navigation";
import { DashboardLayout } from "@multica/views/layout";
import { MulticaIcon } from "@multica/ui/components/common/multica-icon";
import { SearchCommand, SearchTrigger } from "@multica/views/search";
import { FloatingChat } from "@multica/views/chat/floating-chat";
import { cn } from "@multica/ui/lib/utils";
import { WebNotificationBridge } from "@/components/web-notification-bridge";
import { WorkspaceDocumentTitle } from "@/platform/workspace-document-title";
import { CalmMobileBar, CalmSidebar } from "@/components/calm/calm-shell";

// Issue detail pages own the whole phone screen (they pin a composer to the
// bottom), so they skip the space reserved for the tab bar.
const ISSUE_DETAIL = /\/issues\/[^/]+/;

export default function Layout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname() ?? "";
  const reserveTabBar = !ISSUE_DETAIL.test(pathname);
  return (
    <>
      {/* useSearchParams requires a Suspense boundary in the app router. Sits
          outside DashboardLayout so the tab is named while the guard is still
          resolving the workspace. */}
      <Suspense fallback={null}>
        <WorkspaceDocumentTitle />
      </Suspense>
      <DashboardLayout
        loadingIndicator={<MulticaIcon className="size-6" />}
        searchSlot={<SearchTrigger />}
        sidebar={<CalmSidebar />}
        shellClassName="bg-white md:bg-[#f6f4f1]"
        insetClassName={cn(
          "bg-white md:m-3 md:ml-0 md:rounded-[22px] md:shadow-[0_1px_2px_rgba(0,0,0,0.04)]",
          reserveTabBar && "pb-[calc(68px+env(safe-area-inset-bottom))] md:pb-0",
        )}
        extra={
          <>
            <SearchCommand />
            <WebNotificationBridge />
            {/* The phone gets the calm tab bar and "+" button instead of
                the floating chat launcher, which would sit on top of them. */}
            <div className="hidden md:block">
              <FloatingChat />
            </div>
            <CalmMobileBar />
          </>
        }
      >
        {children}
      </DashboardLayout>
    </>
  );
}
