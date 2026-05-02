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
    <aside className="flex h-full flex-col items-center justify-between py-5" data-testid="floating-dock">
      <div className="grid h-12 w-12 place-items-center rounded-2xl border border-white/70 bg-white/62 text-[14px] font-black tracking-[-0.06em] text-slate-900 shadow-[0_12px_24px_rgba(67,88,116,0.14)]">
        CS
      </div>
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
      <div className="rounded-full border border-emerald-200/70 bg-emerald-50/72 px-3 py-1.5 text-[10px] font-black uppercase tracking-[0.14em] text-emerald-700 shadow-[0_10px_20px_rgba(16,185,129,0.12)]">
        Ready
      </div>
    </aside>
  );
}
