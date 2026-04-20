use crate::accounts::AccountsService;
use crate::error::AppResult;
use crate::models::LoginJobState;
use crate::paths::CodexPaths;
use chrono::Utc;
use std::fs;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use tauri::Emitter;

pub const LOGIN_EVENT: &str = "jobs://state-changed";

#[derive(Debug, Clone)]
pub struct LoginService {
    pub paths: CodexPaths,
    pub state: Arc<Mutex<LoginJobState>>,
}

impl LoginService {
    pub fn new(paths: CodexPaths) -> Self {
        Self {
            paths,
            state: Arc::new(Mutex::new(LoginJobState {
                active: false,
                message: "idle".into(),
            })),
        }
    }

    pub fn state(&self) -> LoginJobState {
        self.state.lock().unwrap().clone()
    }

    pub fn start(&self, app: tauri::AppHandle) -> AppResult<LoginJobState> {
        let auth_path = self.paths.auth_file();
        let before = fs::metadata(&auth_path)
            .and_then(|meta| meta.modified())
            .unwrap_or(SystemTime::UNIX_EPOCH);
        {
            let mut state = self.state.lock().unwrap();
            state.active = true;
            state.message = "浏览器登录已启动，请在浏览器完成认证".into();
        }
        let state = self.state.clone();
        let paths = self.paths.clone();
        tauri::async_runtime::spawn(async move {
            let _ = open::that("https://chatgpt.com/auth/login");
            for _ in 0..180 {
                tokio::time::sleep(Duration::from_secs(1)).await;
                let current = fs::metadata(paths.auth_file())
                    .and_then(|meta| meta.modified())
                    .unwrap_or(SystemTime::UNIX_EPOCH);
                if current > before {
                    let imported = AccountsService::new(paths.clone()).import_current();
                    let mut guard = state.lock().unwrap();
                    guard.active = false;
                    guard.message = if imported.is_ok() {
                        format!("登录完成 {}", Utc::now())
                    } else {
                        "检测到 auth 更新，但导入失败".into()
                    };
                    let _ = app.emit(LOGIN_EVENT, guard.clone());
                    return;
                }
            }
            let mut guard = state.lock().unwrap();
            guard.active = false;
            guard.message = "浏览器登录超时，请稍后重试".into();
            let _ = app.emit(LOGIN_EVENT, guard.clone());
        });
        Ok(self.state())
    }
}
