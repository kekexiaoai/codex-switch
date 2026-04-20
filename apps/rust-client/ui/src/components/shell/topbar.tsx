import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { AppView } from "./sidebar";

const titles: Record<AppView, { title: string; description: string }> = {
  accounts: { title: "Accounts", description: "当前账号、导入、切换与桌面登录。" },
  usage: { title: "Usage", description: "读取本地 rollout 日志、缓存与远端 Usage 数据。" },
  "provider-sync": { title: "Provider Sync", description: "统一 provider 元数据、SQLite 与 session meta。" },
  diagnostics: { title: "Diagnostics", description: "查看安全裁剪后的登录和刷新诊断日志。" },
  settings: { title: "Settings", description: "应用偏好设置存储在独立的桌面配置目录。" },
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
    <header className="flex items-center justify-between rounded-[20px] border border-border bg-[rgba(255,255,255,0.8)] px-5 py-4 shadow-panel backdrop-blur-xl">
      <div>
        <div className="flex items-center gap-2">
          <h1 className="m-0 text-lg font-semibold">{current.title}</h1>
          <Badge>Desktop</Badge>
        </div>
        <p className="mt-1 text-sm text-muted-foreground">{current.description}</p>
      </div>
      {onOpenMain ? (
        <Button variant="secondary" onClick={onOpenMain}>
          打开主窗口
        </Button>
      ) : null}
    </header>
  );
}
