import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
    <div className="grid h-full grid-cols-[minmax(0,1fr)_320px] gap-4">
      <Card>
        <CardHeader>
          <div>
            <CardTitle>偏好设置</CardTitle>
            <CardDescription>这些设置会写到应用配置目录，不会污染 `.codex` 运行时数据。</CardDescription>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <SettingRow
            title="启用 Usage 刷新"
            description="关闭后只显示缓存和静态状态。"
            checked={settings.usageRefreshEnabled}
            onCheckedChange={(checked) => onChange({ ...settings, usageRefreshEnabled: checked })}
          />
          <SettingRow
            title="显示完整邮箱"
            description="默认仍使用掩码邮箱。"
            checked={settings.showFullEmail}
            onCheckedChange={(checked) => onChange({ ...settings, showFullEmail: checked })}
          />
          <SettingRow
            title="开机启动"
            description="当前先保留偏好设置位，后续接入实际 autostart。"
            checked={settings.launchAtLogin}
            onCheckedChange={(checked) => onChange({ ...settings, launchAtLogin: checked })}
          />
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <div>
            <CardTitle>说明</CardTitle>
            <CardDescription>去 Web 化的设置页应该像系统偏好，不像网站账户页。</CardDescription>
          </div>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <div>分组明确</div>
          <div>控件紧凑</div>
          <div>没有大卡片式仪表盘装饰</div>
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
    <div className="flex items-start justify-between rounded-xl border border-border bg-panelAlt px-4 py-3">
      <div>
        <div className="font-medium">{title}</div>
        <div className="mt-1 text-sm text-muted-foreground">{description}</div>
      </div>
      <Switch checked={checked} onCheckedChange={onCheckedChange} />
    </div>
  );
}
