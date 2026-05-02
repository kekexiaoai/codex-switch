import { Activity, Gauge, Grid2X2, History, Rocket, Settings, ShieldEllipsis } from "lucide-react";
import { cn } from "@/lib/cn";

export type AppView = "accounts" | "usage" | "provider-sync" | "sessions" | "diagnostics" | "settings";

const items: Array<{ id: AppView; label: string; icon: typeof Activity }> = [
  { id: "accounts", label: "Accounts", icon: Rocket },
  { id: "usage", label: "Usage", icon: Gauge },
  { id: "provider-sync", label: "Provider Sync", icon: Grid2X2 },
  { id: "sessions", label: "Sessions", icon: History },
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
    <aside className="flex h-full flex-col items-center justify-between py-4" data-testid="floating-dock">
      <div className="h-8" aria-hidden="true" />
      <nav className="floating-dock flex flex-col items-center gap-3 px-2 py-4">
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
              <Icon className="h-[18px] w-[18px]" />
              <span className="sr-only">{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="rounded-full border border-emerald-200/70 bg-emerald-50/72 px-2.5 py-1 text-[9px] font-black uppercase tracking-[0.14em] text-emerald-700 shadow-[0_8px_16px_rgba(16,185,129,0.12)]">
        Ready
      </div>
    </aside>
  );
}
