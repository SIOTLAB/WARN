use std::sync::{RwLock, Arc};
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
use serde::{Serialize, Deserialize};
use serde_json::Value;

#[derive(Serialize, Deserialize, Clone)]
struct TokenReq
{
    iss: String,
    iat: u64
}

#[derive(Serialize, Deserialize, Clone)]
struct Token
{
    token: String
}

lazy_static!{ static ref APNS_TOKEN:RwLock<(String, u64)> = RwLock::new((String::new(), 0)); }

pub fn refresh_token(kid: &str, iss: &str)
{
    let timestamp = jsonwebtoken::get_current_timestamp();
    let req = TokenReq { iss: iss.to_owned(), iat: timestamp };
    let mut header = Header::new(Algorithm::ES256);
    header.kid = Some(kid.to_owned());
    let authkey = std::env::var("AUTHKEY").expect("Authkey must be set");
    let token = encode(&header,
        &req,
        &EncodingKey::from_ec_pem(&std::fs::read(authkey).unwrap()).unwrap())
        .unwrap();

    let mut token_handle = APNS_TOKEN.write().unwrap();
    *token_handle = (token, timestamp);
}

pub async fn send_notification(apns_device_id: &str, device_name: &str)
{
    let mut body = serde_json::from_str::<serde_json::Value>(r#"
        {
            "aps" : {
                "alert" : {
                    "title" : "",
                    "subtitle" : "Tap to open"
                }
            }
        }    
    "#).unwrap();
    body["aps"]["alert"]["title"] = Value::from(format!("{device_name} is under attack"));

    let client = awc::Client::default();
    let token = APNS_TOKEN.read().unwrap().0.clone();
    let _response = client.post(format!("https://api.sandbox.push.apple.com:443/3/device/{}", apns_device_id))
    .append_header(("apns-topic","com.warn.userapp"))
        .bearer_auth(token)
        .send_json(&body)
        .await.unwrap();
}