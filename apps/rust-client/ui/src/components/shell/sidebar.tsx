import { useState } from "react";
import {
  Activity,
  ChevronLeft,
  ChevronRight,
  Gauge,
  Grid2X2,
  History,
  Rocket,
  Settings,
  ShieldEllipsis,
} from "lucide-react";
import { cn } from "@/lib/cn";

export type AppView = "accounts" | "usage" | "provider-sync" | "sessions" | "diagnostics" | "settings";

type SidebarProps = {
  activeView: AppView;
  onChange: (view: AppView) => void;
};

type NavigationItem = {
  id: AppView;
  label: string;
  icon: typeof Activity;
};

const items: NavigationItem[] = [
  { id: "accounts", label: "Accounts", icon: Rocket },
  { id: "usage", label: "Usage", icon: Gauge },
  { id: "provider-sync", label: "Provider Sync", icon: Grid2X2 },
  { id: "sessions", label: "Sessions", icon: History },
  { id: "diagnostics", label: "Diagnostics", icon: ShieldEllipsis },
  { id: "settings", label: "Settings", icon: Settings },
];

export function Sidebar({ activeView, onChange }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const itemLayout = collapsed ? "justify-center px-0" : "justify-start gap-3 px-3";

  return (
    <aside
      className={cn(
        "desktop-sidebar flex h-full min-h-0 shrink-0 flex-col border-r border-slate-200/80 bg-white/82 p-2 transition-[width] duration-200 ease-out",
        collapsed ? "w-16" : "w-56",
      )}
      data-collapsed={collapsed}
      data-testid="desktop-sidebar"
    >
      <div className={cn("flex h-12 shrink-0 items-center gap-3 px-2", collapsed && "justify-center")}>
        <div className="grid h-9 w-9 shrink-0 place-items-center rounded-md border border-slate-200 bg-slate-950 text-[11px] font-black text-white shadow-sm">
          CS
        </div>
        {!collapsed ? (
          <div className="min-w-0">
            <div className="truncate text-[14px] font-black text-slate-950">Codex Switch</div>
            <div className="truncate text-[11px] font-semibold text-slate-500">Desktop Control</div>
          </div>
        ) : null}
      </div>

      <nav className="mt-3 flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto" aria-label="主导航">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onChange(item.id)}
              title={item.label}
              aria-current={activeView === item.id ? "page" : undefined}
              className={cn(
                "sidebar-button",
                itemLayout,
                activeView === item.id && "sidebar-button-active",
              )}
            >
              <Icon className="h-5 w-5 shrink-0" />
              {collapsed ? (
                <span className="sr-only">{item.label}</span>
              ) : (
                <span className="truncate">{item.label}</span>
              )}
            </button>
          );
        })}
      </nav>

      <div className="mt-3 flex shrink-0 flex-col gap-2 border-t border-slate-200/80 pt-3">
        <button
          type="button"
          className={cn("sidebar-button text-slate-500", itemLayout)}
          aria-label={collapsed ? "展开侧栏" : "折叠侧栏"}
          title={collapsed ? "展开侧栏" : "折叠侧栏"}
          onClick={() => setCollapsed((value) => !value)}
        >
          {collapsed ? <ChevronRight className="h-5 w-5" /> : <ChevronLeft className="h-5 w-5" />}
          {!collapsed ? <span>折叠侧栏</span> : null}
        </button>
      </div>
    </aside>
  );
}
