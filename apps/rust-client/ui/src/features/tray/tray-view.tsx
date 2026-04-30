import { RefreshCcw, Settings, SquareArrowOutUpRight, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { AccountListItem, UsageSnapshot } from "@/lib/tauri";
import { displayEmail } from "@/features/accounts/display-email";

export function TrayView({
  accounts,
  usage,
  showFullEmail,
  onSwitch,
  onRefresh,
  onOpenMain,
  onOpenSettings,
  onQuit,
}: {
  accounts: AccountListItem[];
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  onSwitch: (id: string) => void;
  onRefresh: () => void;
  onOpenMain: () => void;
  onOpenSettings: () => void;
  onQuit: () => void;
}) {
  const active = accounts.find((account) => account.isActive) ?? accounts[0];

  return (
    <div className="tray-window">
      <div className="desktop-frame flex h-full flex-col overflow-hidden rounded-lg bg-panel">
        <div className="desktop-toolbar flex items-center justify-between px-3">
          <div className="min-w-0">
            <div className="truncate text-[13px] font-semibold">
              {active ? displayEmail(active, showFullEmail) : "No account"}
            </div>
            <div className="mt-0.5 text-[11px] text-muted-foreground">
              {usage ? `${usage.fiveHour.percentUsed}% / ${usage.weekly.percentUsed}%` : "Usage 未刷新"}
            </div>
          </div>
          <Button variant="ghost" size="sm" onClick={onRefresh} aria-label="刷新">
            <RefreshCcw className="h-3.5 w-3.5" />
          </Button>
        </div>
        <div className="min-h-0 flex-1 overflow-auto p-2">
          <div className="desktop-section-title px-1 pb-1">Accounts</div>
          <div className="space-y-1">
            {accounts.map((account) => (
              <button
                key={account.id}
                type="button"
                onClick={() => onSwitch(account.id)}
                className={[
                  "desktop-row flex w-full items-center justify-between gap-2 px-2.5 py-2 text-left",
                  account.isActive ? "desktop-row-selected" : "",
                ].join(" ")}
              >
                <span className="min-w-0 truncate text-[12px]">{displayEmail(account, showFullEmail)}</span>
                <span className="shrink-0 text-[10px] uppercase text-muted-foreground">{account.tier}</span>
              </button>
            ))}
          </div>
        </div>
        <div className="desktop-statusbar grid grid-cols-3 gap-1 p-2">
          <Button variant="secondary" size="sm" onClick={onOpenMain}>
            <SquareArrowOutUpRight className="h-3.5 w-3.5" />
            主窗口
          </Button>
          <Button variant="secondary" size="sm" onClick={onOpenSettings}>
            <Settings className="h-3.5 w-3.5" />
            设置
          </Button>
          <Button variant="secondary" size="sm" onClick={onQuit}>
            <X className="h-3.5 w-3.5" />
            退出
          </Button>
        </div>
      </div>
    </div>
  );
}
