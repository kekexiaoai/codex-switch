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
    <aside className="desktop-frame flex h-full min-w-0 flex-col rounded-l-lg border-r-0 bg-panelAlt">
      <div className="desktop-toolbar flex items-center gap-2 px-3">
        <div className="grid h-7 w-7 place-items-center rounded-md border border-border bg-panel text-[12px] font-semibold shadow-panel">
          CS
        </div>
        <div className="min-w-0">
          <div className="truncate text-[13px] font-semibold">Codex Switch</div>
          <div className="truncate text-[11px] text-muted-foreground">Desktop</div>
        </div>
      </div>
      <nav className="flex flex-1 flex-col gap-0.5 border-t border-white/60 px-2 py-2">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onChange(item.id)}
              className={cn(
                "flex h-8 items-center gap-2 rounded-md border px-2 text-left text-[12px] transition-colors",
                activeView === item.id
                  ? "border-slate-500 bg-slate-800 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.16)]"
                  : "border-transparent bg-transparent text-slate-600 hover:border-border hover:bg-panel hover:text-foreground",
              )}
            >
              <Icon className="h-3.5 w-3.5" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="border-t border-border px-3 py-2 text-[11px] text-muted-foreground">
        Tauri runtime
      </div>
    </aside>
  );
}
