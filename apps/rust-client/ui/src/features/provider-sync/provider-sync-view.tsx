import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { BackupEntry, ProviderSyncStatus } from "@/lib/tauri";

export function ProviderSyncView({
  status,
  targetProvider,
  selectedBackupId,
  onTargetProviderChange,
  onSync,
  onSwitch,
  onSelectBackup,
  onRestoreBackup,
  onPruneBackups,
}: {
  status?: ProviderSyncStatus | null;
  targetProvider: string;
  selectedBackupId?: string | null;
  onTargetProviderChange: (value: string) => void;
  onSync: () => void;
  onSwitch: () => void;
  onSelectBackup: (backupId: string) => void;
  onRestoreBackup: (backupId: string) => void;
  onPruneBackups: () => void;
}) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_360px] gap-4">
      <Card className="min-h-0">
        <CardHeader>
          <div>
            <CardTitle>Provider 状态</CardTitle>
            <CardDescription>同时观察 rollout 会话分布和 SQLite threads 分布。</CardDescription>
          </div>
        </CardHeader>
        <CardContent className="grid h-[calc(100%-76px)] grid-cols-2 gap-4 overflow-hidden">
          <ProviderDistributionPanel title="Rollout Logs" items={status?.rolloutDistribution ?? []} />
          <ProviderDistributionPanel title="SQLite Threads" items={status?.sqliteDistribution ?? []} />
        </CardContent>
      </Card>
      <div className="flex flex-col gap-4">
        <Card>
          <CardHeader>
            <div>
              <CardTitle>当前 Provider</CardTitle>
              <CardDescription>当前值与配置列表直接来自 `config.toml`。</CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <div>Current: {status?.currentProvider ?? "openai"}</div>
            <div>Configured: {(status?.configuredProviders ?? []).join(", ") || "openai"}</div>
            <div>Backups: {status?.backupCount ?? 0}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <div>
              <CardTitle>同步操作</CardTitle>
              <CardDescription>备份后再统一改写会话和 SQLite provider。</CardDescription>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input value={targetProvider} onChange={(event) => onTargetProviderChange(event.target.value)} placeholder="输入 provider，例如 openai" />
            <div className="flex gap-2">
              <Button variant="secondary" onClick={onSync}>
                同步现有
              </Button>
              <Button onClick={onSwitch}>
                切换并同步
              </Button>
            </div>
          </CardContent>
        </Card>
        <Card className="min-h-0 flex-1">
          <CardHeader>
            <div>
              <CardTitle>备份</CardTitle>
              <CardDescription>保留最近同步前的配置、SQLite 和被改写的 rollout 文件。</CardDescription>
            </div>
          </CardHeader>
          <CardContent className="flex h-[calc(100%-76px)] flex-col gap-3 overflow-auto">
            <div className="flex gap-2">
              <Button
                variant="secondary"
                onClick={() => selectedBackupId && onRestoreBackup(selectedBackupId)}
                disabled={!selectedBackupId}
              >
                恢复选中备份
              </Button>
              <Button variant="secondary" onClick={onPruneBackups}>
                清理旧备份
              </Button>
            </div>
            {status?.backups?.length ? (
              <div className="space-y-2">
                {status.backups.map((backup) => (
                  <BackupRow
                    key={backup.id}
                    backup={backup}
                    selected={selectedBackupId === backup.id}
                    onSelect={onSelectBackup}
                  />
                ))}
              </div>
            ) : (
              <div className="rounded-xl border border-dashed border-border bg-panelAlt p-4 text-sm text-muted-foreground">
                还没有备份记录。执行同步或切换后会自动创建。
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function ProviderDistributionPanel({
  title,
  items,
}: {
  title: string;
  items: Array<{ provider: string; sessionCount: number }>;
}) {
  return (
    <div className="flex min-h-0 flex-col rounded-xl border border-border bg-panelAlt">
      <div className="border-b border-border px-4 py-3 text-sm font-semibold">{title}</div>
      <div className="flex-1 overflow-auto p-3">
        {items.length === 0 ? (
          <div className="text-sm text-muted-foreground">没有检测到数据。</div>
        ) : (
          <div className="space-y-2">
            {items.map((item) => (
              <div key={item.provider} className="flex items-center justify-between rounded-lg border border-border bg-panel px-3 py-2">
                <span>{item.provider}</span>
                <span className="text-sm text-muted-foreground">{item.sessionCount}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function BackupRow({
  backup,
  selected,
  onSelect,
}: {
  backup: BackupEntry;
  selected: boolean;
  onSelect: (backupId: string) => void;
}) {
  return (
    <button
      type="button"
      onClick={() => onSelect(backup.id)}
      className={[
        "flex w-full items-center justify-between rounded-xl border px-3 py-3 text-left transition-colors",
        selected ? "border-slate-400 bg-slate-100" : "border-border bg-panelAlt hover:bg-panel",
      ].join(" ")}
    >
      <div>
        <div className="font-medium">{backup.targetProvider}</div>
        <div className="mt-1 text-xs text-muted-foreground">
          {new Date(backup.createdAt).toLocaleString()} · {(backup.totalSize / 1024).toFixed(1)} KB
        </div>
      </div>
      <div className="text-xs uppercase tracking-[0.12em] text-muted-foreground">{backup.id}</div>
    </button>
  );
}
