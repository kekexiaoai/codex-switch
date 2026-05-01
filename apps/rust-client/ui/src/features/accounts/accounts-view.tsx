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
  const active = useMemo(() => accounts.find((account) => account.isActive), [accounts]);
  const tierCounts = useMemo(
    () =>
      accounts.reduce<Record<string, number>>((counts, account) => {
        counts[account.tier] = (counts[account.tier] ?? 0) + 1;
        return counts;
      }, {}),
    [accounts],
  );

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
            <div className="desktop-pane p-4 text-[12px] text-muted-foreground">暂无归档账号，可先导入当前 auth.json。</div>
          ) : null}
          {accounts.map((account) => (
            <button
              key={account.id}
              type="button"
              onClick={() => !account.isActive && onSwitch(account.id)}
              className={[
                "desktop-row grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-3 py-2.5 text-left",
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
                <div className="flex min-w-0 items-center gap-2 text-[11px] text-muted-foreground">
                  <span className="shrink-0 uppercase">{account.tier}</span>
                  <span className="h-1 w-1 rounded-full bg-slate-300" />
                  <span className="truncate">{sourceLabel(account.source)}</span>
                  <span className="h-1 w-1 rounded-full bg-slate-300" />
                  <span className="shrink-0">#{account.manualOrder}</span>
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
              {active ? displayEmail(active, showFullEmail) : "未检测到 ChatGPT 账号"}
            </div>
            <div className="text-[12px] text-muted-foreground">
              {active ? `Tier ${active.tier.toUpperCase()}` : "当前 auth.json 不是可切换账号"}
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
            <CardTitle>归档摘要</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <SummaryRow label="归档账号" value={`${accounts.length}`} />
            <SummaryRow label="Team" value={`${tierCounts.team ?? 0}`} />
            <SummaryRow label="Plus" value={`${tierCounts.plus ?? 0}`} />
            <SummaryRow label="Pro" value={`${tierCounts.pro ?? 0}`} />
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

function sourceLabel(source: AccountListItem["source"]) {
  if (source === "currentAuth") {
    return "当前导入";
  }
  if (source === "backupImport") {
    return "备份导入";
  }
  if (source === "browserLogin") {
    return "浏览器登录";
  }
  return "归档";
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-border pb-2 text-[12px] last:border-b-0 last:pb-0">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-medium text-foreground">{value}</span>
    </div>
  );
}
