use crate::error::{AppError, AppResult};
use crate::models::{masked_email, AccountTier, JwtClaims};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use serde::Deserialize;

#[derive(Debug, Default, Clone)]
pub struct JwtDecoder;

impl JwtDecoder {
    pub fn decode(&self, id_token: &str) -> AppResult<JwtClaims> {
        let mut parts = id_token.split('.');
        let _header = parts.next();
        let payload = parts.next().ok_or(AppError::JwtPayloadInvalid)?;
        let data = URL_SAFE_NO_PAD
            .decode(payload)
            .or_else(|_| {
                let padding = "=".repeat((4 - payload.len() % 4) % 4);
                URL_SAFE_NO_PAD.decode(format!("{payload}{padding}"))
            })
            .map_err(|_| AppError::JwtPayloadInvalid)?;
        let payload: Payload =
            serde_json::from_slice(&data).map_err(|_| AppError::JwtPayloadInvalid)?;
        let email = payload.email.trim().to_lowercase();
        let account_id = payload
            .sub
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
            .unwrap_or_else(|| email.clone());
        Ok(JwtClaims {
            account_id,
            email: email.clone(),
            email_mask: masked_email(&email),
            tier: resolve_tier(
                payload.tier,
                payload.plan,
                payload.openai_auth.and_then(|auth| auth.chatgpt_plan_type),
            ),
        })
    }
}

fn resolve_tier(
    tier: Option<String>,
    plan: Option<String>,
    auth_plan: Option<String>,
) -> AccountTier {
    let value = tier
        .or(plan)
        .or(auth_plan)
        .unwrap_or_else(|| "unknown".into())
        .trim()
        .to_lowercase();
    if value.contains("team") {
        return AccountTier::Team;
    }
    if value.contains("pro") {
        return AccountTier::Pro;
    }
    if value.contains("plus") {
        return AccountTier::Plus;
    }
    AccountTier::Unknown
}

#[derive(Debug, Deserialize)]
struct Payload {
    sub: Option<String>,
    email: String,
    tier: Option<String>,
    plan: Option<String>,
    #[serde(rename = "https://api.openai.com/auth")]
    openai_auth: Option<OpenAiAuthPayload>,
}

#[derive(Debug, Deserialize)]
struct OpenAiAuthPayload {
    #[serde(rename = "chatgpt_plan_type")]
    chatgpt_plan_type: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::JwtDecoder;

    #[test]
    fn decodes_jwt_claims_and_tier() {
        let token = "header.eyJlbWFpbCI6ImFsaWNlQGV4YW1wbGUuY29tIiwic3ViIjoiYWNjdC0xIiwicGxhbiI6InRlYW0ifQ.sig";
        let claims = JwtDecoder.decode(token).unwrap();
        assert_eq!(claims.account_id, "acct-1");
        assert_eq!(claims.email, "alice@example.com");
        assert_eq!(claims.email_mask, "a••••@example.com");
    }
}
