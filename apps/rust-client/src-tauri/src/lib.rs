mod accounts;
mod commands;
mod diagnostics;
mod error;
mod jwt;
mod login;
mod models;
mod paths;
mod provider_sync;
mod settings;
mod state;
mod store;
mod usage;

use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, WebviewUrl, WebviewWindowBuilder,
};

pub use state::AppState;

pub fn run() {
    tauri::Builder::default()
        .manage(AppState::new())
        .invoke_handler(tauri::generate_handler![
            commands::app_show_main_window,
            commands::app_snapshot,
            commands::accounts_list,
            commands::accounts_import_current,
            commands::accounts_import_backup,
            commands::accounts_switch,
            commands::accounts_login_start,
            commands::usage_refresh,
            commands::provider_sync_status,
            commands::provider_sync_run,
            commands::provider_switch,
            commands::settings_get,
            commands::settings_update,
            commands::diagnostics_recent
        ])
        .setup(|app| {
            create_tray_panel_window(app)?;
            let open_main = MenuItem::with_id(app, "open-main", "打开主窗口", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&open_main, &quit])?;
            TrayIconBuilder::with_id("codex-switch-tray")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "open-main" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.unminimize();
                            let _ = window.set_focus();
                        }
                    }
                    "quit" => {
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("tray-panel") {
                            let visible = window.is_visible().unwrap_or(false);
                            if visible {
                                let _ = window.hide();
                            } else {
                                let _ = window.center();
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                })
                .build(app)?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running codex switch tauri app");
}

fn create_tray_panel_window(app: &mut tauri::App) -> tauri::Result<()> {
    if app.get_webview_window("tray-panel").is_none() {
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
        .build()?;
    }
    Ok(())
}
