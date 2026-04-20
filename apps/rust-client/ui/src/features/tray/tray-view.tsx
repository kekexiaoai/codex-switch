import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { AccountListItem, UsageSnapshot } from "@/lib/tauri";

export function TrayView({
  accounts,
  usage,
  onSwitch,
  onRefresh,
  onOpenMain,
}: {
  accounts: AccountListItem[];
  usage?: UsageSnapshot | null;
  onSwitch: (id: string) => void;
  onRefresh: () => void;
  onOpenMain: () => void;
}) {
  const active = accounts.find((account) => account.isActive) ?? accounts[0];

  return (
    <div className="tray-window">
      <div className="flex h-full flex-col gap-3 rounded-[22px] border border-border bg-[rgba(255,255,255,0.92)] p-3 shadow-window backdrop-blur-xl">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>{active?.emailMask ?? "No account"}</CardTitle>
              <CardDescription>{usage ? `${usage.fiveHour.percentUsed}% / ${usage.weekly.percentUsed}%` : "点击刷新查看 usage"}</CardDescription>
            </div>
          </CardHeader>
        </Card>
        <Card className="flex-1 min-h-0">
          <CardHeader>
            <CardTitle>快速切换</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 overflow-auto">
            {accounts.map((account) => (
              <button
                key={account.id}
                type="button"
                onClick={() => onSwitch(account.id)}
                className="flex w-full items-center justify-between rounded-xl border border-border bg-panelAlt px-3 py-2 text-left"
              >
                <span>{account.emailMask}</span>
                <span className="text-xs text-muted-foreground">{account.tier.toUpperCase()}</span>
              </button>
            ))}
          </CardContent>
        </Card>
        <div className="grid grid-cols-2 gap-2">
          <Button variant="secondary" onClick={onRefresh}>
            刷新
          </Button>
          <Button onClick={onOpenMain}>打开主窗口</Button>
        </div>
      </div>
    </div>
  );
}
