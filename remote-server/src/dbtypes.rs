use diesel::prelude::*;
use serde::{Serialize, Deserialize, ser::SerializeStruct};
use uuid::Uuid;
use std::time::{Instant, SystemTime};

#[derive(Queryable)]
pub struct HistoryEntry
{
    pub id: Uuid,
    pub time: Instant,
    pub attack_type: String
}

//FIgure out what db timestamp resolves to in the serialization (Instant, Duration, or SystemTime)

impl Serialize for HistoryEntry
{
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer
    {
        let mut s = serializer.serialize_struct("HistoryEntry", 3)?;
        s.serialize_field("id", &self.id)?;
        //s.serialize_field("time", value)
        s.serialize_field("attack_type", &self.attack_type)?;
        s.end()
    }
}