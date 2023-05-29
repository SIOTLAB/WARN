// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "attacktype"))]
    pub struct Attacktype;

    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "connstatus"))]
    pub struct Connstatus;

    #[derive(diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "severity"))]
    pub struct Severity;
}

diesel::table! {
    accounts (account_id) {
        account_id -> Uuid,
    }
}

diesel::table! {
    apnsid (apns_id) {
        apns_id -> Varchar,
        user_id -> Uuid,
    }
}

diesel::table! {
    deviceinfo (manf_name, device_name) {
        manf_name -> Varchar,
        device_name -> Varchar,
        pps -> Int4,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::Connstatus;
    use super::sql_types::Severity;

    devices (device_id) {
        device_id -> Varchar,
        device_name -> Varchar,
        user_id -> Uuid,
        connection_status -> Connstatus,
        severity -> Severity,
        info_manf -> Varchar,
        info_name -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::Attacktype;
    use super::sql_types::Severity;

    history (history_id) {
        history_id -> Uuid,
        user_id -> Uuid,
        timestamp -> Timestamptz,
        attack_type -> Nullable<Attacktype>,
        severity -> Severity,
        device_address -> Varchar,
    }
}

diesel::table! {
    unknowndevices (device_id) {
        device_id -> Varchar,
        user_id -> Uuid,
        device_name -> Nullable<Varchar>,
        device_vendor -> Nullable<Varchar>,
        timestamp -> Timestamptz,
    }
}

diesel::table! {
    users (user_id) {
        user_id -> Uuid,
        account_id -> Uuid,
    }
}

diesel::joinable!(apnsid -> users (user_id));
diesel::joinable!(devices -> accounts (user_id));
diesel::joinable!(history -> accounts (user_id));
diesel::joinable!(history -> devices (device_address));
diesel::joinable!(unknowndevices -> accounts (user_id));
diesel::joinable!(users -> accounts (account_id));

diesel::allow_tables_to_appear_in_same_query!(
    accounts,
    apnsid,
    deviceinfo,
    devices,
    history,
    unknowndevices,
    users,
);
