import { useMemo } from "react";
import { ArrowRightLeft, Import, RefreshCcw, UserRoundPlus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { AccountListItem, LoginJobState, UsageSnapshot } from "@/lib/tauri";
import { displayEmail } from "./display-email";

export function AccountsView({
  accounts,
  usage,
  loginState,
  showFullEmail,
  onImportCurrent,
  onImportBackup,
  onSwitch,
  onRefreshUsage,
  onLogin,
}: {
  accounts: AccountListItem[];
  usage?: UsageSnapshot | null;
  loginState?: LoginJobState | null;
  showFullEmail: boolean;
  onImportCurrent: () => void;
  onImportBackup: () => void;
  onSwitch: (id: string) => void;
  onRefreshUsage: () => void;
  onLogin: () => void;
}) {
  const active = useMemo(() => accounts.find((account) => account.isActive) ?? accounts[0], [accounts]);

  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_340px] gap-3 overflow-hidden">
      <Card className="min-h-0 overflow-hidden">
        <CardHeader className="h-11">
          <CardTitle>账号列表</CardTitle>
          <div className="flex gap-1.5">
            <Button variant="secondary" size="sm" onClick={onImportCurrent}>
              <Import className="h-3.5 w-3.5" />
              导入当前
            </Button>
            <Button variant="secondary" size="sm" onClick={onImportBackup}>
              <Import className="h-3.5 w-3.5" />
              导入备份
            </Button>
            <Button size="sm" onClick={onLogin}>
              <UserRoundPlus className="h-3.5 w-3.5" />
              浏览器登录
            </Button>
          </div>
        </CardHeader>
        <CardContent className="flex h-[calc(100%-44px)] flex-col gap-1 overflow-auto p-2">
          {accounts.length === 0 ? (
            <div className="desktop-pane p-4 text-[12px] text-muted-foreground">暂无归档账号</div>
          ) : null}
          {accounts.map((account) => (
            <button
              key={account.id}
              type="button"
              onClick={() => !account.isActive && onSwitch(account.id)}
              className={[
                "desktop-row flex w-full items-center justify-between px-3 py-2.5 text-left",
                account.isActive ? "desktop-row-selected" : "",
              ].join(" ")}
            >
              <div className="min-w-0 space-y-1">
                <div className="flex items-center gap-2">
                  <div className="truncate text-[13px] font-medium">{displayEmail(account, showFullEmail)}</div>
                  {account.isActive ? (
                    <Badge className="border-emerald-300 bg-emerald-50 text-emerald-700">Active</Badge>
                  ) : null}
                </div>
                <div className="truncate text-[11px] text-muted-foreground">
                  {account.tier.toUpperCase()} / {account.source} / #{account.manualOrder}
                </div>
              </div>
              <Button variant="secondary" size="sm" disabled={account.isActive}>
                <ArrowRightLeft className="h-3.5 w-3.5" />
                切换
              </Button>
            </button>
          ))}
        </CardContent>
      </Card>

      <div className="flex h-full min-h-0 flex-col gap-3">
        <Card>
          <CardHeader className="h-11">
            <CardTitle>当前账号</CardTitle>
            <Button variant="secondary" size="sm" onClick={onRefreshUsage}>
              <RefreshCcw className="h-3.5 w-3.5" />
              刷新
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="truncate text-[16px] font-semibold">
              {active ? displayEmail(active, showFullEmail) : "未检测到账号"}
            </div>
            <div className="text-[12px] text-muted-foreground">
              {active ? `Tier ${active.tier.toUpperCase()}` : "等待账号导入"}
            </div>
            {usage ? (
              <div className="grid grid-cols-2 gap-2">
                <Metric label="5 小时" value={`${usage.fiveHour.percentUsed}%`} helper={usage.sourceLabel ?? "Unknown"} />
                <Metric label="Weekly" value={`${usage.weekly.percentUsed}%`} helper={new Date(usage.weekly.resetsAt).toLocaleString()} />
              </div>
            ) : (
              <div className="desktop-pane p-3 text-[12px] text-muted-foreground">暂无 Usage 快照</div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="h-11">
            <CardTitle>登录任务</CardTitle>
          </CardHeader>
          <CardContent className="text-[12px] leading-5 text-muted-foreground">
            {loginState?.message ?? "尚未启动登录任务。"}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function Metric({ label, value, helper }: { label: string; value: string; helper: string }) {
  return (
    <div className="desktop-pane p-3">
      <div className="desktop-section-title">{label}</div>
      <div className="mt-1 text-[20px] font-semibold">{value}</div>
      <div className="mt-1 truncate text-[11px] text-muted-foreground">{helper}</div>
    </div>
  );
}
