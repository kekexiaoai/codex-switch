import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { AppView } from "./sidebar";

const titles: Record<AppView, { title: string; description: string }> = {
  accounts: { title: "Accounts", description: "账号归档、当前会话与快速切换" },
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
    <header className="desktop-toolbar flex items-center justify-between rounded-tr-lg px-4">
      <div>
        <div className="flex items-center gap-2">
          <h1 className="m-0 text-[14px] font-semibold">{current.title}</h1>
          <Badge className="bg-white/54">Local</Badge>
        </div>
        <p className="mt-0.5 text-[11px] text-muted-foreground">{current.description}</p>
      </div>
      {onOpenMain ? (
        <Button variant="secondary" size="sm" onClick={onOpenMain}>
          打开主窗口
        </Button>
      ) : null}
    </header>
  );
}
