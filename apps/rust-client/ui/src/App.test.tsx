import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/tauri", () => ({
  getAppSnapshot: vi.fn().mockResolvedValue({
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
  }),
  importCurrentAccount: vi.fn(),
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
  },
  onEvent: vi.fn().mockResolvedValue(() => {}),
}));

import { App } from "./App";

describe("App", () => {
  it("renders desktop sidebar instead of web navbar", async () => {
    render(<App />);
    expect(await screen.findByText("Desktop Runtime")).toBeInTheDocument();
    expect(screen.getAllByText("Accounts").length).toBeGreaterThan(0);
    expect(screen.queryByText("Welcome")).not.toBeInTheDocument();
  });
});
