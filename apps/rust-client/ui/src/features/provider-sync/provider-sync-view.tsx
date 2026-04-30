import { RotateCcw, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
    <div className="grid h-full grid-cols-[minmax(0,1fr)_340px] gap-3 overflow-hidden">
      <Card className="min-h-0 overflow-hidden">
        <CardHeader className="h-11">
          <CardTitle>Provider 状态</CardTitle>
          <div className="text-[11px] text-muted-foreground">Current: {status?.currentProvider ?? "openai"}</div>
        </CardHeader>
        <CardContent className="grid h-[calc(100%-44px)] grid-cols-2 gap-3 overflow-hidden">
          <ProviderDistributionPanel title="Rollout Logs" items={status?.rolloutDistribution ?? []} />
          <ProviderDistributionPanel title="SQLite Threads" items={status?.sqliteDistribution ?? []} />
        </CardContent>
      </Card>
      <div className="flex min-h-0 flex-col gap-3">
        <Card>
          <CardHeader className="h-11">
            <CardTitle>同步操作</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-1.5">
              <div className="desktop-section-title">Target Provider</div>
              <Input
                value={targetProvider}
                onChange={(event) => onTargetProviderChange(event.target.value)}
                placeholder="openai"
              />
            </div>
            <div className="flex gap-2">
              <Button variant="secondary" size="sm" onClick={onSync}>
                同步现有
              </Button>
              <Button size="sm" onClick={onSwitch}>
                切换并同步
              </Button>
            </div>
            <div className="desktop-pane space-y-2 p-3 text-[12px]">
              <InfoRow label="Configured" value={(status?.configuredProviders ?? []).join(", ") || "openai"} />
              <InfoRow label="Backups" value={`${status?.backupCount ?? 0}`} />
              <InfoRow label="Size" value={`${((status?.backupTotalSize ?? 0) / 1024).toFixed(1)} KB`} />
            </div>
          </CardContent>
        </Card>
        <Card className="min-h-0 flex-1 overflow-hidden">
          <CardHeader className="h-11">
            <CardTitle>备份</CardTitle>
            <div className="flex gap-1.5">
              <Button
                variant="secondary"
                size="sm"
                onClick={() => selectedBackupId && onRestoreBackup(selectedBackupId)}
                disabled={!selectedBackupId}
              >
                <RotateCcw className="h-3.5 w-3.5" />
                恢复
              </Button>
              <Button variant="secondary" size="sm" onClick={onPruneBackups}>
                <Trash2 className="h-3.5 w-3.5" />
                清理
              </Button>
            </div>
          </CardHeader>
          <CardContent className="h-[calc(100%-44px)] overflow-auto p-2">
            {status?.backups?.length ? (
              <div className="space-y-1">
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
              <div className="desktop-pane p-3 text-[12px] text-muted-foreground">暂无备份记录</div>
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
    <div className="desktop-pane flex min-h-0 flex-col overflow-hidden">
      <div className="border-b border-border px-3 py-2 text-[12px] font-semibold">{title}</div>
      <div className="flex-1 overflow-auto p-2">
        {items.length === 0 ? (
          <div className="p-2 text-[12px] text-muted-foreground">没有检测到数据</div>
        ) : (
          <div className="space-y-1">
            {items.map((item) => (
              <div key={item.provider} className="desktop-row flex items-center justify-between px-2.5 py-2">
                <span className="truncate text-[12px]">{item.provider}</span>
                <span className="text-[12px] text-muted-foreground">{item.sessionCount}</span>
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
        "desktop-row flex w-full items-center justify-between gap-3 px-2.5 py-2 text-left",
        selected ? "desktop-row-selected" : "",
      ].join(" ")}
    >
      <div className="min-w-0">
        <div className="truncate text-[12px] font-medium">{backup.targetProvider}</div>
        <div className="mt-0.5 truncate text-[11px] text-muted-foreground">
          {new Date(backup.createdAt).toLocaleString()} / {(backup.totalSize / 1024).toFixed(1)} KB
        </div>
      </div>
      <div className="shrink-0 text-[10px] uppercase tracking-[0.04em] text-muted-foreground">{backup.id}</div>
    </button>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-muted-foreground">{label}</span>
      <span className="max-w-[190px] truncate text-foreground">{value}</span>
    </div>
  );
}
