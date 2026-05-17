-- =============================================================================
--  Blood Bank Management System — DDL Script (FIXED v2)
--  M4: DDL scripts added, EER diagram verified
--  Dialect : MySQL 8.0.16+
--  Fixes vs v1:
--    1. Removed UNIQUE(AdminUserID) from HOSPITAL  (one admin → multiple branches)
--    2. Removed UNIQUE(AdminUserID) from BLOOD_BANK (same)
--    3. Removed UNIQUE(UserID) from DONOR           (FK only; uniqueness at app layer)
--    4. Removed CHECK(CURRENT_DATE ...) constraints  (MySQL error 3816)
-- =============================================================================

DROP DATABASE IF EXISTS blood_bank_db;
CREATE DATABASE blood_bank_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE blood_bank_db;
SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────────────────
--  TABLE 1: USERS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE USERS (
    UserID       INT          NOT NULL AUTO_INCREMENT,
    Email        VARCHAR(255) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Role         ENUM('Donor','BankAdmin','HospitalAdmin') NOT NULL,
    CreatedAT    DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_users       PRIMARY KEY (UserID),
    CONSTRAINT uq_users_email UNIQUE      (Email),
    CONSTRAINT chk_users_email CHECK (Email LIKE '%_@__%.__%')
);
CREATE INDEX idx_users_email ON USERS (Email);
CREATE INDEX idx_users_role  ON USERS (Role);

-- ─────────────────────────────────────────────────────────────
--  TABLE 2: BLOOD_BANK
--  FIX 1: No UNIQUE on AdminUserID
-- ─────────────────────────────────────────────────────────────
CREATE TABLE BLOOD_BANK (
    BankID      INT          NOT NULL AUTO_INCREMENT,
    AdminUserID INT          NOT NULL,
    Name        VARCHAR(150) NOT NULL,
    City        VARCHAR(100) NOT NULL,
    Address     VARCHAR(255) NOT NULL,
    ContactNo   VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_blood_bank       PRIMARY KEY (BankID),
    CONSTRAINT uq_blood_bank_phone UNIQUE      (ContactNo),
    CONSTRAINT fk_blood_bank_admin FOREIGN KEY (AdminUserID)
        REFERENCES USERS (UserID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_blood_bank_phone CHECK (ContactNo REGEXP '^0[0-9]{3}-[0-9]{7}$')
);
CREATE INDEX idx_blood_bank_admin ON BLOOD_BANK (AdminUserID);
CREATE INDEX idx_blood_bank_city  ON BLOOD_BANK (City);

-- ─────────────────────────────────────────────────────────────
--  TABLE 3: HOSPITAL
--  FIX 2: No UNIQUE on AdminUserID
-- ─────────────────────────────────────────────────────────────
CREATE TABLE HOSPITAL (
    HospitalID  INT          NOT NULL AUTO_INCREMENT,
    AdminUserID INT          NOT NULL,
    Name        VARCHAR(150) NOT NULL,
    City        VARCHAR(100) NOT NULL,
    Address     VARCHAR(255) NOT NULL,
    ContactNo   VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_hospital       PRIMARY KEY (HospitalID),
    CONSTRAINT uq_hospital_phone UNIQUE      (ContactNo),
    CONSTRAINT fk_hospital_admin FOREIGN KEY (AdminUserID)
        REFERENCES USERS (UserID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_hospital_phone CHECK (ContactNo REGEXP '^0[0-9]{3}-[0-9]{7}$')
);
CREATE INDEX idx_hospital_admin ON HOSPITAL (AdminUserID);
CREATE INDEX idx_hospital_city  ON HOSPITAL (City);

-- ─────────────────────────────────────────────────────────────
--  TABLE 4: DONOR
--  FIX 3: No UNIQUE on UserID  |  FIX 4: No CHECK(CURRENT_DATE)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE DONOR (
    DonorID          INT          NOT NULL AUTO_INCREMENT,
    UserID           INT          NOT NULL,
    FullName         VARCHAR(150) NOT NULL,
    CNIC             CHAR(15)     NOT NULL,
    BloodType        ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    DateOfBirth      DATE         NOT NULL,
    ContactNo        VARCHAR(20)  NOT NULL,
    LastDonationDate DATE         NOT NULL,
    CONSTRAINT pk_donor      PRIMARY KEY (DonorID),
    CONSTRAINT uq_donor_cnic UNIQUE      (CNIC),
    CONSTRAINT fk_donor_user FOREIGN KEY (UserID)
        REFERENCES USERS (UserID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_donor_cnic              CHECK (CNIC REGEXP '^[0-9]{5}-[0-9]{7}-[0-9]$'),
    CONSTRAINT chk_donor_donation_after_dob CHECK (LastDonationDate > DateOfBirth),
    CONSTRAINT chk_donor_phone             CHECK (ContactNo REGEXP '^0[0-9]{3}-[0-9]{7}$')
);
CREATE INDEX idx_donor_user      ON DONOR (UserID);
CREATE INDEX idx_donor_bloodtype ON DONOR (BloodType);
CREATE INDEX idx_donor_cnic      ON DONOR (CNIC);

-- ─────────────────────────────────────────────────────────────
--  TABLE 5: BLOOD_INVENTORY
-- ─────────────────────────────────────────────────────────────
CREATE TABLE BLOOD_INVENTORY (
    InventoryID    INT  NOT NULL AUTO_INCREMENT,
    BankID         INT  NOT NULL,
    BloodType      ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    UnitsAvailable INT  NOT NULL DEFAULT 0,
    LastUpdated    DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_blood_inventory     PRIMARY KEY (InventoryID),
    CONSTRAINT uq_inventory_bank_type UNIQUE      (BankID, BloodType),
    CONSTRAINT fk_inventory_bank      FOREIGN KEY (BankID)
        REFERENCES BLOOD_BANK (BankID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_inventory_units CHECK (UnitsAvailable >= 0)
);
CREATE INDEX idx_inventory_bank      ON BLOOD_INVENTORY (BankID);
CREATE INDEX idx_inventory_bloodtype ON BLOOD_INVENTORY (BloodType);
CREATE INDEX idx_inventory_bank_type ON BLOOD_INVENTORY (BankID, BloodType);

-- ─────────────────────────────────────────────────────────────
--  TABLE 6: DONATION
--  FIX 4: No CHECK(DonationDate <= CURRENT_DATE)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE DONATION (
    DonationID   INT              NOT NULL AUTO_INCREMENT,
    DonorID      INT              NOT NULL,
    BankID       INT              NOT NULL,
    DonationDate DATE             NOT NULL,
    UnitsDonated TINYINT UNSIGNED NOT NULL DEFAULT 1,
    ExpiryDate   DATE             NOT NULL,
    CONSTRAINT pk_donation       PRIMARY KEY (DonationID),
    CONSTRAINT fk_donation_donor FOREIGN KEY (DonorID)
        REFERENCES DONOR (DonorID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_donation_bank  FOREIGN KEY (BankID)
        REFERENCES BLOOD_BANK (BankID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_donation_units  CHECK (UnitsDonated BETWEEN 1 AND 2),
    CONSTRAINT chk_donation_expiry CHECK (ExpiryDate > DonationDate)
);
CREATE INDEX idx_donation_donor  ON DONATION (DonorID);
CREATE INDEX idx_donation_bank   ON DONATION (BankID);
CREATE INDEX idx_donation_date   ON DONATION (DonationDate);
CREATE INDEX idx_donation_expiry ON DONATION (ExpiryDate);

-- ─────────────────────────────────────────────────────────────
--  TABLE 7: BLOOD_REQUEST
-- ─────────────────────────────────────────────────────────────
CREATE TABLE BLOOD_REQUEST (
    RequestID     INT              NOT NULL AUTO_INCREMENT,
    HospitalID    INT              NOT NULL,
    InventoryID   INT              NOT NULL,
    BloodType     ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    UnitsRequired TINYINT UNSIGNED NOT NULL,
    UrgencyLevel  ENUM('Normal','High','Critical')          NOT NULL DEFAULT 'Normal',
    Status        ENUM('Pending','Fulfilled','Cancelled')   NOT NULL DEFAULT 'Pending',
    RequestDate   DATE             NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_blood_request     PRIMARY KEY (RequestID),
    CONSTRAINT fk_request_hospital  FOREIGN KEY (HospitalID)
        REFERENCES HOSPITAL (HospitalID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_request_inventory FOREIGN KEY (InventoryID)
        REFERENCES BLOOD_INVENTORY (InventoryID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_request_units CHECK (UnitsRequired BETWEEN 1 AND 10)
);
CREATE INDEX idx_request_hospital       ON BLOOD_REQUEST (HospitalID);
CREATE INDEX idx_request_inventory      ON BLOOD_REQUEST (InventoryID);
CREATE INDEX idx_request_status         ON BLOOD_REQUEST (Status);
CREATE INDEX idx_request_urgency        ON BLOOD_REQUEST (UrgencyLevel);
CREATE INDEX idx_request_bloodtype      ON BLOOD_REQUEST (BloodType);
CREATE INDEX idx_request_date           ON BLOOD_REQUEST (RequestDate);
CREATE INDEX idx_request_status_urgency ON BLOOD_REQUEST (Status, UrgencyLevel);

SET FOREIGN_KEY_CHECKS = 1;
-- End of DDL | Commit: M4: DDL scripts added, EER diagram verified
