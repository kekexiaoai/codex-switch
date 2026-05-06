mod accounts;
mod commands;
mod diagnostics;
mod error;
mod jwt;
mod login;
mod models;
mod paths;
mod provider_sync;
mod sessions;
mod settings;
mod state;
mod store;
mod usage;

use std::time::Duration;
#[cfg(target_os = "macos")]
use tauri::TitleBarStyle;
use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, WebviewUrl, WebviewWindowBuilder,
};
#[cfg(desktop)]
use tauri_plugin_autostart::Builder as AutostartBuilder;
#[cfg(target_os = "macos")]
use tauri_plugin_autostart::MacosLauncher;

pub use state::AppState;

#[cfg(target_os = "macos")]
const TRAY_ICON: tauri::image::Image<'_> = tauri::include_image!(
    "../../../apps/mac-client/CodexSwitch/Resources/StatusBarIconLightHighContrastBold.png"
);
#[cfg(not(target_os = "macos"))]
const TRAY_ICON: tauri::image::Image<'_> =
    tauri::include_image!("../../../packaging/icons/AppIcon.iconset/icon_32x32.png");

pub fn run() {
    tauri::Builder::default()
        .manage(AppState::new())
        .invoke_handler(tauri::generate_handler![
            commands::app_show_main_window,
            commands::app_open_view,
            commands::app_quit,
            commands::app_snapshot,
            commands::accounts_list,
            commands::accounts_import_current,
            commands::accounts_import_backup,
            commands::accounts_import_backups,
            commands::accounts_switch,
            commands::accounts_remove,
            commands::accounts_login_start,
            commands::accounts_login_cancel,
            commands::usage_refresh,
            commands::provider_sync_status,
            commands::provider_sync_run,
            commands::provider_switch,
            commands::provider_sync_backups,
            commands::provider_sync_restore,
            commands::provider_sync_prune,
            commands::sessions_list,
            commands::sessions_projects,
            commands::sessions_get,
            commands::settings_get,
            commands::settings_update,
            commands::diagnostics_recent
        ])
        .on_page_load(|webview, payload| {
            if webview.label() == "main"
                && matches!(payload.event(), tauri::webview::PageLoadEvent::Finished)
            {
                show_main_window(webview.app_handle());
            }
        })
        .setup(|app| {
            #[cfg(desktop)]
            app.handle().plugin(autostart_plugin())?;
            app.handle().plugin(tauri_plugin_dialog::init())?;
            let open_main =
                MenuItem::with_id(app, "open-main", "打开 Codex Switch", true, None::<&str>)?;
            let open_settings =
                MenuItem::with_id(app, "open-settings", "设置…", true, None::<&str>)?;
            let refresh_usage =
                MenuItem::with_id(app, "refresh-usage", "刷新 Usage", true, None::<&str>)?;
            let open_panel =
                MenuItem::with_id(app, "open-tray-panel", "打开快速面板", true, None::<&str>)?;
            let separator = PredefinedMenuItem::separator(app)?;
            let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let menu = Menu::with_items(
                app,
                &[
                    &open_main,
                    &open_settings,
                    &refresh_usage,
                    &open_panel,
                    &separator,
                    &quit,
                ],
            )?;
            let tray = TrayIconBuilder::with_id("codex-switch-tray")
                .menu(&menu)
                .tooltip("Codex Switch")
                .show_menu_on_left_click(true)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "open-main" => {
                        show_main_window(app);
                    }
                    "open-settings" => {
                        show_main_view(app, "settings");
                    }
                    "refresh-usage" => {
                        refresh_usage_from_menu(app);
                    }
                    "open-tray-panel" => {
                        toggle_tray_panel(app);
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::DoubleClick {
                        button: MouseButton::Left,
                        ..
                    } = event
                    {
                        show_main_window(tray.app_handle());
                    }
                });
            #[cfg(target_os = "macos")]
            let tray = tray.icon(TRAY_ICON).icon_as_template(true);
            #[cfg(not(target_os = "macos"))]
            let tray = tray.icon(TRAY_ICON);
            tray.build(app)?;
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building codex switch tauri app")
        .run(|app, event| {
            if let tauri::RunEvent::Ready = event {
                let app = app.clone();
                tauri::async_runtime::spawn(async move {
                    tokio::time::sleep(Duration::from_millis(500)).await;
                    show_main_window(&app);
                });
            }

            if let tauri::RunEvent::WindowEvent {
                label,
                event: tauri::WindowEvent::CloseRequested { api, .. },
                ..
            } = &event
            {
                if label == "main" {
                    api.prevent_close();
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.hide();
                    }
                }
            }

            #[cfg(target_os = "macos")]
            if let tauri::RunEvent::Reopen { .. } = event {
                show_main_window(app);
            }
        });
}

#[cfg(desktop)]
fn autostart_plugin<R: tauri::Runtime>() -> tauri::plugin::TauriPlugin<R> {
    let builder = AutostartBuilder::new().app_name("Codex Switch");
    #[cfg(target_os = "macos")]
    let builder = builder.macos_launcher(MacosLauncher::LaunchAgent);
    builder.build()
}

fn show_main_window(app: &AppHandle) {
    if let Ok(window) = main_window(app) {
        #[cfg(target_os = "macos")]
        let _ = app.show();
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

fn main_window(app: &AppHandle) -> tauri::Result<tauri::WebviewWindow> {
    if let Some(window) = app.get_webview_window("main") {
        return Ok(window);
    }

    let builder = WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
        .title("Codex Switch")
        .inner_size(1240.0, 840.0)
        .min_inner_size(1080.0, 720.0)
        .center()
        .resizable(true);

    #[cfg(target_os = "macos")]
    let builder = builder
        .title_bar_style(TitleBarStyle::Transparent)
        .hidden_title(true);

    builder.build()
}

fn show_main_view(app: &AppHandle, view: &str) {
    show_main_window(app);
    let _ = app.emit("shell://navigate", view);
}

fn toggle_tray_panel(app: &AppHandle) {
    let Ok(window) = tray_panel_window(app) else {
        return;
    };
    let visible = window.is_visible().unwrap_or(false);
    if visible {
        let _ = window.hide();
    } else {
        let _ = window.center();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

fn refresh_usage_from_menu(app: &AppHandle) {
    let app_handle = app.clone();
    let state = app.state::<AppState>().inner().clone();
    tauri::async_runtime::spawn(async move {
        if let Ok(settings) = state.settings.load() {
            if let Ok(snapshot) = state.usage.refresh_active_usage(&settings).await {
                let _ = app_handle.emit(state::EVENT_USAGE_UPDATED, &snapshot);
            }
        }
    });
}

fn tray_panel_window(app: &AppHandle) -> tauri::Result<tauri::WebviewWindow> {
    if let Some(window) = app.get_webview_window("tray-panel") {
        return Ok(window);
    }

    WebviewWindowBuilder::new(
        app,
        "tray-panel",
        WebviewUrl::App("index.html?panel=tray".into()),
    )
    .title("Codex Switch Tray")
    .inner_size(420.0, 620.0)
    .decorations(false)
    .always_on_top(true)
    .visible(false)
    .skip_taskbar(true)
    .resizable(false)
    .build()
}
