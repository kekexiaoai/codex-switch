import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { AppView } from "./sidebar";

const titles: Record<AppView, { title: string; description: string }> = {
  accounts: { title: "Accounts", description: "Account archive and active session" },
  usage: { title: "Usage", description: "Quota snapshot" },
  "provider-sync": { title: "Provider Sync", description: "Config, sessions, and SQLite" },
  diagnostics: { title: "Diagnostics", description: "Recent local events" },
  settings: { title: "Settings", description: "Desktop preferences" },
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
          <Badge>Local</Badge>
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
