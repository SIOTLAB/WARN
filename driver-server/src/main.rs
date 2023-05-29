mod schema;
mod models;
mod dbactions;
mod notif;

#[macro_use]
extern crate lazy_static;

#[macro_use]
extern crate diesel;
use diesel::{r2d2::{Pool, ConnectionManager, PooledConnection}, PgConnection};
use actix_web::{get, web, App, HttpResponse, HttpServer, Responder, http::header::{ContentType}, post, delete, put};

use models::MacAddress;
// use r2d2::{Pool};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::models::ApnsIdItem;

type DBPool = Pool<ConnectionManager<PgConnection>>;
type ActixError = actix_web::error::Error;

#[actix_web::main]
async fn main() -> std::io::Result<()>
{
    dotenvy::dotenv().ok();
    let _authkey_test = std::env::var("AUTHKEY").expect("Authkey must be set"); //Test authkey exists on start
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let manager = ConnectionManager::<PgConnection>::new(database_url);
    println!("Creating database pool...");
    let pool = Pool::builder()
        .test_on_check_out(true)
        .build(manager)
        .expect("Failed to create pool.");
    
    let mut args: Vec<String> = std::env::args().collect();
    if args.len() != 3
    {
        println!("Invalid arguments, starting localhost 8080");
        args = vec![String::from(&args[0]), String::from("localhost"), String::from("8080")];
    }

    println!("Starting clear unknown schedule");
    let schedule_pool = pool.clone();
    let _clear_schedule = std::thread::spawn(move ||
    {
        let mut schedule_time = std::time::Instant::now() + std::time::Duration::from_secs(60 * 60);
        loop
        {
            let dur = schedule_time - std::time::Instant::now();
            std::thread::sleep(dur);
            dbactions::clear_unknown_devices(&mut get_pool_connection(&schedule_pool));
            schedule_time += std::time::Duration::from_secs(60 * 60);            
        }
    });

    let kid = std::env::var("KID").expect("Set KID");
    let iss = std::env::var("ISS").expect("Set ISS");
    let _apns_service = std::thread::spawn(move ||
    {
        use notif::*;
        loop
        {
            refresh_token(&kid, &iss);
            std::thread::sleep(std::time::Duration::from_secs(30*60));
        }
    });

    println!("Starting server");
    HttpServer::new(move || {
        App::new()
            .service(home)
            .service(add_unknown_device)
            .service(get_unknown_devices)
            .service(get_device_info)
            .service(add_attack)
            .service(get_history_item)
            .service(get_device_status)
            .service(add_device)
            .service(delete_device)
            .service(create_user)
            .service(delete_user)
            .service(create_notif_rel)
            .app_data(web::Data::new(pool.clone()))
    })
    .bind((args[1].clone(), args[2].parse().expect("Port not valid")))
    .expect("Binding failed")
    .run()
    .await
}

#[get("/")]
async fn home() -> impl Responder
{
    HttpResponse::Ok().body("Hello world")
}

#[derive(Serialize, Deserialize)]
struct UnknownDevice { device_id: MacAddress, user_id: Uuid, device_name: Option<String>, device_vendor: Option<String> }
#[post("/unknown-device")]
async fn add_unknown_device(body: web::Json<UnknownDevice>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::add_unknown_device(&mut conn, body.device_id.clone(), body.user_id, body.device_name.clone(), body.device_vendor.clone())
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[derive(Serialize, Deserialize)]
struct UnknownDeviceReq { user_id: Uuid }
#[get("/unknown-device")]
async fn get_unknown_devices(body: web::Query<UnknownDeviceReq>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::get_unknown_devices(&mut conn, body.user_id)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[get("/info")]
async fn get_device_info(pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::get_device_info(&mut conn)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[derive(Serialize, Deserialize)]
struct GetHistoryRequest { user_id: uuid::Uuid, count: i64 }
#[get("/history")]
async fn get_history_item(query: web::Query<GetHistoryRequest>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::get_history_items(&mut conn, query.user_id, query.count)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)

}

#[derive(Serialize, Deserialize)]
struct UpdateDeviceRequest { device_id: MacAddress, user_id: Uuid, connection_status: models::ConnStatus,
    severity: Option<models::Severity>, attack_type: Option<models::AttackType>, no_notify: Option<bool> }
#[put("/device")]
async fn add_attack(query: web::Json<UpdateDeviceRequest>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let attack_type = query.attack_type;
    let s = query.severity;
    let ignore_notif = query.no_notify;
    let uid = query.user_id;
    let (query_result, pool) = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        (
            dbactions::update_device_status(&mut conn, query.user_id, &query.device_id, query.connection_status, query.severity),
            pool
        )
    })
    .await.map_err(actix_web::error::ErrorInternalServerError)?;
    let device = query_result.map_err(actix_web::error::ErrorBadRequest)?;

    if let Some(true) = ignore_notif
    {
        return to_json_body(&device);
    }
    match s
    {
        Some(severity) if severity != models::Severity::Ok =>
        {
            let mut historyitem = models::HistoryItem
            {
                user_id: device.user_id,
                history_id: Uuid::new_v4(),
                timestamp: time::OffsetDateTime::now_utc(),
                attack_type,
                severity: device.severity,
                device_address: device.device_id.clone()
            };
            let (_query_result, pool) = web::block(move ||
            {
                let mut conn = get_pool_connection(&pool);
                (dbactions::add_history_item(&mut conn, &mut historyitem), pool)
            })
            .await
            .map_err(actix_web::error::ErrorInternalServerError)?;
            _query_result.map_err(actix_web::error::ErrorBadRequest)?;
    
            //Send notification here
            println!("Notification to be sent for device {:?}", device);
            let apnsids = web::block(move ||
            {
                let mut conn = get_pool_connection(&pool);
                dbactions::get_all_notif_ids(&mut conn, uid)
            })
            .await
            .map_err(actix_web::error::ErrorInternalServerError)?
            .map_err(actix_web::error::ErrorBadRequest)?;
            for id in apnsids
            {
                notif::send_notification(&id.apns_id, &device.device_name).await;
            }
        },
        _ => {println!("Device updated without severity.")}
    }

    to_json_body(&device)

}

#[derive(Serialize, Deserialize)]
struct GetDeviceStatusRequest { user_id: Uuid }
#[get("/device")]
async fn get_device_status(query: web::Query<GetDeviceStatusRequest>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::get_device(&mut conn, query.user_id)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[post("/device")]
async fn add_device(body: web::Json<models::Device>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let new_device = body.into_inner();
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::add_device(&mut conn, new_device)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[derive(Serialize, Deserialize)]
struct DelDeviceReq { user_id: Uuid, device_id: MacAddress }
#[delete("/device")]
async fn delete_device(body: web::Json<DelDeviceReq>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::delete_device(&mut conn, body.user_id, &body.device_id)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[derive(Serialize, Deserialize)]
struct NewUserRequest { local_server_id: Uuid }
#[post("/user")]
async fn create_user(body: web::Json<NewUserRequest>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let new_user = models::User { user_id: Uuid::new_v4(), account_id: body.into_inner().local_server_id };
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::add_user(&mut conn, new_user)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[post("/apns")]
async fn create_notif_rel(body: web::Json<ApnsIdItem>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::add_apns_registration(&mut conn, body.apns_id.clone(), body.user_id)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

#[derive(Serialize, Deserialize)]
struct RemoveUserRequest { user_id: Uuid }
#[delete("/user")]
async fn delete_user(body: web::Json<RemoveUserRequest>, pool: web::Data<DBPool>) -> Result<impl Responder, ActixError>
{
    let new_user = body.into_inner().user_id;
    let query_result = web::block(move ||
    {
        let mut conn = get_pool_connection(&pool);
        dbactions::delete_user(&mut conn, new_user)
    })
    .await
    .map_err(actix_web::error::ErrorInternalServerError)?
    .map_err(actix_web::error::ErrorBadRequest)?;

    to_json_body(&query_result)
}

fn get_pool_connection(pool: &DBPool) -> PooledConnection<ConnectionManager<PgConnection>>
{
    pool.get().expect("Connection retreival failed")
}

fn to_json_body<T>(data: &T) -> Result<impl Responder, ActixError>
    where T: ?Sized + Serialize
{
    let json_result = serde_json::to_string_pretty(&data);
    match json_result
    {
        Ok(json) => Ok(HttpResponse::Ok().content_type(ContentType::json()).body(json)),
        Err(output) => Ok(HttpResponse::NotFound().body(output.to_string()))
    }
}