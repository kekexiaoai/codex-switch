use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("当前 auth.json 不存在")]
    CurrentAuthMissing,
    #[error("auth 文件不可读取")]
    AuthUnreadable,
    #[error("auth JSON 非法")]
    AuthJsonInvalid,
    #[error("检测到 API Key 模式，无法作为 ChatGPT 账号导入")]
    ApiKeyModeDetected,
    #[error("id_token 缺失")]
    IdTokenMissing,
    #[error("JWT 载荷非法")]
    JwtPayloadInvalid,
    #[error("归档写入失败")]
    ArchiveWriteFailed,
    #[error("活跃账号替换失败")]
    ActiveAuthReplacementFailed,
    #[error("没有可用的 Usage 数据")]
    NoUsageData,
    #[error("设置写入失败")]
    SettingsWriteFailed,
    #[error("Provider Sync 失败: {0}")]
    ProviderSync(String),
    #[error("桌面登录启动失败: {0}")]
    Login(String),
    #[error("资源不存在: {0}")]
    NotFound(String),
    #[error("{0}")]
    Message(String),
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error(transparent)]
    Json(#[from] serde_json::Error),
    #[error(transparent)]
    Chrono(#[from] chrono::ParseError),
    #[error(transparent)]
    Sqlite(#[from] rusqlite::Error),
    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
}

pub type AppResult<T> = Result<T, AppError>;
