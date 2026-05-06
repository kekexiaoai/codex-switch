import { useMemo, useState } from "react";
import type { ReactNode } from "react";
import {
  ArrowRightLeft,
  Bot,
  Clock3,
  Copy,
  Eye,
  EyeOff,
  FolderOpen,
  Import,
  RefreshCcw,
  Trash2,
  UserRoundPlus,
  UsersRound,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import type { AccountListItem, CurrentAuthMode, LoginJobState, UsageSnapshot, UsageSourceMode } from "@/lib/tauri";
import { displayEmail } from "./display-email";

export function AccountsView({
  accounts,
  usage,
  loginState,
  loginBusy,
  currentAuthMode,
  showFullEmail,
  usageSourceMode,
  usageRefreshStatus,
  onShowFullEmailChange,
  onImportCurrent,
  onImportBackup,
  onImportBackupDirectory,
  onSwitch,
  onRemove,
  onRefreshUsage,
  onLogin,
  onCancelLogin,
}: {
  accounts: AccountListItem[];
  usage?: UsageSnapshot | null;
  loginState?: LoginJobState | null;
  loginBusy?: boolean;
  currentAuthMode: CurrentAuthMode;
  showFullEmail: boolean;
  usageSourceMode: UsageSourceMode;
  usageRefreshStatus?: { kind: "success" | "error"; message: string } | null;
  onShowFullEmailChange: (showFullEmail: boolean) => void;
  onImportCurrent: () => void;
  onImportBackup: () => void;
  onImportBackupDirectory: () => void;
  onSwitch: (id: string) => void;
  onRemove: (id: string) => void;
  onRefreshUsage: () => void;
  onLogin: () => void;
  onCancelLogin: () => void;
}) {
  const active = useMemo(() => accounts.find((account) => account.isActive), [accounts]);
  const usageSummary = usage ? `${usage.fiveHour.percentUsed}% / ${usage.weekly.percentUsed}%` : "--";
  const tierCounts = useMemo(
    () =>
      accounts.reduce<Record<string, number>>((counts, account) => {
        counts[account.tier] = (counts[account.tier] ?? 0) + 1;
        return counts;
      }, {}),
    [accounts],
  );
  const quickSwitchAccount = accounts.find((account) => !account.isActive) ?? (active ? undefined : accounts[0]);
  const usageSourceLabel = formatUsageSource(usageSourceMode);
  const currentModeLabel = formatCurrentAuthMode(currentAuthMode);
  const usageForAccount = (account?: AccountListItem) =>
    account && usage?.accountId === account.id ? usage : null;

  return (
    <div className="flex h-full min-h-0 flex-col gap-4 overflow-hidden">
      <div className="grid grid-cols-3 gap-4">
        <StatCard
          icon={<Bot className="h-7 w-7" />}
          label="当前 Codex 账号"
          value={active ? displayEmail(active, showFullEmail) : currentModeLabel}
          compact
        />
        <StatCard icon={<UsersRound className="h-7 w-7" />} label="本地归档账号" value={`${accounts.length}`} />
        <StatCard icon={<Clock3 className="h-7 w-7" />} label="Usage 5h / Weekly" value={usageSummary} />
      </div>

      <Card className="flex shrink-0 items-center justify-between gap-4 px-5 py-4">
        <div className="flex min-w-0 items-center gap-3">
          <div className="grid h-9 w-9 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-blue-50 to-cyan-50 text-blue-600">
            <Bot className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <div className="text-[18px] font-black tracking-[-0.04em]">账号工作台</div>
            <div className="truncate text-[11px] font-semibold uppercase tracking-[0.08em] text-slate-400">
              当前 auth.json / 归档账号 / 浏览器登录
            </div>
          </div>
        </div>
        <div className="flex shrink-0 flex-wrap justify-end gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => onShowFullEmailChange(!showFullEmail)}
            aria-pressed={showFullEmail}
          >
            {showFullEmail ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
            {showFullEmail ? "隐藏邮箱" : "显示完整邮箱"}
          </Button>
          <Button variant="secondary" size="sm" onClick={onRefreshUsage}>
            <RefreshCcw className="h-3.5 w-3.5" />
            刷新 Usage
          </Button>
          <Button variant="secondary" size="sm" onClick={onImportCurrent}>
            <Import className="h-3.5 w-3.5" />
            导入当前
          </Button>
          <Button variant="secondary" size="sm" onClick={onImportBackup}>
            导入备份
          </Button>
          <Button variant="secondary" size="sm" onClick={onImportBackupDirectory}>
            <FolderOpen className="h-3.5 w-3.5" />
            导入文件夹
          </Button>
          <Button size="sm" onClick={onLogin} disabled={loginBusy}>
            <UserRoundPlus className="h-3.5 w-3.5" />
            浏览器登录
          </Button>
        </div>
      </Card>

      <div className="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_300px] gap-4">
        <Card className="flex min-h-0 flex-col overflow-hidden">
          <div className="flex shrink-0 items-center justify-between border-b border-slate-200/70 px-5 py-3">
            <div>
              <div className="text-[15px] font-black tracking-[-0.03em]">归档账号</div>
              <div className="mt-0.5 text-[11px] font-semibold text-slate-400">来自 ~/.codex/accounts 的可切换身份</div>
            </div>
            <div className="rounded-full border border-slate-300/50 bg-white/54 px-2.5 py-1 text-[11px] font-bold text-slate-500">
              {accounts.length} 个账号
            </div>
          </div>
          <div className="grid shrink-0 grid-cols-[minmax(0,1.4fr)_88px_minmax(220px,0.9fr)_144px] border-b border-slate-200/70 px-5 py-2.5 text-[12px] font-bold text-slate-500">
            <div>邮箱</div>
            <div>订阅</div>
            <div>配额状态</div>
            <div>操作</div>
          </div>
          <div className="min-h-0 flex-1 overflow-auto">
            {accounts.length === 0 ? (
              <div className="px-5 py-8 text-[13px] text-slate-500">暂无归档账号，可先导入当前 auth.json。</div>
            ) : null}
            {accounts.map((account) => (
              <AccountTableRow
                key={account.id}
                account={account}
                usage={usageForAccount(account)}
                showFullEmail={showFullEmail}
                onSwitch={onSwitch}
                onRemove={onRemove}
              />
            ))}
          </div>
        </Card>

        <Card className="flex min-h-0 flex-col gap-4 p-4">
          <div className="flex items-center gap-3">
            <div>
              <div className="text-[15px] font-black tracking-[-0.03em]">当前账号</div>
              <div className="text-[11px] font-semibold text-slate-400">auth.json 当前生效身份</div>
            </div>
          </div>
          <AccountSummaryCard
            account={active}
            usage={usageForAccount(active)}
            showFullEmail={showFullEmail}
            emptyText="未检测到 ChatGPT 账号"
          />
          <div className="rounded-2xl border border-slate-200/80 bg-white/56 p-3">
            <div className="flex items-center justify-between gap-3">
              <span className="text-[12px] font-semibold text-slate-500">配置模式</span>
              <Badge className={currentAuthMode === "openaiApiKey" ? "border-amber-300 bg-amber-50 text-amber-700" : ""}>
                {currentModeLabel}
              </Badge>
            </div>
            {currentAuthMode === "openaiApiKey" ? (
              <div className="mt-2 text-[12px] font-medium leading-5 text-amber-700">
                当前 Codex auth.json 使用 API Key 配置，切换账号前会自动备份，之后可从列表切回。
              </div>
            ) : null}
          </div>
          <UsageStatusCard usage={usage} status={usageRefreshStatus} />
          <div className="desktop-divider" />
          <div>
            <div className="text-[15px] font-black tracking-[-0.03em]">快速切换</div>
            <div className="mt-2">
              <AccountSummaryCard
                account={quickSwitchAccount}
                usage={usageForAccount(quickSwitchAccount)}
                showFullEmail={showFullEmail}
                emptyText="暂无备用账号"
                onSwitch={onSwitch}
              />
            </div>
          </div>
          <div className="desktop-divider" />
          <div>
            <div className="text-[15px] font-black tracking-[-0.03em]">本地状态</div>
            <div className="mt-3 space-y-2">
              <SummaryRow label="Team" value={`${tierCounts.team ?? 0}`} />
              <SummaryRow label="Plus" value={`${tierCounts.plus ?? 0}`} />
              <SummaryRow label="Pro" value={`${tierCounts.pro ?? 0}`} />
              <SummaryRow label="数据源" value={usageSourceLabel} />
              <SummaryRow label="Auth 模式" value={currentModeLabel} />
              <SummaryRow label="Usage" value={usage ? "已读取" : "未刷新"} />
              <SummaryRow label="登录任务" value={loginState?.active ? "运行中" : "空闲"} />
            </div>
          </div>
          <BrowserLoginTaskCard state={loginState} busy={loginBusy} onCancel={onCancelLogin} />
        </Card>
      </div>
    </div>
  );
}

function BrowserLoginTaskCard({
  state,
  busy,
  onCancel,
}: {
  state?: LoginJobState | null;
  busy?: boolean;
  onCancel: () => void;
}) {
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">("idle");
  const active = Boolean(state?.active || busy);
  const authUrl = state?.authUrl ?? null;
  const message = state?.message ?? "尚未启动登录任务。";

  const copyAuthUrl = async () => {
    if (!authUrl) {
      return;
    }
    try {
      await navigator.clipboard.writeText(authUrl);
      setCopyState("copied");
      window.setTimeout(() => setCopyState("idle"), 1800);
    } catch {
      setCopyState("failed");
    }
  };

  return (
    <div
      data-testid="browser-login-task"
      className={[
        "rounded-2xl border p-3 text-[12px] leading-5",
        active ? "border-blue-200 bg-blue-50/70 text-slate-700" : "border-slate-200/80 bg-white/58 text-slate-500",
      ].join(" ")}
    >
      <div className="flex items-center justify-between gap-3">
        <div className="font-black text-slate-900">{active ? "等待浏览器授权" : "浏览器登录"}</div>
        <Badge className={active ? "border-blue-300 bg-blue-50 text-blue-700" : "border-slate-300 bg-slate-50 text-slate-600"}>
          {active ? "进行中" : "空闲"}
        </Badge>
      </div>
      <div className="mt-2 font-medium text-slate-600">{message}</div>
      {authUrl ? (
        <div className="mt-2 truncate rounded-xl border border-blue-100 bg-white/78 px-3 py-2 font-mono text-[11px] text-slate-500">
          {authUrl}
        </div>
      ) : null}
      <div className="mt-3 flex flex-wrap justify-end gap-2">
        <Button type="button" variant="secondary" size="sm" onClick={copyAuthUrl} disabled={!authUrl}>
          <Copy className="h-3.5 w-3.5" />
          复制链接
        </Button>
        {active ? (
          <Button type="button" variant="danger" size="sm" onClick={onCancel}>
            取消登录
          </Button>
        ) : null}
      </div>
      {copyState !== "idle" ? (
        <div className={copyState === "copied" ? "mt-2 text-right font-bold text-emerald-600" : "mt-2 text-right font-bold text-rose-600"}>
          {copyState === "copied" ? "链接已复制" : "复制失败"}
        </div>
      ) : null}
    </div>
  );
}

function StatCard({
  icon,
  label,
  value,
  compact = false,
}: {
  icon: ReactNode;
  label: string;
  value: string;
  compact?: boolean;
}) {
  return (
    <Card className="stat-card flex items-center gap-5">
      <div className="grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br from-blue-50 to-cyan-50 text-blue-600">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="text-[13px] font-bold text-slate-500">{label}</div>
        <div
          className={[
            "mt-1 truncate font-black leading-none tracking-[-0.06em]",
            compact ? "text-[20px]" : "text-[30px]",
          ].join(" ")}
        >
          {value}
        </div>
      </div>
    </Card>
  );
}

function UsageStatusCard({
  usage,
  status,
}: {
  usage?: UsageSnapshot | null;
  status?: { kind: "success" | "error"; message: string } | null;
}) {
  const tone = status?.kind === "error" ? "error" : usage || status?.kind === "success" ? "success" : "idle";
  const badgeClass =
    tone === "error"
      ? "border-rose-300 bg-rose-50 text-rose-700"
      : tone === "success"
        ? "border-emerald-300 bg-emerald-50 text-emerald-700"
        : "border-slate-300 bg-slate-50 text-slate-600";
  const label = tone === "error" ? "异常" : tone === "success" ? "正常" : "未刷新";
  const message =
    status?.message ??
    (usage ? `已读取，来源：${usage.sourceLabel ?? "未知来源"}` : "尚未刷新 Usage，点击刷新后会显示账号状态。");

  return (
    <div
      className={[
        "rounded-2xl border p-3",
        tone === "error" ? "border-rose-200 bg-rose-50/70" : "border-slate-200/80 bg-white/56",
      ].join(" ")}
    >
      <div className="flex items-center justify-between gap-3">
        <span className="text-[12px] font-semibold text-slate-500">Usage 状态</span>
        <Badge className={badgeClass}>{label}</Badge>
      </div>
      <div className={tone === "error" ? "mt-2 text-[12px] font-medium leading-5 text-rose-700" : "mt-2 text-[12px] font-medium leading-5 text-slate-500"}>
        {message}
      </div>
    </div>
  );
}

function AccountSummaryCard({
  account,
  usage,
  showFullEmail,
  emptyText,
  onSwitch,
}: {
  account?: AccountListItem;
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  emptyText: string;
  onSwitch?: (id: string) => void;
}) {
  if (!account) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300/70 bg-white/42 p-4 text-[13px] text-slate-500">
        {emptyText}
      </div>
    );
  }

  const five = usage?.fiveHour.percentUsed ?? 0;
  const weekly = usage?.weekly.percentUsed ?? 0;
  const canSwitch = Boolean(onSwitch && !account.isActive);

  return (
    <button
      type="button"
      disabled={!canSwitch}
      onClick={() => canSwitch && onSwitch?.(account.id)}
      className="desktop-row w-full p-3 text-left disabled:cursor-default disabled:hover:border-transparent disabled:hover:bg-transparent disabled:hover:shadow-none"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="truncate text-[14px] font-black tracking-[-0.04em]">
            {displayEmail(account, showFullEmail)}
          </div>
          <div className="mt-1 text-[11px] font-semibold text-slate-500">
            {sourceLabel(account.source)} · #{account.manualOrder}
          </div>
        </div>
        <TierBadge tier={account.tier} />
      </div>
      <div className="mt-3 grid grid-cols-2 gap-3">
        <UsageBar label="5h" value={five} compact />
        <UsageBar label="Weekly" value={weekly} compact />
      </div>
    </button>
  );
}

function AccountTableRow({
  account,
  usage,
  showFullEmail,
  onSwitch,
  onRemove,
}: {
  account: AccountListItem;
  usage?: UsageSnapshot | null;
  showFullEmail: boolean;
  onSwitch: (id: string) => void;
  onRemove: (id: string) => void;
}) {
  const canSwitch = !account.isActive;
  const email = displayEmail(account, showFullEmail);
  return (
    <div
      className={[
        "grid w-full grid-cols-[minmax(0,1.4fr)_88px_minmax(220px,0.9fr)_144px] items-center border-b border-slate-200/70 px-5 py-3 text-left last:border-b-0",
        account.isActive ? "bg-white/46" : "hover:bg-white/40",
      ].join(" ")}
    >
      <div className="min-w-0">
        <div className="truncate text-[14px] font-bold">{email}</div>
        <div className="truncate text-[11px] text-slate-500">
          {sourceLabel(account.source)} · #{account.manualOrder}
        </div>
      </div>
      <TierBadge tier={account.tier} />
      <div className="grid grid-cols-2 gap-4 pr-4">
        <UsageBar label="5h" value={usage?.fiveHour.percentUsed ?? 0} compact />
        <UsageBar label="Weekly" value={usage?.weekly.percentUsed ?? 0} compact />
      </div>
      <div className="flex items-center gap-2">
        <Button
          type="button"
          variant="ghost"
          size="sm"
          disabled={!canSwitch}
          onClick={() => onSwitch(account.id)}
          aria-label={canSwitch ? `切换到 ${email}` : `当前账号 ${email}`}
          className="h-8 px-2 text-slate-500 disabled:opacity-55"
        >
          {canSwitch ? <ArrowRightLeft className="h-3.5 w-3.5" /> : null}
          {canSwitch ? "切换" : "当前"}
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          disabled={account.isActive}
          onClick={() => onRemove(account.id)}
          aria-label={`清除 ${email}`}
          title={account.isActive ? "当前账号不能清除，请先切换到其他账号" : "清除本地归档账号"}
          className="h-8 px-2 text-rose-600 hover:border-rose-200 hover:bg-rose-50 disabled:text-slate-400 disabled:opacity-55"
        >
          <Trash2 className="h-3.5 w-3.5" />
          清除
        </Button>
      </div>
    </div>
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
  return <Badge className={`${styles[tier]} w-fit justify-self-start whitespace-nowrap px-2`}>{tier}</Badge>;
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

function formatCurrentAuthMode(mode: CurrentAuthMode) {
  if (mode === "openaiApiKey") {
    return "OPENAI_API_KEY 模式";
  }
  if (mode === "oauth") {
    return "OAuth 模式";
  }
  if (mode === "invalid") {
    return "无法识别";
  }
  return "未检测";
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-slate-200/70 pb-2 text-[12px] last:border-b-0 last:pb-0">
      <span className="text-slate-500">{label}</span>
      <span className="font-bold text-slate-800">{value}</span>
    </div>
  );
}

function formatUsageSource(source: UsageSourceMode) {
  return source === "automatic" ? "自动" : "本地";
}
