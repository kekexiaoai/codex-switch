import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AppSnapshot } from "@/lib/tauri";

const snapshot: AppSnapshot = {
  accounts: [],
  settings: {
    usageRefreshEnabled: true,
    usageSourceMode: "automatic",
    showFullEmail: false,
    launchAtLogin: false,
  },
  diagnostics: [],
  providerStatus: {
    currentProvider: "openai",
    configuredProviders: ["openai"],
    rolloutDistribution: [],
    sqliteDistribution: [],
    backupCount: 0,
    backupTotalSize: 0,
    backups: [],
  },
};

vi.mock("@/lib/tauri", () => ({
  getAppSnapshot: vi.fn(),
  accountsImportBackup: vi.fn(),
  importCurrentAccount: vi.fn(),
  pickAuthBackupFile: vi.fn(),
  getAutostartEnabled: vi.fn().mockResolvedValue(false),
  switchAccount: vi.fn(),
  refreshUsage: vi.fn(),
  runProviderSync: vi.fn(),
  switchProvider: vi.fn(),
  saveSettings: vi.fn(),
  setAutostartEnabled: vi.fn(),
  showMainWindow: vi.fn(),
  startBrowserLogin: vi.fn(),
  events: {
    accountsChanged: "accounts://changed",
    usageUpdated: "usage://updated",
    settingsChanged: "settings://changed",
    diagnosticsAppended: "diagnostics://appended",
    jobsChanged: "jobs://state-changed",
    shellNavigate: "shell://navigate",
  },
  onEvent: vi.fn().mockResolvedValue(() => {}),
}));

import { App } from "./App";
import { getAppSnapshot } from "@/lib/tauri";

describe("App", () => {
  beforeEach(() => {
    vi.mocked(getAppSnapshot).mockReset();
    vi.mocked(getAppSnapshot).mockResolvedValue(snapshot);
  });

  it("renders desktop sidebar instead of web navbar", async () => {
    render(<App />);
    expect(await screen.findByText("Codex Switch")).toBeInTheDocument();
    expect(screen.getByText("Menu Bar Utility")).toBeInTheDocument();
    expect(screen.getAllByText("Accounts").length).toBeGreaterThan(0);
    expect(screen.getByText("导入备份")).toBeInTheDocument();
    expect(screen.queryByText("Welcome")).not.toBeInTheDocument();
  });

  it("shows a startup error when the desktop snapshot cannot load", async () => {
    vi.mocked(getAppSnapshot).mockRejectedValueOnce(new Error("id_token 缺失"));

    render(<App />);

    expect(await screen.findByText("id_token 缺失")).toBeInTheDocument();
  });
});
