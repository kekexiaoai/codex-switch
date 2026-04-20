import { Activity, FolderSync, Gauge, Settings, ShieldEllipsis } from "lucide-react";
import { cn } from "@/lib/cn";

export type AppView = "accounts" | "usage" | "provider-sync" | "diagnostics" | "settings";

const items: Array<{ id: AppView; label: string; icon: typeof Activity }> = [
  { id: "accounts", label: "Accounts", icon: Activity },
  { id: "usage", label: "Usage", icon: Gauge },
  { id: "provider-sync", label: "Provider Sync", icon: FolderSync },
  { id: "diagnostics", label: "Diagnostics", icon: ShieldEllipsis },
  { id: "settings", label: "Settings", icon: Settings },
];

export function Sidebar({
  activeView,
  onChange,
}: {
  activeView: AppView;
  onChange: (view: AppView) => void;
}) {
  return (
    <aside className="flex h-full flex-col rounded-[22px] border border-border bg-[rgba(255,255,255,0.78)] p-3 shadow-window backdrop-blur-xl">
      <div className="border-b border-border px-3 pb-4 pt-2">
        <div className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">Codex Switch</div>
        <div className="mt-2 text-lg font-semibold">Desktop Runtime</div>
        <div className="mt-1 text-sm text-muted-foreground">Tauri + Rust + shadcn/ui</div>
      </div>
      <nav className="mt-4 flex flex-1 flex-col gap-1">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onChange(item.id)}
              className={cn(
                "flex items-center gap-3 rounded-xl border px-3 py-2.5 text-left text-sm transition-colors",
                activeView === item.id
                  ? "border-slate-300 bg-foreground text-white"
                  : "border-transparent bg-transparent text-muted-foreground hover:bg-panelAlt hover:text-foreground",
              )}
            >
              <Icon className="h-4 w-4" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="rounded-xl border border-border bg-panelAlt px-3 py-3 text-xs text-muted-foreground">
        主窗口负责完整管理，托盘只保留快速入口。
      </div>
    </aside>
  );
}
