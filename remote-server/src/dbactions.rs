use crate::models::*;
use diesel::prelude::*;
use uuid::Uuid;

type DieselError = diesel::result::Error;

pub fn get_unknown_devices(conn: &mut PgConnection, mut user: Uuid) -> Result<Vec<UnknownDeviceItem>, DieselError>
{
    use crate::schema::unknowndevices::dsl::*;

    check_user(conn, &mut user)?;

    unknowndevices.filter(user_id.eq(user)).load::<UnknownDeviceItem>(conn)
}

pub fn add_unknown_device(conn: &mut PgConnection, did: MacAddress, mut user: Uuid, dname: Option<String>, dvendor: Option<String>)
    -> Result<UnknownDeviceItem, DieselError>
{
    use crate::schema::unknowndevices::dsl::*;

    check_user(conn, &mut user)?;

    //Check device isnt already in the loaded devices table
    {
        use crate::schema::devices::dsl as devs;
        let res = devs::devices.filter(devs::device_id.eq(did.clone())).get_result::<Device>(conn);
        if res != Err(diesel::result::Error::NotFound)
        {
            return Err(DieselError::DatabaseError(diesel::result::DatabaseErrorKind::UniqueViolation, Box::new(String::from("Already found in added devices"))));
        }
    }

    let item = UnknownDeviceItem
    {
        device_id: did, user_id: user, timestamp: time::OffsetDateTime::now_utc(), device_name: dname, device_vendor: dvendor
    };

    diesel::insert_into(unknowndevices)
        .values(item)
        .get_result(conn)
}

pub fn get_device_info(conn: &mut PgConnection) -> Result<Vec<DeviceInfoItem>, DieselError>
{
    use crate::schema::deviceinfo::dsl::*;

    deviceinfo
        .order_by(device_name)
        .load::<DeviceInfoItem>(conn)
}

pub fn get_history_items(conn: &mut PgConnection, mut user: Uuid, count: i64) -> Result<Vec<HistoryItem>, DieselError>
{
    use crate::schema::history::dsl::*;

    check_user(conn, &mut user)?;

    history
        .filter(user_id.eq(user))
        .order_by(timestamp.desc())
        .limit(count)
        .load::<HistoryItem>(conn)
}

pub fn add_history_item(conn: &mut PgConnection, item: &mut HistoryItem) -> Result<HistoryItem, DieselError>
{
    use crate::schema::history::dsl::*;

    check_user(conn, &mut item.user_id)?;

    diesel::insert_into(history)
        .values(item.clone())
        .get_result(conn)
}

pub fn update_device_status(conn: &mut PgConnection, mut user: Uuid, device: &MacAddress, status: ConnStatus, sev: Option<Severity>) -> Result<Device, DieselError>
{
    use crate::schema::devices::dsl::*;

    check_user(conn, &mut user)?;

    match sev
    {
        Some(x) =>
        {
            diesel::update(devices)
                .filter(device_id.eq(device))
                .filter(user_id.eq(user))
                .set((connection_status.eq(status), severity.eq(x)))
                .get_result::<Device>(conn)
        }
        None =>
        {
            diesel::update(devices)
                .filter(device_id.eq(device))
                .filter(user_id.eq(user))
                .set(connection_status.eq(status))
                .get_result::<Device>(conn)
        }
    }
}


pub fn get_device(conn: &mut PgConnection, mut user: Uuid) -> Result<Vec<CombinedDevice>, DieselError>
{
    use crate::schema::devices::dsl as dev;
    use crate::schema::deviceinfo::dsl as inf;

    check_user(conn, &mut user)?;

    let result = dev::devices.left_outer_join(
        inf::deviceinfo.on(dev::info_name.eq(inf::device_name).and(dev::info_manf.eq(inf::manf_name)))
    )
        .filter(dev::user_id.eq(user))
        .load::<(Device, Option<DeviceInfoItem>)>(conn);

    match result
    {
        Ok(x) => Ok(x.into_iter().map(|item| item.into()).collect()),
        Err(e) => Err(e)
    }
}

pub fn add_device(conn: &mut PgConnection, mut device: Device) -> Result<Device, DieselError>
{
    use crate::schema::devices::dsl::*;

    check_user(conn, &mut device.user_id)?;

    let id = device.device_id.clone();

    let res = diesel::insert_into(devices)
        .values(device)
        .get_result(conn);

    if res.is_ok()
    {
        use crate::schema::unknowndevices::dsl as ud;
        let _ = diesel::delete(ud::unknowndevices.filter(
            ud::device_id.eq(id)))
            .get_result::<UnknownDeviceItem>(conn);
    }
    res
}

pub fn delete_device(conn: &mut PgConnection, mut uid: Uuid, did: &MacAddress) -> Result<Device, DieselError>
{
    use crate::schema::devices::dsl::*;

    check_user(conn, &mut uid)?;

    diesel::delete(devices.filter(device_id.eq(did))
        .filter(user_id.eq(uid)))
        .get_result(conn)
}

pub fn add_user(conn: &mut PgConnection, user: User) -> Result<User, DieselError>
{
    use crate::schema::accounts::dsl as accnts;
    use crate::schema::users::dsl as usrs;

    let accounts = accnts::accounts.filter(accnts::account_id.eq(user.account_id)).load::<Account>(conn)?;
    if accounts.is_empty()
    {
        diesel::insert_into(accnts::accounts)
            .values(Account { account_id: user.account_id }).get_result::<Account>(conn)?;
    }

    diesel::insert_into(usrs::users)
        .values(user)
        .get_result(conn)
}

pub fn add_apns_registration(conn: &mut PgConnection, aid: String, user: Uuid) -> Result<ApnsIdItem, DieselError>
{
    {
        use crate::schema::users::dsl::*;
        let usrs = users.filter(user_id.eq(user)).load::<User>(conn)?;
        if usrs.is_empty()
        {
            return Err(DieselError::NotFound);
        }
    }
    
    {
        use crate::schema::apnsid::dsl::*;
        let items = apnsid.filter(apns_id.eq(aid.clone())).load::<ApnsIdItem>(conn)?;
        if items.is_empty()
        {
            diesel::insert_into(apnsid).values(ApnsIdItem { apns_id: aid, user_id: user }).get_result::<ApnsIdItem>(conn)
        }
        else
        {
            diesel::update(apnsid)
                .filter(apns_id.eq(aid))
                .set(user_id.eq(user))
                .get_result::<ApnsIdItem>(conn)
        }
    }
}

pub fn get_all_notif_ids(conn: &mut PgConnection, mut luid: Uuid) -> Result<Vec<ApnsIdItem>, DieselError>
{
    let usrs;
    {
        use crate::schema::users::dsl::*;
        check_user(conn, &mut luid)?;

        usrs = users.filter(account_id.eq(luid)).load::<User>(conn)?;
        if usrs.is_empty()
        {
            return Err(DieselError::NotFound);
        }
    }

    let mut apnsids = Vec::new();
    for usr in usrs
    {
        use crate::schema::apnsid::dsl::*;
        let mut items = apnsid.filter(user_id.eq(usr.user_id)).load::<ApnsIdItem>(conn)?;
        apnsids.append(&mut items);
    }
    Ok(apnsids)
}

pub fn delete_user(conn: &mut PgConnection, user: Uuid) -> Result<User, DieselError>
{
    use crate::schema::users::dsl::*;

    diesel::delete(users.filter(user_id.eq(user)))
        .get_result(conn)
}

pub fn clear_unknown_devices(conn: &mut PgConnection)
{
    let deleted_unknowns = diesel::sql_query("DELETE FROM UnknownDevices WHERE NOW() - timestamp >= make_interval(hours => 1)").get_results::<UnknownDeviceItem>(conn);

    if let Ok(removed) = deleted_unknowns
    {
        for x in removed
        {
            println!("Expired Unknown {:?}", x);
        }
    }
    else
    {
        println!("Error deleting unknowns");    
    }
}

fn check_user(conn: &mut PgConnection, user: &mut Uuid) -> Result<(), DieselError>
{
    use crate::schema::users::dsl::*;

    let mut result = users.filter(user_id.eq(*user)).load::<User>(conn)?;
    if result.is_empty()
    {
        result = users.filter(account_id.eq(*user)).load::<User>(conn)?;
        if result.is_empty()
        {
            println!("{}, Invalid user id/local server id provided.", time::OffsetDateTime::now_local().unwrap_or(time::OffsetDateTime::now_utc()));
            return Err(DieselError::NotFound);
        }
    }
    *user = result[0].account_id;
    Ok(())
}
