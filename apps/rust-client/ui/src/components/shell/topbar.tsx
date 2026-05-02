import { Activity, Database, ShieldCheck } from "lucide-react";
import type { ReactNode } from "react";
import type { AppView } from "./sidebar";

const titles: Record<AppView, { title: string; description: string }> = {
  accounts: { title: "仪表盘", description: "Codex 账号切换、Usage 快照与本地归档" },
  usage: { title: "Usage", description: "配额快照与刷新来源" },
  "provider-sync": { title: "Provider Sync", description: "配置、会话日志与 SQLite 维护" },
  diagnostics: { title: "Diagnostics", description: "本地诊断事件与运行状态" },
  settings: { title: "Settings", description: "桌面偏好与启动项" },
};

export function Topbar({
  view,
  accountCount,
  provider,
  usageState,
}: {
  view: AppView;
  accountCount: number;
  provider: string;
  usageState: string;
}) {
  const current = titles[view];
  return (
    <header className="app-titlebar relative z-10 flex items-center justify-between gap-5" data-tauri-drag-region>
      <div className="min-w-0">
        <div className="mb-1 flex items-center gap-2 text-[11px] font-black uppercase tracking-[0.18em] text-slate-400">
          <span>Codex Switch</span>
          <span className="h-1 w-1 rounded-full bg-slate-300" />
          <span>Local Desktop</span>
        </div>
        <div className="flex items-center gap-3">
          <h1 className="m-0 text-[28px] font-black tracking-[-0.05em] text-slate-950">{current.title}</h1>
          <span className="rounded-full border border-slate-300/50 bg-white/54 px-2.5 py-1 text-[11px] font-bold uppercase tracking-[0.08em] text-slate-500">
            本地
          </span>
        </div>
        <p className="mt-1 text-[12px] font-medium text-slate-500">{current.description}</p>
      </div>
      <div className="hidden items-center gap-2 xl:flex">
        <StatusPill icon={<Database className="h-3.5 w-3.5" />} label="账号" value={`${accountCount}`} />
        <StatusPill icon={<Activity className="h-3.5 w-3.5" />} label="Usage" value={usageState} />
        <StatusPill icon={<ShieldCheck className="h-3.5 w-3.5" />} label="Provider" value={provider || "OpenAI"} />
      </div>
    </header>
  );
}

function StatusPill({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex h-10 items-center gap-2 rounded-2xl border border-slate-300/45 bg-white/52 px-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.82)]">
      <span className="text-slate-400">{icon}</span>
      <span className="text-[11px] font-bold text-slate-400">{label}</span>
      <span className="max-w-28 truncate text-[12px] font-black text-slate-800">{value}</span>
    </div>
  );
}
