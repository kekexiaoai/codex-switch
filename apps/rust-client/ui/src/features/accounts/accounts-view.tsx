import { useMemo } from "react";
import { ArrowRightLeft, Import, RefreshCcw, UserRoundPlus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
    <div className="grid h-full grid-cols-[minmax(0,1.25fr)_360px] gap-4 overflow-hidden">
      <Card className="min-h-0 overflow-hidden">
        <CardHeader>
          <div>
            <CardTitle>账号列表</CardTitle>
            <CardDescription>归档账号与当前活跃账号使用同一条 `.codex` 数据链路。</CardDescription>
          </div>
          <div className="flex gap-2">
            <Button variant="secondary" onClick={onImportCurrent}>
              <Import className="h-4 w-4" />
              导入当前
            </Button>
            <Button variant="secondary" onClick={onImportBackup}>
              <Import className="h-4 w-4" />
              导入备份
            </Button>
            <Button onClick={onLogin}>
              <UserRoundPlus className="h-4 w-4" />
              浏览器登录
            </Button>
          </div>
        </CardHeader>
        <CardContent className="flex h-[calc(100%-76px)] flex-col gap-2 overflow-auto">
          {accounts.length === 0 ? (
            <div className="rounded-xl border border-dashed border-border bg-panelAlt p-5 text-sm text-muted-foreground">
              还没有归档账号。可以先导入当前 `auth.json`，或直接启动浏览器登录。
            </div>
          ) : null}
          {accounts.map((account) => (
            <div
              key={account.id}
              className="flex items-center justify-between rounded-xl border border-border bg-panelAlt px-4 py-3"
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <div className="font-medium">{displayEmail(account, showFullEmail)}</div>
                  {account.isActive ? <Badge className="border-emerald-200 bg-emerald-50 text-emerald-700">Active</Badge> : null}
                </div>
                <div className="text-xs text-muted-foreground">
                  {account.tier.toUpperCase()} · {account.source} · order {account.manualOrder}
                </div>
              </div>
              <Button variant="secondary" onClick={() => onSwitch(account.id)} disabled={account.isActive}>
                <ArrowRightLeft className="h-4 w-4" />
                切换
              </Button>
            </div>
          ))}
        </CardContent>
      </Card>

      <div className="flex h-full flex-col gap-4">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>当前账号</CardTitle>
              <CardDescription>显示活跃账号和最近一次 usage 刷新状态。</CardDescription>
            </div>
            <Button variant="secondary" onClick={onRefreshUsage}>
              <RefreshCcw className="h-4 w-4" />
              刷新 Usage
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="text-xl font-semibold">
              {active ? displayEmail(active, showFullEmail) : "未检测到账号"}
            </div>
            <div className="text-sm text-muted-foreground">{active ? `Tier: ${active.tier.toUpperCase()}` : "先导入或登录一个账号。"}</div>
            {usage ? (
              <div className="grid grid-cols-2 gap-3">
                <Metric label="5 小时" value={`${usage.fiveHour.percentUsed}%`} helper={usage.sourceLabel ?? "Unknown"} />
                <Metric label="Weekly" value={`${usage.weekly.percentUsed}%`} helper={new Date(usage.weekly.resetsAt).toLocaleString()} />
              </div>
            ) : (
              <div className="rounded-xl border border-dashed border-border bg-panelAlt p-4 text-sm text-muted-foreground">
                暂无 Usage 快照。点击“刷新 Usage”后会优先走远端 API，再回退到本地日志和缓存。
              </div>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <div>
              <CardTitle>登录状态</CardTitle>
              <CardDescription>浏览器登录完成后会自动检测 `auth.json` 变化并尝试导入。</CardDescription>
            </div>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            {loginState?.message ?? "尚未启动登录任务。"}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function Metric({ label, value, helper }: { label: string; value: string; helper: string }) {
  return (
    <div className="rounded-xl border border-border bg-panelAlt p-4">
      <div className="text-xs uppercase tracking-[0.12em] text-muted-foreground">{label}</div>
      <div className="mt-2 text-2xl font-semibold">{value}</div>
      <div className="mt-1 text-xs text-muted-foreground">{helper}</div>
    </div>
  );
}
