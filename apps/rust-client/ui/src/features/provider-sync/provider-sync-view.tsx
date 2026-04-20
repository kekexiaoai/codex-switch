import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { ProviderSyncStatus } from "@/lib/tauri";

export function ProviderSyncView({
  status,
  targetProvider,
  onTargetProviderChange,
  onSync,
  onSwitch,
}: {
  status?: ProviderSyncStatus | null;
  targetProvider: string;
  onTargetProviderChange: (value: string) => void;
  onSync: () => void;
  onSwitch: () => void;
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
