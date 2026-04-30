import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import type { SettingsDto } from "@/lib/tauri";

export function SettingsView({
  settings,
  onChange,
}: {
  settings: SettingsDto;
  onChange: (settings: SettingsDto) => void;
}) {
  return (
    <div className="grid h-full grid-cols-[minmax(0,1fr)_280px] gap-3">
      <Card>
        <CardHeader className="h-11">
          <CardTitle>偏好设置</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="desktop-pane p-3">
            <div className="flex items-center justify-between gap-4">
              <div>
                <div className="text-[13px] font-medium">Usage Source</div>
                <div className="mt-0.5 text-[11px] text-muted-foreground">Automatic / Local Only</div>
              </div>
              <div className="flex rounded-md border border-border bg-panel p-0.5">
                <Button
                  size="sm"
                  variant={settings.usageSourceMode === "automatic" ? "default" : "ghost"}
                  onClick={() => onChange({ ...settings, usageSourceMode: "automatic" })}
                >
                  Auto
                </Button>
                <Button
                  size="sm"
                  variant={settings.usageSourceMode === "localOnly" ? "default" : "ghost"}
                  onClick={() => onChange({ ...settings, usageSourceMode: "localOnly" })}
                >
                  Local
                </Button>
              </div>
            </div>
          </div>
          <SettingRow
            title="启用 Usage 刷新"
            description="允许刷新远端或本地 usage 快照"
            checked={settings.usageRefreshEnabled}
            onCheckedChange={(checked) => onChange({ ...settings, usageRefreshEnabled: checked })}
          />
          <SettingRow
            title="显示完整邮箱"
            description="账号列表和托盘使用完整邮箱"
            checked={settings.showFullEmail}
            onCheckedChange={(checked) => onChange({ ...settings, showFullEmail: checked })}
          />
          <SettingRow
            title="开机启动"
            description="随系统登录启动 Codex Switch"
            checked={settings.launchAtLogin}
            onCheckedChange={(checked) => onChange({ ...settings, launchAtLogin: checked })}
          />
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="h-11">
          <CardTitle>存储</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-[12px] text-muted-foreground">
          <InfoRow label="Codex data" value="~/.codex" />
          <InfoRow label="Settings" value="App config" />
          <InfoRow label="Runtime" value="Tauri" />
        </CardContent>
      </Card>
    </div>
  );
}

function SettingRow({
  title,
  description,
  checked,
  onCheckedChange,
}: {
  title: string;
  description: string;
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
}) {
  return (
    <div className="desktop-pane flex items-center justify-between gap-4 px-3 py-2.5">
      <div>
        <div className="text-[13px] font-medium">{title}</div>
        <div className="mt-0.5 text-[11px] text-muted-foreground">{description}</div>
      </div>
      <Switch checked={checked} onCheckedChange={onCheckedChange} />
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 border-b border-border pb-2 last:border-b-0 last:pb-0">
      <span>{label}</span>
      <span className="text-foreground">{value}</span>
    </div>
  );
}
