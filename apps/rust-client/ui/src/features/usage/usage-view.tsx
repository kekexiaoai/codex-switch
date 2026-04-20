import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { UsageSnapshot } from "@/lib/tauri";

export function UsageView({ usage }: { usage?: UsageSnapshot | null }) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_320px] gap-4">
      <Card>
        <CardHeader>
          <div>
            <CardTitle>Usage Snapshot</CardTitle>
            <CardDescription>来源优先级：API → Local Logs → Cache。</CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {usage ? (
            <div className="grid grid-cols-2 gap-4">
              <UsagePanel label="5 小时" value={`${usage.fiveHour.percentUsed}%`} helper={new Date(usage.fiveHour.resetsAt).toLocaleString()} />
              <UsagePanel label="Weekly" value={`${usage.weekly.percentUsed}%`} helper={new Date(usage.weekly.resetsAt).toLocaleString()} />
            </div>
          ) : (
            <div className="rounded-xl border border-dashed border-border bg-panelAlt p-5 text-sm text-muted-foreground">
              当前没有可展示的 Usage 数据。请先导入账号并刷新。
            </div>
          )}
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <div>
            <CardTitle>说明</CardTitle>
            <CardDescription>这里不做炫技 dashboard，只强调数据来源和可读性。</CardDescription>
          </div>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <div>当前数据源：{usage?.sourceLabel ?? "未刷新"}</div>
          <div>更新时间：{usage ? new Date(usage.updatedAt).toLocaleString() : "未刷新"}</div>
          <div>主窗口优先承载完整信息，托盘只显示摘要。</div>
        </CardContent>
      </Card>
    </div>
  );
}

function UsagePanel({ label, value, helper }: { label: string; value: string; helper: string }) {
  return (
    <div className="rounded-xl border border-border bg-panelAlt p-5">
      <div className="text-xs uppercase tracking-[0.14em] text-muted-foreground">{label}</div>
      <div className="mt-3 text-4xl font-semibold">{value}</div>
      <div className="mt-2 text-sm text-muted-foreground">{helper}</div>
    </div>
  );
}
