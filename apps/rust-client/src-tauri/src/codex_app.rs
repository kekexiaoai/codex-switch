use crate::models::CodexRestartResult;
use std::process::Command;
use std::thread;
use std::time::Duration;

pub fn restart_codex_app() -> CodexRestartResult {
    match restart_platform_codex_app() {
        Ok(()) => CodexRestartResult {
            attempted: true,
            success: true,
            message: "Codex 已重启".into(),
        },
        Err(message) => CodexRestartResult {
            attempted: true,
            success: false,
            message,
        },
    }
}

#[cfg(target_os = "macos")]
fn restart_platform_codex_app() -> Result<(), String> {
    let _ = Command::new("osascript")
        .args(["-e", "tell application \"Codex\" to quit"])
        .status();
    thread::sleep(Duration::from_millis(900));

    let status = Command::new("open")
        .args(["-a", "Codex"])
        .status()
        .map_err(|error| format!("账号已切换，但无法启动 Codex: {error}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("账号已切换，但 Codex 启动命令失败: {status}"))
    }
}

#[cfg(target_os = "windows")]
fn restart_platform_codex_app() -> Result<(), String> {
    let _ = Command::new("taskkill")
        .args(["/IM", "Codex.exe", "/T", "/F"])
        .status();
    thread::sleep(Duration::from_millis(900));

    if let Some(path) = windows_codex_executable_path() {
        Command::new(&path)
            .spawn()
            .map_err(|error| format!("账号已切换，但无法启动 Codex: {error}"))?;
        return Ok(());
    }

    let status = Command::new("cmd")
        .args(["/C", "start", "\"\"", "Codex.exe"])
        .status()
        .map_err(|error| format!("账号已切换，但无法启动 Codex: {error}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("账号已切换，但未找到 Codex.exe: {status}"))
    }
}

#[cfg(target_os = "windows")]
fn windows_codex_executable_path() -> Option<std::path::PathBuf> {
    let mut candidates = Vec::new();
    if let Ok(local_app_data) = std::env::var("LOCALAPPDATA") {
        let local = std::path::PathBuf::from(local_app_data);
        candidates.push(local.join("Programs").join("Codex").join("Codex.exe"));
        candidates.push(local.join("Codex").join("Codex.exe"));
    }
    if let Ok(program_files) = std::env::var("ProgramFiles") {
        candidates.push(
            std::path::PathBuf::from(program_files)
                .join("Codex")
                .join("Codex.exe"),
        );
    }

    candidates.into_iter().find(|path| path.exists())
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn restart_platform_codex_app() -> Result<(), String> {
    Err("账号已切换，但当前系统暂不支持自动重启 Codex".into())
}
