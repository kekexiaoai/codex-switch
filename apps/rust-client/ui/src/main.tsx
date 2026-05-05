import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

function revealMainWindowWhenReady() {
  if (!("__TAURI_INTERNALS__" in window) || window.location.search.includes("panel=tray")) {
    return;
  }

  window.requestAnimationFrame(() => {
    import("@tauri-apps/api/window")
      .then(async ({ getCurrentWindow }) => {
        const appWindow = getCurrentWindow();
        await appWindow.show();
        await appWindow.unminimize();
        await appWindow.setFocus();
      })
      .catch(() => {
        // 前端只负责避免首屏白屏，显示失败时后端 page-load 钩子会兜底。
      });
  });
}

revealMainWindowWhenReady();
