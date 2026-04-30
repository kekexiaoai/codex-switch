import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { UsageSnapshot } from "@/lib/tauri";

export function UsageView({ usage }: { usage?: UsageSnapshot | null }) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_300px] gap-3">
      <Card>
        <CardHeader className="h-11">
          <CardTitle>Usage Snapshot</CardTitle>
          <div className="text-[11px] text-muted-foreground">{usage?.sourceLabel ?? "未刷新"}</div>
        </CardHeader>
        <CardContent>
          {usage ? (
            <div className="space-y-3">
              <UsageMeter
                label="5 小时"
                value={usage.fiveHour.percentUsed}
                helper={new Date(usage.fiveHour.resetsAt).toLocaleString()}
              />
              <UsageMeter
                label="Weekly"
                value={usage.weekly.percentUsed}
                helper={new Date(usage.weekly.resetsAt).toLocaleString()}
              />
            </div>
          ) : (
            <div className="desktop-pane p-4 text-[12px] text-muted-foreground">暂无可展示数据</div>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="h-11">
          <CardTitle>来源</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-[12px] text-muted-foreground">
          <InfoRow label="Source" value={usage?.sourceLabel ?? "Unknown"} />
          <InfoRow label="Updated" value={usage ? new Date(usage.updatedAt).toLocaleString() : "Never"} />
          <InfoRow label="Mode" value="API / Local / Cache" />
        </CardContent>
      </Card>
    </div>
  );
}

function UsageMeter({ label, value, helper }: { label: string; value: number; helper: string }) {
  const percent = Math.max(0, Math.min(100, value));

  return (
    <div className="desktop-pane p-3">
      <div className="flex items-center justify-between">
        <div className="desktop-section-title">{label}</div>
        <div className="text-[13px] font-semibold">{percent}%</div>
      </div>
      <div className="mt-2 h-2 rounded-sm border border-border bg-panel">
        <div className="h-full rounded-[3px] bg-slate-700" style={{ width: `${percent}%` }} />
      </div>
      <div className="mt-2 truncate text-[11px] text-muted-foreground">{helper}</div>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-border pb-2 last:border-b-0 last:pb-0">
      <span>{label}</span>
      <span className="truncate text-foreground">{value}</span>
    </div>
  );
}
