use diesel::deserialize::{self, FromSql, FromSqlRow};
use diesel::expression::AsExpression;
use diesel::pg::Pg;
use diesel::serialize::{self, IsNull, Output, ToSql};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use std::io::Write;

use crate::schema::*;

pub type MacAddress = String;
// pub type MacAddressPrefix = String;


#[derive(Debug, AsExpression, FromSqlRow,  PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
#[diesel(sql_type = crate::schema::sql_types::Attacktype)]
pub enum AttackType
{
    Deauthentication,
    Krack
}

impl ToSql<crate::schema::sql_types::Attacktype, Pg> for AttackType
{
    fn to_sql<'b>(&'b self, out: &mut diesel::serialize::Output<'b, '_, Pg>) -> diesel::serialize::Result 
    {
        match *self
        {
            AttackType::Deauthentication => out.write_all(b"deauthentication")?,
            AttackType::Krack => out.write_all(b"krack")?
        }
        Ok(IsNull::No)
    }
}

impl FromSql<crate::schema::sql_types::Attacktype, Pg> for AttackType
{
    fn from_sql(bytes: diesel::backend::RawValue<'_, Pg>) -> deserialize::Result<Self>
    {
        match bytes.as_bytes()
        {
            b"deauthentication" => Ok(AttackType::Deauthentication),
            b"krack" => Ok(AttackType::Krack),
            _ => Err("Unrecognized enum variant".into())
        }
    }
}

#[derive(Debug, AsExpression, FromSqlRow, PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
#[diesel(sql_type = crate::schema::sql_types::Connstatus)]
pub enum ConnStatus
{
    Online,
    Offline,
    Unknown
}

impl ToSql<crate::schema::sql_types::Connstatus, Pg> for ConnStatus
{
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result 
    {
        match *self
        {
            ConnStatus::Online => out.write_all(b"online")?,
            ConnStatus::Offline => out.write_all(b"offline")?,
            ConnStatus::Unknown => out.write_all(b"unknown")?
        }
        Ok(IsNull::No)
    }
}

impl FromSql<crate::schema::sql_types::Connstatus, Pg> for ConnStatus
{
    fn from_sql(bytes: diesel::backend::RawValue<'_, Pg>) -> deserialize::Result<Self>
    {
        match bytes.as_bytes()
        {
            b"online" => Ok(ConnStatus::Online),
            b"offline" => Ok(ConnStatus::Offline),
            b"unknown" => Ok(ConnStatus::Unknown),
            _ => Err("Unrecognized enum variant".into())
        }    
    }
}

#[derive(Debug, AsExpression, FromSqlRow, PartialEq, Eq, Serialize, Deserialize, Clone, Copy)]
#[diesel(sql_type = crate::schema::sql_types::Severity)]
pub enum Severity
{
    Ok,
    Warning,
    Attack
}

impl ToSql<crate::schema::sql_types::Severity, Pg> for Severity
{
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result 
    {
        match *self
        {
            Severity::Ok => out.write_all(b"ok")?,
            Severity::Warning => out.write_all(b"warning")?,
            Severity::Attack => out.write_all(b"attack")?
        }
        Ok(IsNull::No)
    }
}

impl FromSql<crate::schema::sql_types::Severity, Pg> for Severity
{
    fn from_sql(bytes: diesel::backend::RawValue<'_, Pg>) -> deserialize::Result<Self>
    {
        match bytes.as_bytes()
        {
            b"ok" => Ok(Severity::Ok),
            b"warning" => Ok(Severity::Warning),
            b"attack" => Ok(Severity::Attack),
            _ => Err("Unrecognized enum variant".into())
        }    
    }
}


#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(account_id))]
pub struct Account
{
    pub account_id: Uuid
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(user_id))]
pub struct User
{
    pub user_id: Uuid,
    pub account_id: Uuid
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(apns_id), table_name = apnsid)]
pub struct ApnsIdItem
{
    pub apns_id: String,
    pub user_id: Uuid
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(device_id))]
pub struct Device
{
    pub device_id: MacAddress,
    pub device_name: String,
    pub user_id: Uuid,
    pub connection_status: ConnStatus,
    pub severity: Severity,
    pub info_manf: String,
    pub info_name: String
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(history_id), table_name = history)]
pub struct HistoryItem
{
    pub history_id: Uuid,
    pub user_id: Uuid,
    pub timestamp: time::OffsetDateTime,
    pub attack_type: Option<AttackType>,
    pub severity: Severity,
    pub device_address: MacAddress
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone)]
#[diesel(primary_key(manf_name, device_name), table_name = deviceinfo)]
pub struct DeviceInfoItem
{
    pub manf_name: String,
    pub device_name: String,
    pub pps: i32
}

#[derive(Queryable, Insertable, Identifiable, Debug, PartialEq, Serialize, Deserialize, Clone, QueryableByName)]
#[diesel(primary_key(device_id), table_name = unknowndevices)]
pub struct UnknownDeviceItem
{
    pub device_id: MacAddress,
    pub user_id: Uuid,
    pub device_name: Option<String>,
    pub device_vendor: Option<String>,
    pub timestamp: time::OffsetDateTime
}

#[derive(Debug, PartialEq, Serialize, Deserialize, Clone)]
pub struct CombinedDevice
{
    pub device_id: MacAddress,
    pub device_name: String,
    pub user_id: Uuid,
    pub connection_status: ConnStatus,
    pub severity: Severity,
    pub info_manf: Option<String>,
    pub info_name: Option<String>,
    pub pps: Option<i32>
}

impl From<(Device, Option<DeviceInfoItem>)> for CombinedDevice
{
    fn from(value: (Device, Option<DeviceInfoItem>)) -> Self 
    {
        Self 
        {
            device_id: value.0.device_id,
            device_name: value.0.device_name,
            user_id: value.0.user_id,
            connection_status: value.0.connection_status,
            severity: value.0.severity,
            info_manf: value.1.as_ref().map(|x| x.manf_name.clone()),
            info_name: value.1.as_ref().map(|x| x.device_name.clone()), 
            pps: value.1.as_ref().map(|x| x.pps)
        }
    }
}