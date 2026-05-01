import { Activity, ChevronDown, FileText, FolderSync, Gauge, Grid2X2, Rocket, Settings, ShieldEllipsis } from "lucide-react";
import { cn } from "@/lib/cn";

export type AppView = "accounts" | "usage" | "provider-sync" | "diagnostics" | "settings";

const items: Array<{ id: AppView; label: string; icon: typeof Activity }> = [
  { id: "accounts", label: "Accounts", icon: Rocket },
  { id: "usage", label: "Usage", icon: Gauge },
  { id: "provider-sync", label: "Provider Sync", icon: Grid2X2 },
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
    <aside className="flex h-full flex-col items-center justify-between py-5" data-testid="floating-dock">
      <button
        type="button"
        className="rounded-2xl bg-gradient-to-br from-blue-600 to-cyan-500 px-4 py-3 text-[13px] font-bold text-white shadow-[0_14px_28px_rgba(37,99,235,0.28)]"
      >
        更新
      </button>
      <nav className="floating-dock flex flex-col items-center gap-5 px-3 py-6">
        {items.map((item) => {
          const Icon = item.icon;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => onChange(item.id)}
              title={item.label}
              className={cn(
                "dock-button",
                activeView === item.id ? "dock-button-active" : "",
              )}
            >
              <Icon className="h-5 w-5" />
              <span className="sr-only">{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="flex flex-col items-center gap-5">
        <button type="button" className="dock-button bg-white/64 shadow-[0_12px_24px_rgba(67,88,116,0.14)]" title="Logs">
          <FileText className="h-5 w-5" />
        </button>
        <ChevronDown className="h-4 w-4 text-slate-400" />
      </div>
    </aside>
  );
}
