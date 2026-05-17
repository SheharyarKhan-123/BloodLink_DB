-- =============================================================================
--  Blood Bank Management System — DML Script
--  Milestone 5: Data Population, UPDATE/DELETE demos, Validation Queries
--  Dialect : MySQL 8.0.16+
--  Commit  : M5: Data populated validation queries added
-- =============================================================================
--
--  HOW TO RUN — TWO STEPS ONLY
--  ----------------------------
--  1. Put all 7 *_clean.csv files in the SAME folder as this .sql file.
--
--  2. Open a terminal in that folder and run:
--         mysql --local-infile=1 -u root -p blood_bank_db < M5_DML_BloodLink.sql
--
--     Or in MySQL Workbench: set the working directory to the folder containing
--     the CSVs, then run this script via the Script tab.
--
--  NOTE: LOAD DATA LOCAL INFILE reads CSVs from whatever folder you run
--        the command from — no need to copy files anywhere special.
-- =============================================================================

USE blood_bank_db;
SET FOREIGN_KEY_CHECKS = 0;
SET SESSION local_infile = 1;

-- =============================================================================
--  SECTION 1 — LOAD DATA LOCAL INFILE  (FK-safe order)
-- =============================================================================

-- ── TABLE 1: USERS (100 rows) ─────────────────────────────────────────────────
LOAD DATA LOCAL INFILE 'USERS_clean.csv'
INTO TABLE USERS
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(UserID, Email, PasswordHash, Role, CreatedAT);

-- ── TABLE 2: BLOOD_BANK (100 rows) ───────────────────────────────────────────
--  FK: USERS(AdminUserID)
LOAD DATA LOCAL INFILE 'BLOOD_BANK_clean.csv'
INTO TABLE BLOOD_BANK
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(BankID, AdminUserID, Name, City, Address, ContactNo);

-- ── TABLE 3: HOSPITAL (100 rows) ─────────────────────────────────────────────
--  FK: USERS(AdminUserID)
LOAD DATA LOCAL INFILE 'HOSPITAL_clean.csv'
INTO TABLE HOSPITAL
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(HospitalID, AdminUserID, Name, City, Address, ContactNo);

-- ── TABLE 4: DONOR (100 rows) ────────────────────────────────────────────────
--  FK: USERS(UserID)
LOAD DATA LOCAL INFILE 'DONOR_clean.csv'
INTO TABLE DONOR
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(DonorID, UserID, FullName, CNIC, BloodType, DateOfBirth, ContactNo, LastDonationDate);

-- ── TABLE 5: BLOOD_INVENTORY (100 rows) ──────────────────────────────────────
--  FK: BLOOD_BANK(BankID)
LOAD DATA LOCAL INFILE 'BLOOD_INVENTORY_clean.csv'
INTO TABLE BLOOD_INVENTORY
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(InventoryID, BankID, BloodType, UnitsAvailable, LastUpdated);

-- ── TABLE 6: DONATION (50 rows — regenerated; source CSV was fully corrupt) ──
--  FK: DONOR(DonorID), BLOOD_BANK(BankID)
LOAD DATA LOCAL INFILE 'DONATION_clean.csv'
INTO TABLE DONATION
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(DonationID, DonorID, BankID, DonationDate, UnitsDonated, ExpiryDate);

-- ── TABLE 7: BLOOD_REQUEST (100 rows) ────────────────────────────────────────
--  FK: HOSPITAL(HospitalID), BLOOD_INVENTORY(InventoryID)
LOAD DATA LOCAL INFILE 'BLOOD_REQUEST_clean.csv'
INTO TABLE BLOOD_REQUEST
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(RequestID, HospitalID, InventoryID, BloodType, UnitsRequired, UrgencyLevel, Status, RequestDate);

SET FOREIGN_KEY_CHECKS = 1;


-- =============================================================================
--  SECTION 2 — UPDATE & DELETE  (each with a WHERE condition)
-- =============================================================================

-- UPDATE 1: Mark stale Pending requests (before 2025-01-01) as Cancelled
UPDATE BLOOD_REQUEST
   SET Status = 'Cancelled'
 WHERE Status = 'Pending'
   AND RequestDate < '2025-01-01';

-- UPDATE 2: Replenish low-stock inventory (under 10 units) — add 50 units
UPDATE BLOOD_INVENTORY
   SET UnitsAvailable = UnitsAvailable + 50,
       LastUpdated    = CURDATE()
 WHERE UnitsAvailable < 10;

-- UPDATE 3: Correct a donor's LastDonationDate (data-entry fix)
UPDATE DONOR
   SET LastDonationDate = '2024-06-15'
 WHERE DonorID = 5;

-- DELETE 1: Remove old cancelled requests (before 2024-01-01)
DELETE FROM BLOOD_REQUEST
 WHERE Status      = 'Cancelled'
   AND RequestDate < '2024-01-01';

-- DELETE 2: Purge expired donation records (expiry before 2023-06-01)
DELETE FROM DONATION
 WHERE ExpiryDate < '2023-06-01';


-- =============================================================================
--  SECTION 3 — VALIDATION QUERIES
-- =============================================================================

-- ── 3a. ROW COUNTS ────────────────────────────────────────────────────────────
SELECT 'USERS'           AS TableName, COUNT(*) AS RowCount FROM USERS
UNION ALL
SELECT 'BLOOD_BANK',                   COUNT(*) FROM BLOOD_BANK
UNION ALL
SELECT 'HOSPITAL',                     COUNT(*) FROM HOSPITAL
UNION ALL
SELECT 'DONOR',                        COUNT(*) FROM DONOR
UNION ALL
SELECT 'BLOOD_INVENTORY',              COUNT(*) FROM BLOOD_INVENTORY
UNION ALL
SELECT 'DONATION',                     COUNT(*) FROM DONATION
UNION ALL
SELECT 'BLOOD_REQUEST',                COUNT(*) FROM BLOOD_REQUEST;

-- ── 3b. NULL CHECKS — all Violations must be 0 ───────────────────────────────
SELECT 'USERS.Email IS NULL'                 AS Check_Name, COUNT(*) AS Violations FROM USERS          WHERE Email IS NULL
UNION ALL
SELECT 'USERS.Role IS NULL',                 COUNT(*) FROM USERS          WHERE Role IS NULL
UNION ALL
SELECT 'BLOOD_BANK.Name IS NULL',            COUNT(*) FROM BLOOD_BANK     WHERE Name IS NULL
UNION ALL
SELECT 'BLOOD_BANK.AdminUserID IS NULL',     COUNT(*) FROM BLOOD_BANK     WHERE AdminUserID IS NULL
UNION ALL
SELECT 'BLOOD_BANK.ContactNo IS NULL',       COUNT(*) FROM BLOOD_BANK     WHERE ContactNo IS NULL
UNION ALL
SELECT 'HOSPITAL.Name IS NULL',              COUNT(*) FROM HOSPITAL       WHERE Name IS NULL
UNION ALL
SELECT 'HOSPITAL.AdminUserID IS NULL',       COUNT(*) FROM HOSPITAL       WHERE AdminUserID IS NULL
UNION ALL
SELECT 'DONOR.FullName IS NULL',             COUNT(*) FROM DONOR          WHERE FullName IS NULL
UNION ALL
SELECT 'DONOR.CNIC IS NULL',                 COUNT(*) FROM DONOR          WHERE CNIC IS NULL
UNION ALL
SELECT 'DONOR.BloodType IS NULL',            COUNT(*) FROM DONOR          WHERE BloodType IS NULL
UNION ALL
SELECT 'DONOR.ContactNo IS NULL',            COUNT(*) FROM DONOR          WHERE ContactNo IS NULL
UNION ALL
SELECT 'BLOOD_INVENTORY.UnitsAvailable < 0', COUNT(*) FROM BLOOD_INVENTORY WHERE UnitsAvailable < 0
UNION ALL
SELECT 'DONATION.DonorID IS NULL',           COUNT(*) FROM DONATION       WHERE DonorID IS NULL
UNION ALL
SELECT 'DONATION.BankID IS NULL',            COUNT(*) FROM DONATION       WHERE BankID IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.Status IS NULL',       COUNT(*) FROM BLOOD_REQUEST  WHERE Status IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.UrgencyLevel IS NULL', COUNT(*) FROM BLOOD_REQUEST  WHERE UrgencyLevel IS NULL;

-- ── 3c. FK INTEGRITY JOINS ────────────────────────────────────────────────────

SELECT bb.BankID, bb.Name AS BankName, u.Email AS AdminEmail, u.Role
  FROM BLOOD_BANK bb JOIN USERS u ON u.UserID = bb.AdminUserID LIMIT 10;

SELECT h.HospitalID, h.Name AS HospitalName, u.Email AS AdminEmail, u.Role
  FROM HOSPITAL h JOIN USERS u ON u.UserID = h.AdminUserID LIMIT 10;

SELECT d.DonorID, d.FullName, d.BloodType, u.Email
  FROM DONOR d JOIN USERS u ON u.UserID = d.UserID LIMIT 10;

SELECT bi.InventoryID, bb.Name AS Bank, bi.BloodType, bi.UnitsAvailable
  FROM BLOOD_INVENTORY bi JOIN BLOOD_BANK bb ON bb.BankID = bi.BankID LIMIT 10;

SELECT dn.DonationID, d.FullName AS DonorName, d.BloodType,
       bb.Name AS Bank, dn.DonationDate, dn.UnitsDonated, dn.ExpiryDate
  FROM DONATION dn
  JOIN DONOR      d  ON d.DonorID  = dn.DonorID
  JOIN BLOOD_BANK bb ON bb.BankID  = dn.BankID
 LIMIT 10;

SELECT br.RequestID, h.Name AS Hospital, bi.BloodType,
       br.UnitsRequired, br.UrgencyLevel, br.Status, br.RequestDate
  FROM BLOOD_REQUEST   br
  JOIN HOSPITAL        h  ON h.HospitalID   = br.HospitalID
  JOIN BLOOD_INVENTORY bi ON bi.InventoryID = br.InventoryID
 LIMIT 10;

-- ── 3d. ORPHAN CHECKS — all must return 0 ────────────────────────────────────
SELECT COUNT(*) AS Orphaned_Banks        FROM BLOOD_BANK     bb LEFT JOIN USERS u  ON u.UserID      = bb.AdminUserID WHERE u.UserID      IS NULL;
SELECT COUNT(*) AS Orphaned_Hospitals    FROM HOSPITAL        h  LEFT JOIN USERS u  ON u.UserID      = h.AdminUserID  WHERE u.UserID      IS NULL;
SELECT COUNT(*) AS Orphaned_Donors       FROM DONOR           d  LEFT JOIN USERS u  ON u.UserID      = d.UserID       WHERE u.UserID      IS NULL;
SELECT COUNT(*) AS Requests_Bad_Hospital FROM BLOOD_REQUEST   br LEFT JOIN HOSPITAL h ON h.HospitalID = br.HospitalID  WHERE h.HospitalID  IS NULL;
SELECT COUNT(*) AS Requests_Bad_Inventory FROM BLOOD_REQUEST  br LEFT JOIN BLOOD_INVENTORY bi ON bi.InventoryID = br.InventoryID WHERE bi.InventoryID IS NULL;
SELECT COUNT(*) AS Donations_Bad_Donor   FROM DONATION        dn LEFT JOIN DONOR    d  ON d.DonorID   = dn.DonorID    WHERE d.DonorID     IS NULL;

-- ── 3e. BUSINESS SPOT-CHECKS ─────────────────────────────────────────────────

SELECT BloodType, SUM(UnitsAvailable) AS TotalUnits, COUNT(*) AS NumLocations
  FROM BLOOD_INVENTORY GROUP BY BloodType ORDER BY TotalUnits DESC;

SELECT br.RequestID, h.Name AS Hospital, br.BloodType, br.UnitsRequired, br.RequestDate
  FROM BLOOD_REQUEST br JOIN HOSPITAL h ON h.HospitalID = br.HospitalID
 WHERE br.Status = 'Pending' AND br.UrgencyLevel = 'Critical'
 ORDER BY br.RequestDate;

SELECT DonorID, FullName, BloodType, LastDonationDate,
       DATEDIFF(CURDATE(), LastDonationDate) AS DaysSinceDonation
  FROM DONOR
 WHERE LastDonationDate < DATE_SUB(CURDATE(), INTERVAL 90 DAY)
 ORDER BY LastDonationDate;

-- End of DML | Commit: M5: Data populated validation queries added
