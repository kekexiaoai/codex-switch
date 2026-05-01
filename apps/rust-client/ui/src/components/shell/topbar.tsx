import { Bell, Eye, Filter, FolderOpen, LayoutGrid, List, RefreshCcw, Search, Settings, Upload } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { AppView } from "./sidebar";

const titles: Record<AppView, { title: string; description: string }> = {
  accounts: { title: "仪表盘", description: "账号、配额与 Provider 一站式管理" },
  usage: { title: "Usage", description: "配额快照与刷新来源" },
  "provider-sync": { title: "Provider Sync", description: "配置、会话日志与 SQLite 维护" },
  diagnostics: { title: "Diagnostics", description: "本地诊断事件与运行状态" },
  settings: { title: "Settings", description: "桌面偏好与启动项" },
};

export function Topbar({
  view,
  onOpenMain,
}: {
  view: AppView;
  onOpenMain?: () => void;
}) {
  const current = titles[view];
  return (
    <header className="relative z-10 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="mb-1 text-[12px] font-black uppercase tracking-[0.18em] text-slate-400">Codex Switch</div>
          <div className="flex items-center gap-2">
            <h1 className="m-0 text-[28px] font-black tracking-[-0.05em] text-blue-600">{current.title}</h1>
            <span className="grid h-6 w-6 place-items-center rounded-full border border-slate-300/70 bg-white/54 text-[12px] text-slate-500">
              ?
            </span>
          </div>
          <p className="mt-1 text-[12px] font-medium text-slate-500">{current.description}</p>
        </div>
        <div className="flex items-center gap-3">
          <Button variant="secondary" size="lg">
            平台布局
          </Button>
          <Button variant="secondary" size="lg">
            <Bell className="h-4 w-4" />
            消息通知
          </Button>
        </div>
      </div>
      <div className="desktop-toolbar flex items-center justify-between px-4">
        <div className="flex items-center gap-3">
          <div className="flex h-11 w-52 items-center gap-3 rounded-2xl border border-slate-300/50 bg-white/50 px-4 text-slate-400">
            <Search className="h-4 w-4" />
            <span className="text-[13px]">搜索账号...</span>
          </div>
          <div className="flex rounded-2xl border border-slate-300/50 bg-white/50 p-1">
            <Button variant="ghost" size="sm" className="h-8 rounded-xl">
              <List className="h-4 w-4" />
            </Button>
            <Button size="sm" className="h-8 rounded-xl">
              <LayoutGrid className="h-4 w-4" />
            </Button>
          </div>
          <Button variant="secondary" size="lg">
            <Filter className="h-4 w-4" />
            全部
          </Button>
        </div>
        <div className="flex items-center gap-3">
          <Button size="lg" onClick={onOpenMain}>
            +
          </Button>
          <Button variant="secondary" size="lg">
            <RefreshCcw className="h-4 w-4" />
          </Button>
          <Button variant="secondary" size="lg">
            <Eye className="h-4 w-4" />
          </Button>
          <Button variant="secondary" size="lg">
            <Upload className="h-4 w-4" />
          </Button>
          <Button variant="secondary" size="lg">
            <FolderOpen className="h-4 w-4" />
          </Button>
          <Button variant="secondary" size="lg">
            <Settings className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </header>
  );
}
