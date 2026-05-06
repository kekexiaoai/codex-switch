use crate::accounts::AccountsService;
use crate::error::{AppError, AppResult};
use crate::models::LoginJobState;
use crate::paths::CodexPaths;
use crate::store::AuthStore;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use chrono::{DateTime, SecondsFormat, Utc};
use reqwest::Url;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;
use tauri::Emitter;

pub const LOGIN_EVENT: &str = "jobs://state-changed";

const OAUTH_CLIENT_ID: &str = "app_EMoamEEZ73f0CkXaXp7hrann";
const OAUTH_ORIGINATOR: &str = "codex_chatgpt_desktop";
const OAUTH_SCOPES: &str = "openid profile email offline_access";
const DEFAULT_CALLBACK_PORT: u16 = 1455;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OAuthCallbackResult {
    Code {
        code: String,
        state: String,
    },
    Failure {
        error: String,
        description: Option<String>,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthTokenResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub id_token: String,
    pub account_id: Option<String>,
}

struct DesktopLoginAttempt {
    server: LocalOAuthCallbackServer,
    state: String,
    code_verifier: String,
}

#[derive(Debug, Clone)]
pub struct DesktopLoginBroker {
    client: reqwest::Client,
}

impl DesktopLoginBroker {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::new(),
        }
    }

    pub fn build_authorization_url(
        &self,
        redirect_uri: &str,
        state: &str,
        code_verifier: &str,
    ) -> String {
        let code_challenge = code_challenge(code_verifier);
        Url::parse_with_params(
            "https://auth.openai.com/oauth/authorize",
            &[
                ("response_type", "code"),
                ("client_id", OAUTH_CLIENT_ID),
                ("redirect_uri", redirect_uri),
                ("scope", OAUTH_SCOPES),
                ("code_challenge", code_challenge.as_str()),
                ("code_challenge_method", "S256"),
                ("state", state),
                ("originator", OAUTH_ORIGINATOR),
                ("id_token_add_organizations", "true"),
                ("codex_cli_simplified_flow", "true"),
                ("allowed_workspace_id", ""),
            ],
        )
        .expect("authorization url should be valid")
        .to_string()
    }

    pub fn build_auth_data(
        &self,
        token: OAuthTokenResponse,
        now: DateTime<Utc>,
    ) -> AppResult<Vec<u8>> {
        let mut tokens = serde_json::Map::new();
        tokens.insert(
            "access_token".into(),
            serde_json::Value::String(token.access_token),
        );
        tokens.insert(
            "refresh_token".into(),
            serde_json::Value::String(token.refresh_token),
        );
        tokens.insert("id_token".into(), serde_json::Value::String(token.id_token));
        if let Some(account_id) = token.account_id {
            tokens.insert("account_id".into(), serde_json::Value::String(account_id));
        }

        let value = serde_json::json!({
            "OPENAI_API_KEY": "",
            "auth_mode": "chatgpt",
            "last_refresh": now.to_rfc3339_opts(SecondsFormat::Millis, true),
            "tokens": tokens,
        });
        Ok(serde_json::to_vec_pretty(&value)?)
    }

    fn begin_login(&self) -> AppResult<DesktopLoginAttempt> {
        let server = LocalOAuthCallbackServer::new(None)?;
        let state = random_url_safe_string(32);
        let code_verifier = random_url_safe_string(64);
        let url = self.build_authorization_url(server.redirect_uri(), &state, &code_verifier);
        if let Err(error) = open::that(url) {
            server.stop();
            return Err(AppError::Login(format!("无法打开浏览器: {error}")));
        }

        Ok(DesktopLoginAttempt {
            server,
            state,
            code_verifier,
        })
    }

    async fn complete_login(&self, attempt: DesktopLoginAttempt) -> AppResult<Vec<u8>> {
        let result =
            tokio::time::timeout(Duration::from_secs(180), attempt.server.wait_for_callback())
                .await
                .map_err(|_| AppError::Login("浏览器登录超时，请稍后重试".into()))??;
        attempt.server.stop();

        match result {
            OAuthCallbackResult::Code {
                code,
                state: returned_state,
            } => {
                if returned_state != attempt.state {
                    return Err(AppError::Login("登录状态校验失败，请重试".into()));
                }
                let token = self
                    .exchange_code_for_tokens(
                        &code,
                        &attempt.code_verifier,
                        attempt.server.redirect_uri(),
                    )
                    .await?;
                self.build_auth_data(token, Utc::now())
            }
            OAuthCallbackResult::Failure { error, .. } if error == "access_denied" => {
                Err(AppError::Login("浏览器登录已取消".into()))
            }
            OAuthCallbackResult::Failure { error, description } => Err(AppError::Login(
                description.unwrap_or_else(|| format!("浏览器登录失败: {error}")),
            )),
        }
    }

    async fn exchange_code_for_tokens(
        &self,
        code: &str,
        code_verifier: &str,
        redirect_uri: &str,
    ) -> AppResult<OAuthTokenResponse> {
        let response = self
            .client
            .post("https://auth.openai.com/oauth/token")
            .form(&[
                ("grant_type", "authorization_code"),
                ("code", code),
                ("redirect_uri", redirect_uri),
                ("code_verifier", code_verifier),
                ("client_id", OAUTH_CLIENT_ID),
            ])
            .send()
            .await?
            .error_for_status()
            .map_err(|error| AppError::Login(format!("令牌交换失败: {error}")))?;

        let payload: TokenExchangePayload = response
            .json()
            .await
            .map_err(|error| AppError::Login(format!("令牌响应解析失败: {error}")))?;

        Ok(OAuthTokenResponse {
            access_token: payload.access_token,
            refresh_token: payload.refresh_token,
            id_token: payload.id_token,
            account_id: payload.account_id,
        })
    }
}

#[derive(Debug, Clone)]
pub struct LocalOAuthCallbackServer {
    redirect_uri: String,
    inner: Arc<LocalServerInner>,
}

#[derive(Debug)]
struct LocalServerInner {
    result_tx: Arc<Mutex<Option<tokio::sync::oneshot::Sender<AppResult<OAuthCallbackResult>>>>>,
    result_rx: Mutex<Option<tokio::sync::oneshot::Receiver<AppResult<OAuthCallbackResult>>>>,
    stop_tx: Mutex<Option<Sender<()>>>,
    handle: Mutex<Option<JoinHandle<()>>>,
}

impl LocalOAuthCallbackServer {
    pub fn new(port: Option<u16>) -> AppResult<Self> {
        let listener = TcpListener::bind(("127.0.0.1", port.unwrap_or(DEFAULT_CALLBACK_PORT)))?;
        listener.set_nonblocking(true)?;
        let actual_port = listener.local_addr()?.port();
        let redirect_uri = format!("http://localhost:{actual_port}/auth/callback");
        let (result_tx, result_rx) = tokio::sync::oneshot::channel();
        let (stop_tx, stop_rx) = mpsc::channel();
        let result_tx = Arc::new(Mutex::new(Some(result_tx)));
        let thread_result_tx = Arc::clone(&result_tx);

        let handle =
            thread::spawn(move || run_callback_server(listener, stop_rx, thread_result_tx));

        Ok(Self {
            redirect_uri,
            inner: Arc::new(LocalServerInner {
                result_tx,
                result_rx: Mutex::new(Some(result_rx)),
                stop_tx: Mutex::new(Some(stop_tx)),
                handle: Mutex::new(Some(handle)),
            }),
        })
    }

    pub fn redirect_uri(&self) -> &str {
        &self.redirect_uri
    }

    pub async fn wait_for_callback(&self) -> AppResult<OAuthCallbackResult> {
        let receiver = self
            .inner
            .result_rx
            .lock()
            .unwrap()
            .take()
            .ok_or_else(|| AppError::Login("回调监听已经被消费".into()))?;
        receiver
            .await
            .map_err(|_| AppError::Login("回调监听已结束".into()))?
    }

    pub fn stop(&self) {
        if let Some(stop_tx) = self.inner.stop_tx.lock().unwrap().take() {
            let _ = stop_tx.send(());
        }
        if let Some(tx) = self.inner.result_tx.lock().unwrap().take() {
            let _ = tx.send(Err(AppError::Login("回调监听已停止".into())));
        }
        if let Some(handle) = self.inner.handle.lock().unwrap().take() {
            let _ = handle.join();
        }
    }
}

#[derive(Debug, Clone)]
pub struct LoginService {
    pub paths: CodexPaths,
    pub state: Arc<Mutex<LoginJobState>>,
    broker: DesktopLoginBroker,
}

impl LoginService {
    pub fn new(paths: CodexPaths) -> Self {
        Self {
            paths,
            state: Arc::new(Mutex::new(LoginJobState {
                active: false,
                message: "idle".into(),
            })),
            broker: DesktopLoginBroker::new(),
        }
    }

    pub fn state(&self) -> LoginJobState {
        self.state.lock().unwrap().clone()
    }

    pub fn start(&self, app: tauri::AppHandle) -> AppResult<LoginJobState> {
        {
            let state = self.state.lock().unwrap();
            if state.active {
                return Err(AppError::Login(
                    "浏览器登录正在进行中，请先完成当前登录或等待超时后再试".into(),
                ));
            }
        }

        let attempt = self.broker.begin_login()?;
        {
            let mut state = self.state.lock().unwrap();
            state.active = true;
            state.message = "浏览器已打开，请在浏览器完成认证".into();
        }
        let _ = app.emit(LOGIN_EVENT, self.state());

        let state = self.state.clone();
        let paths = self.paths.clone();
        let broker = self.broker.clone();
        tauri::async_runtime::spawn(async move {
            let result = broker.complete_login(attempt).await;
            let mut guard = state.lock().unwrap();
            guard.active = false;
            guard.message = match result {
                Ok(data) => {
                    let store = AuthStore::new(paths.clone());
                    match store
                        .replace_active_auth(&data)
                        .and_then(|_| AccountsService::new(paths.clone()).import_current())
                    {
                        Ok(_) => {
                            let _ = app.emit("accounts://changed", true);
                            format!("登录完成 {}", Utc::now())
                        }
                        Err(error) => format!("登录成功，但账号导入失败: {error}"),
                    }
                }
                Err(error) => error.to_string(),
            };
            let _ = app.emit(LOGIN_EVENT, guard.clone());
        });

        Ok(self.state())
    }
}

fn run_callback_server(
    listener: TcpListener,
    stop_rx: Receiver<()>,
    result_tx: Arc<Mutex<Option<tokio::sync::oneshot::Sender<AppResult<OAuthCallbackResult>>>>>,
) {
    loop {
        match stop_rx.try_recv() {
            Ok(_) | Err(TryRecvError::Disconnected) => break,
            Err(TryRecvError::Empty) => {}
        }

        match listener.accept() {
            Ok((mut stream, _)) => {
                let parsed = handle_callback_connection(&mut stream);
                if let Some(result) = parsed {
                    if let Some(tx) = result_tx.lock().unwrap().take() {
                        let _ = tx.send(Ok(result));
                    }
                    break;
                }
            }
            Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(10));
            }
            Err(error) => {
                if let Some(tx) = result_tx.lock().unwrap().take() {
                    let _ = tx.send(Err(AppError::Login(format!("回调监听失败: {error}"))));
                }
                break;
            }
        }
    }
}

fn handle_callback_connection(stream: &mut TcpStream) -> Option<OAuthCallbackResult> {
    let mut buffer = [0_u8; 16_384];
    let bytes_read = stream.read(&mut buffer).ok()?;
    if bytes_read == 0 {
        return None;
    }
    let request = String::from_utf8_lossy(&buffer[..bytes_read]);
    let request_line = request.lines().next()?;
    let mut parts = request_line.split_whitespace();
    let _method = parts.next()?;
    let target = parts.next()?;
    let url = Url::parse(&format!("http://localhost{target}")).ok()?;

    if url.path() != "/auth/callback" {
        let _ = write_http_response(stream, 404, "Not found");
        return None;
    }

    let params = url
        .query_pairs()
        .collect::<std::collections::HashMap<_, _>>();
    if let (Some(code), Some(state)) = (params.get("code"), params.get("state")) {
        let _ = write_http_response(
            stream,
            200,
            "Codex login complete. You can close this window and return to Codex Switch.",
        );
        return Some(OAuthCallbackResult::Code {
            code: code.to_string(),
            state: state.to_string(),
        });
    }

    if let Some(error) = params.get("error") {
        let _ = write_http_response(
            stream,
            200,
            "Codex login finished with an error. You can close this window.",
        );
        return Some(OAuthCallbackResult::Failure {
            error: error.to_string(),
            description: params
                .get("error_description")
                .map(|value| value.to_string()),
        });
    }

    let _ = write_http_response(stream, 400, "Invalid callback");
    None
}

fn write_http_response(stream: &mut TcpStream, status: u16, body: &str) -> std::io::Result<()> {
    let status_text = match status {
        200 => "OK",
        400 => "Bad Request",
        _ => "Not Found",
    };
    let response = format!(
        "HTTP/1.1 {status} {status_text}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    stream.write_all(response.as_bytes())
}

fn random_url_safe_string(length: usize) -> String {
    use rand::{distributions::Alphanumeric, Rng};
    rand::thread_rng()
        .sample_iter(Alphanumeric)
        .take(length)
        .map(char::from)
        .collect()
}

fn code_challenge(code_verifier: &str) -> String {
    let digest = Sha256::digest(code_verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
}

#[derive(Debug, Deserialize)]
struct TokenExchangePayload {
    access_token: String,
    refresh_token: String,
    id_token: String,
    account_id: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{TimeDelta, TimeZone, Utc};
    use reqwest::StatusCode;
    use serde_json::Value;

    #[test]
    fn builds_authorization_url_with_expected_desktop_query() {
        let broker = DesktopLoginBroker::new();
        let redirect_uri = "http://localhost:1455/auth/callback";
        let url =
            broker.build_authorization_url(redirect_uri, "expected-state", "expected-verifier");

        assert_eq!(
            url,
            "https://auth.openai.com/oauth/authorize?response_type=code&client_id=app_EMoamEEZ73f0CkXaXp7hrann&redirect_uri=http%3A%2F%2Flocalhost%3A1455%2Fauth%2Fcallback&scope=openid+profile+email+offline_access&code_challenge=a7vAnVI-b6qjdd18p8m2utvFMMIs0_T3n9RWc495DxQ&code_challenge_method=S256&state=expected-state&originator=codex_chatgpt_desktop&id_token_add_organizations=true&codex_cli_simplified_flow=true&allowed_workspace_id="
        );
    }

    #[test]
    fn builds_codex_compatible_auth_data() {
        let broker = DesktopLoginBroker::new();
        let data = broker
            .build_auth_data(
                OAuthTokenResponse {
                    access_token: "access-token".into(),
                    refresh_token: "refresh-token".into(),
                    id_token: "id-token".into(),
                    account_id: Some("account-123".into()),
                },
                Utc.with_ymd_and_hms(2025, 3, 28, 10, 31, 12).unwrap()
                    + TimeDelta::milliseconds(345),
            )
            .unwrap();
        let value: Value = serde_json::from_slice(&data).unwrap();

        assert_eq!(value["auth_mode"], "chatgpt");
        assert_eq!(value["tokens"]["account_id"], "account-123");
        assert_eq!(value["OPENAI_API_KEY"], "");
        assert_eq!(value["last_refresh"], "2025-03-28T10:31:12.345Z");
    }

    #[tokio::test]
    async fn callback_server_receives_authorization_code() {
        let server = LocalOAuthCallbackServer::new(Some(0)).unwrap();
        let callback_url = format!("{}?code=test-code&state=test-state", server.redirect_uri());

        let wait = tokio::spawn({
            let server = server.clone();
            async move { server.wait_for_callback().await }
        });

        let response = reqwest::get(callback_url).await.unwrap();
        let result = wait.await.unwrap().unwrap();
        server.stop();

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            result,
            OAuthCallbackResult::Code {
                code: "test-code".into(),
                state: "test-state".into(),
            }
        );
    }

    #[test]
    fn callback_server_defaults_to_registered_desktop_redirect_uri() {
        let server = LocalOAuthCallbackServer::new(None).unwrap();

        assert_eq!(server.redirect_uri(), "http://localhost:1455/auth/callback");

        server.stop();
    }
}
