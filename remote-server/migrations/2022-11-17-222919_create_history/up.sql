-- Your SQL goes here
-- TODO
    -- ADD: DIRECTION, strength of attack signal,

CREATE TYPE AttackType AS ENUM (
    'deauthentication', 'krack'
);

CREATE TYPE ConnStatus AS ENUM (
    'online', 'offline', 'unknown'
);

CREATE TYPE Severity AS ENUM (
    'ok', 'warning', 'attack'
);

CREATE TABLE Accounts (
    account_id UUID PRIMARY KEY
);

CREATE TABLE Users (
    user_id UUID PRIMARY KEY,
    account_id UUID REFERENCES Accounts(account_id) NOT NULL
);

CREATE TABLE ApnsID (
    apns_id VARCHAR(64) PRIMARY KEY CHECK (LENGTH(apns_id) = 64),
    user_id UUID REFERENCES Users(user_id) ON DELETE CASCADE NOT NULL
);

CREATE TABLE DeviceInfo (
    manf_name VARCHAR(100) NOT NULL,
    device_name VARCHAR(100) NOT NULL,
    pps INTEGER NOT NULL CHECK (pps > 0),
    PRIMARY KEY (manf_name, device_name)
);

CREATE TABLE Devices (
    device_id VARCHAR(17) PRIMARY KEY CHECK (device_id = LOWER(device_id) AND LENGTH(device_id) = 17),
    device_name VARCHAR(100) NOT NULL,
    user_id UUID REFERENCES Accounts(account_id) NOT NULL,
    connection_status ConnStatus NOT NULL DEFAULT 'unknown',
    severity Severity NOT NULL Default 'ok',
    info_manf VARCHAR(100) NOT NULL,
    info_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (info_manf, info_name) REFERENCES DeviceInfo(manf_name, device_name)
);

CREATE TABLE UnknownDevices (
    device_id VARCHAR(17) PRIMARY KEY CHECK (device_id = LOWER(device_id) AND LENGTH(device_id) = 17),
    user_id UUID REFERENCES Accounts(account_id) NOT NULL,
    device_name VARCHAR(256) DEFAULT NULL,
    device_vendor VARCHAR(256) DEFAULT NULL,
    timestamp TIMESTAMPTZ NOT NULL
);

CREATE TABLE History (
    history_id UUID PRIMARY KEY,
    user_id UUID REFERENCES Accounts(account_id) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    attack_type AttackType,
    severity Severity NOT NULL,
    device_address VARCHAR(17) REFERENCES Devices(device_id) ON DELETE CASCADE NOT NULL CHECK (device_address = LOWER(device_address) AND LENGTH(device_address) = 17)
);