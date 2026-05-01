import { useMemo } from "react";
import type { ReactNode } from "react";
import { ArrowRightLeft, Bot, Import, RefreshCcw, Sparkles, UserRoundPlus, UsersRound } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
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
  const recommended = accounts.find((account) => !account.isActive) ?? active ?? accounts[0];
  const providerPanels = [
    {
      name: "Codex",
      icon: <Bot className="h-5 w-5" />,
      accounts,
    },
    {
      name: "Antigravity",
      icon: <Sparkles className="h-5 w-5" />,
      accounts: accounts.slice().reverse(),
    },
  ];

  return (
    <div className="flex h-full min-h-0 flex-col gap-6 overflow-hidden">
      <div className="grid grid-cols-3 gap-5">
        <StatCard icon={<UsersRound className="h-7 w-7" />} label="账号总数" value={`${accounts.length}`} />
        <StatCard icon={<Sparkles className="h-7 w-7" />} label="Antigravity" value={`${Math.max(0, Math.ceil(accounts.length / 2))}`} />
        <StatCard icon={<Bot className="h-7 w-7" />} label="Codex" value={`${accounts.length}`} />
      </div>

      <div className="grid min-h-0 flex-1 grid-cols-2 gap-5 overflow-hidden">
        {providerPanels.map((panel) => (
          <Card key={panel.name} className="flex min-h-0 flex-col overflow-hidden">
            <div className="flex items-center justify-between border-b border-slate-200/70 px-5 py-4">
              <div className="flex items-center gap-3">
                <div className="grid h-9 w-9 place-items-center rounded-2xl bg-gradient-to-br from-blue-50 to-cyan-50 text-blue-600">
                  {panel.icon}
                </div>
                <div>
                  <div className="text-[18px] font-black tracking-[-0.04em]">{panel.name}</div>
                  <div className="text-[11px] font-semibold uppercase tracking-[0.08em] text-slate-400">
                    当前账户 / 推荐账号
                  </div>
                </div>
              </div>
              <div className="flex gap-2">
                <Button variant="secondary" size="sm" onClick={onRefreshUsage}>
                  <RefreshCcw className="h-3.5 w-3.5" />
                  刷新
                </Button>
                <Button variant="secondary" size="sm" onClick={onImportCurrent}>
                  <Import className="h-3.5 w-3.5" />
                </Button>
              </div>
            </div>

            <div className="grid min-h-0 flex-1 grid-cols-2 divide-x divide-slate-200/70 overflow-hidden">
              <AccountColumn
                title="当前账户"
                account={active}
                usage={usage}
                showFullEmail={showFullEmail}
                emptyText="未检测到 ChatGPT 账号"
                onSwitch={onSwitch}
              />
              <AccountColumn
                title="推荐账号"
                account={recommended}
                usage={usage}
                showFullEmail={showFullEmail}
                emptyText="暂无可推荐账号"
                onSwitch={onSwitch}
              />
            </div>

            <div className="grid grid-cols-3 gap-3 border-t border-slate-200/70 px-5 py-4">
              <Button onClick={onLogin}>
                <UserRoundPlus className="h-4 w-4" />
                浏览器登录
              </Button>
              <Button variant="secondary" onClick={onImportBackup}>
                导入备份
              </Button>
              <Button variant="secondary" onClick={onRefreshUsage}>
                刷新 Usage
              </Button>
            </div>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-[minmax(0,1fr)_320px] gap-5">
        <Card className="overflow-hidden">
          <div className="grid grid-cols-[minmax(0,1fr)_120px_220px_150px] border-b border-slate-200/70 px-5 py-3 text-[12px] font-bold text-slate-500">
            <div>邮箱</div>
            <div>订阅</div>
            <div>配额状态</div>
            <div>操作</div>
          </div>
          <div className="max-h-[240px] overflow-auto">
            {accounts.length === 0 ? (
              <div className="px-5 py-8 text-[13px] text-slate-500">暂无归档账号，可先导入当前 auth.json。</div>
            ) : null}
            {accounts.map((account) => (
              <AccountTableRow
                key={account.id}
                account={account}
                usage={usage}
                showFullEmail={showFullEmail}
                onSwitch={onSwitch}
              />
            ))}
          </div>
        </Card>

        <Card className="p-5">
          <div className="text-[15px] font-black tracking-[-0.03em]">运行摘要</div>
          <div className="mt-4 space-y-3">
            <SummaryRow label="Team" value={`${tierCounts.team ?? 0}`} />
            <SummaryRow label="Plus" value={`${tierCounts.plus ?? 0}`} />
            <SummaryRow label="Pro" value={`${tierCounts.pro ?? 0}`} />
            <SummaryRow label="登录任务" value={loginState?.active ? "运行中" : "空闲"} />
          </div>
          <div className="mt-4 rounded-2xl bg-white/58 p-3 text-[12px] leading-5 text-slate-500">
            {loginState?.message ?? "尚未启动登录任务。"}
          </div>
        </Card>
      </div>
    </div>
  );
}

function StatCard({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <Card className="stat-card flex items-center gap-5">
      <div className="grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br from-blue-50 to-cyan-50 text-blue-600">
        {icon}
      </div>
      <div>
        <div className="text-[13px] font-bold text-slate-500">{label}</div>
        <div className="mt-1 text-[30px] font-black leading-none tracking-[-0.06em]">{value}</div>
      </div>
    </Card>
  );
}

function AccountColumn({
  title,
  account,
  usage,
  showFullEmail,
  emptyText,
  onSwitch,
}: {
  title: string;
  account?: AccountListItem;
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  emptyText: string;
  onSwitch: (id: string) => void;
}) {
  return (
    <div className="min-w-0 p-5">
      <div className="mb-4 flex items-center gap-2 text-[12px] font-bold text-slate-400">
        <span className="grid h-4 w-4 place-items-center rounded-full border border-slate-300 text-[10px]">✓</span>
        {title}
      </div>
      {account ? (
        <AccountCard account={account} usage={usage} showFullEmail={showFullEmail} onSwitch={onSwitch} />
      ) : (
        <div className="rounded-2xl border border-dashed border-slate-300/70 bg-white/42 p-5 text-[13px] text-slate-500">
          {emptyText}
        </div>
      )}
    </div>
  );
}

function AccountCard({
  account,
  usage,
  showFullEmail,
  onSwitch,
}: {
  account: AccountListItem;
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  onSwitch: (id: string) => void;
}) {
  const five = usage?.fiveHour.percentUsed ?? 0;
  const weekly = usage?.weekly.percentUsed ?? 0;

  return (
    <button
      type="button"
      onClick={() => !account.isActive && onSwitch(account.id)}
      className="desktop-row w-full p-4 text-left"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="truncate text-[16px] font-black tracking-[-0.04em]">
            {displayEmail(account, showFullEmail)}
          </div>
          <div className="mt-2 text-[12px] font-semibold text-slate-500">{sourceLabel(account.source)}</div>
        </div>
        <TierBadge tier={account.tier} />
      </div>
      <UsageBar label="5h" value={five} />
      <UsageBar label="Weekly" value={weekly} />
      <div className="mt-5 flex items-center justify-end gap-5 border-t border-dashed border-slate-200 pt-3 text-slate-400">
        <ArrowRightLeft className="h-4 w-4" />
        <RefreshCcw className="h-4 w-4" />
      </div>
    </button>
  );
}

function AccountTableRow({
  account,
  usage,
  showFullEmail,
  onSwitch,
}: {
  account: AccountListItem;
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  onSwitch: (id: string) => void;
}) {
  return (
    <button
      type="button"
      onClick={() => !account.isActive && onSwitch(account.id)}
      className={[
        "grid w-full grid-cols-[minmax(0,1fr)_120px_220px_150px] items-center border-b border-slate-200/70 px-5 py-4 text-left last:border-b-0",
        account.isActive ? "bg-white/46" : "hover:bg-white/40",
      ].join(" ")}
    >
      <div className="min-w-0">
        <div className="truncate text-[14px] font-bold">{displayEmail(account, showFullEmail)}</div>
        <div className="truncate text-[11px] text-slate-500">
          {sourceLabel(account.source)} · #{account.manualOrder}
        </div>
      </div>
      <TierBadge tier={account.tier} />
      <div className="grid grid-cols-2 gap-4 pr-4">
        <UsageBar label="5h" value={usage?.fiveHour.percentUsed ?? 0} compact />
        <UsageBar label="Weekly" value={usage?.weekly.percentUsed ?? 0} compact />
      </div>
      <div className="flex items-center gap-4 text-slate-400">
        <ArrowRightLeft className="h-4 w-4" />
        <RefreshCcw className="h-4 w-4" />
      </div>
    </button>
  );
}

function UsageBar({ label, value, compact = false }: { label: string; value: number; compact?: boolean }) {
  const percent = Math.max(0, Math.min(100, value));
  const warning = percent > 60 && percent < 85;
  return (
    <div className={compact ? "" : "mt-5"}>
      <div className="mb-1 flex items-center justify-between text-[12px] font-semibold text-slate-500">
        <span>{label}</span>
        <span className={warning ? "text-amber-500" : "text-emerald-500"}>{percent}%</span>
      </div>
      <div className="usage-track">
        <div className={warning ? "usage-fill usage-fill-warning" : "usage-fill"} style={{ width: `${percent}%` }} />
      </div>
      {!compact ? <div className="mt-1 text-right text-[11px] text-slate-500">已重置</div> : null}
    </div>
  );
}

function TierBadge({ tier }: { tier: AccountListItem["tier"] }) {
  const styles: Record<AccountListItem["tier"], string> = {
    plus: "border-emerald-300 bg-emerald-50 text-emerald-700",
    pro: "border-sky-300 bg-sky-50 text-sky-700",
    team: "border-violet-300 bg-violet-50 text-violet-700",
    unknown: "border-slate-300 bg-slate-50 text-slate-600",
  };
  return <Badge className={styles[tier]}>{tier}</Badge>;
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
    <div className="flex items-center justify-between gap-3 border-b border-slate-200/70 pb-2 text-[12px] last:border-b-0 last:pb-0">
      <span className="text-slate-500">{label}</span>
      <span className="font-bold text-slate-800">{value}</span>
    </div>
  );
}
