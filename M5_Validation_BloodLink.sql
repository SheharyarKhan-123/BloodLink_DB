-- =============================================================================
--  Blood Bank Management System — Validation Queries
--  Milestone 5: Post-Load Data Validation
--  Dialect : MySQL 8.0.16+
--  Commit  : M5: Data populated validation queries added
--
--  Run AFTER M5_DML_BloodLink.sql has been executed.
--  Every query is labelled with its expected result.
-- =============================================================================

USE blood_bank_db;

-- =============================================================================
--  VALIDATION 1 — COUNT(*) FOR EACH TABLE
--  Expected: USERS=100, BLOOD_BANK=100, HOSPITAL=100, DONOR=100,
--            BLOOD_INVENTORY=100, DONATION=50, BLOOD_REQUEST=100
-- =============================================================================

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


-- =============================================================================
--  VALIDATION 2 — NULL CHECK ON KEY COLUMNS
--  Expected: Violations = 0 for every row
-- =============================================================================

SELECT 'USERS.Email'                  AS Column_Checked, COUNT(*) AS NULL_Count FROM USERS          WHERE Email IS NULL
UNION ALL
SELECT 'USERS.PasswordHash',          COUNT(*) FROM USERS          WHERE PasswordHash IS NULL
UNION ALL
SELECT 'USERS.Role',                  COUNT(*) FROM USERS          WHERE Role IS NULL
UNION ALL
SELECT 'USERS.CreatedAT',             COUNT(*) FROM USERS          WHERE CreatedAT IS NULL
UNION ALL
SELECT 'BLOOD_BANK.AdminUserID',      COUNT(*) FROM BLOOD_BANK     WHERE AdminUserID IS NULL
UNION ALL
SELECT 'BLOOD_BANK.Name',             COUNT(*) FROM BLOOD_BANK     WHERE Name IS NULL
UNION ALL
SELECT 'BLOOD_BANK.City',             COUNT(*) FROM BLOOD_BANK     WHERE City IS NULL
UNION ALL
SELECT 'BLOOD_BANK.ContactNo',        COUNT(*) FROM BLOOD_BANK     WHERE ContactNo IS NULL
UNION ALL
SELECT 'HOSPITAL.AdminUserID',        COUNT(*) FROM HOSPITAL       WHERE AdminUserID IS NULL
UNION ALL
SELECT 'HOSPITAL.Name',               COUNT(*) FROM HOSPITAL       WHERE Name IS NULL
UNION ALL
SELECT 'HOSPITAL.City',               COUNT(*) FROM HOSPITAL       WHERE City IS NULL
UNION ALL
SELECT 'HOSPITAL.ContactNo',          COUNT(*) FROM HOSPITAL       WHERE ContactNo IS NULL
UNION ALL
SELECT 'DONOR.UserID',                COUNT(*) FROM DONOR          WHERE UserID IS NULL
UNION ALL
SELECT 'DONOR.FullName',              COUNT(*) FROM DONOR          WHERE FullName IS NULL
UNION ALL
SELECT 'DONOR.CNIC',                  COUNT(*) FROM DONOR          WHERE CNIC IS NULL
UNION ALL
SELECT 'DONOR.BloodType',             COUNT(*) FROM DONOR          WHERE BloodType IS NULL
UNION ALL
SELECT 'DONOR.DateOfBirth',           COUNT(*) FROM DONOR          WHERE DateOfBirth IS NULL
UNION ALL
SELECT 'DONOR.ContactNo',             COUNT(*) FROM DONOR          WHERE ContactNo IS NULL
UNION ALL
SELECT 'DONOR.LastDonationDate',      COUNT(*) FROM DONOR          WHERE LastDonationDate IS NULL
UNION ALL
SELECT 'BLOOD_INVENTORY.BankID',      COUNT(*) FROM BLOOD_INVENTORY WHERE BankID IS NULL
UNION ALL
SELECT 'BLOOD_INVENTORY.BloodType',   COUNT(*) FROM BLOOD_INVENTORY WHERE BloodType IS NULL
UNION ALL
SELECT 'BLOOD_INVENTORY.UnitsAvailable', COUNT(*) FROM BLOOD_INVENTORY WHERE UnitsAvailable IS NULL
UNION ALL
SELECT 'DONATION.DonorID',            COUNT(*) FROM DONATION       WHERE DonorID IS NULL
UNION ALL
SELECT 'DONATION.BankID',             COUNT(*) FROM DONATION       WHERE BankID IS NULL
UNION ALL
SELECT 'DONATION.DonationDate',       COUNT(*) FROM DONATION       WHERE DonationDate IS NULL
UNION ALL
SELECT 'DONATION.ExpiryDate',         COUNT(*) FROM DONATION       WHERE ExpiryDate IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.HospitalID',    COUNT(*) FROM BLOOD_REQUEST  WHERE HospitalID IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.InventoryID',   COUNT(*) FROM BLOOD_REQUEST  WHERE InventoryID IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.BloodType',     COUNT(*) FROM BLOOD_REQUEST  WHERE BloodType IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.Status',        COUNT(*) FROM BLOOD_REQUEST  WHERE Status IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.UrgencyLevel',  COUNT(*) FROM BLOOD_REQUEST  WHERE UrgencyLevel IS NULL
UNION ALL
SELECT 'BLOOD_REQUEST.RequestDate',   COUNT(*) FROM BLOOD_REQUEST  WHERE RequestDate IS NULL;


-- =============================================================================
--  VALIDATION 3 — FOREIGN KEY INTEGRITY (JOIN-based checks)
--  Expected: each query returns rows with no NULLs on the joined columns
-- =============================================================================

-- 3a. BLOOD_BANK → USERS (every bank admin must exist in USERS)
SELECT bb.BankID,
       bb.Name          AS BankName,
       bb.AdminUserID,
       u.Email          AS AdminEmail,
       u.Role
  FROM BLOOD_BANK bb
  JOIN USERS u ON u.UserID = bb.AdminUserID
 ORDER BY bb.BankID
 LIMIT 10;

-- 3b. HOSPITAL → USERS (every hospital admin must exist in USERS)
SELECT h.HospitalID,
       h.Name           AS HospitalName,
       h.AdminUserID,
       u.Email          AS AdminEmail,
       u.Role
  FROM HOSPITAL h
  JOIN USERS u ON u.UserID = h.AdminUserID
 ORDER BY h.HospitalID
 LIMIT 10;

-- 3c. DONOR → USERS (every donor account must exist in USERS)
SELECT d.DonorID,
       d.FullName,
       d.BloodType,
       d.UserID,
       u.Email
  FROM DONOR d
  JOIN USERS u ON u.UserID = d.UserID
 ORDER BY d.DonorID
 LIMIT 10;

-- 3d. BLOOD_INVENTORY → BLOOD_BANK (every inventory row must link to a bank)
SELECT bi.InventoryID,
       bi.BloodType,
       bi.UnitsAvailable,
       bb.BankID,
       bb.Name          AS BankName,
       bb.City
  FROM BLOOD_INVENTORY bi
  JOIN BLOOD_BANK bb ON bb.BankID = bi.BankID
 ORDER BY bi.InventoryID
 LIMIT 10;

-- 3e. DONATION → DONOR + BLOOD_BANK (donations must link to valid donor and bank)
SELECT dn.DonationID,
       d.FullName       AS DonorName,
       d.BloodType,
       bb.Name          AS BankName,
       dn.DonationDate,
       dn.UnitsDonated,
       dn.ExpiryDate
  FROM DONATION dn
  JOIN DONOR      d  ON d.DonorID  = dn.DonorID
  JOIN BLOOD_BANK bb ON bb.BankID  = dn.BankID
 ORDER BY dn.DonationID
 LIMIT 10;

-- 3f. BLOOD_REQUEST → HOSPITAL + BLOOD_INVENTORY (requests must link to both)
SELECT br.RequestID,
       h.Name           AS HospitalName,
       bi.BloodType,
       br.UnitsRequired,
       br.UrgencyLevel,
       br.Status,
       br.RequestDate
  FROM BLOOD_REQUEST   br
  JOIN HOSPITAL        h  ON h.HospitalID   = br.HospitalID
  JOIN BLOOD_INVENTORY bi ON bi.InventoryID = br.InventoryID
 ORDER BY br.RequestID
 LIMIT 10;


-- =============================================================================
--  VALIDATION 4 — ORPHAN CHECKS
--  Expected: every query returns 0
-- =============================================================================

-- 4a. BLOOD_BANK rows whose AdminUserID has no matching USERS row
SELECT COUNT(*) AS Orphaned_Banks
  FROM BLOOD_BANK bb
  LEFT JOIN USERS u ON u.UserID = bb.AdminUserID
 WHERE u.UserID IS NULL;

-- 4b. HOSPITAL rows whose AdminUserID has no matching USERS row
SELECT COUNT(*) AS Orphaned_Hospitals
  FROM HOSPITAL h
  LEFT JOIN USERS u ON u.UserID = h.AdminUserID
 WHERE u.UserID IS NULL;

-- 4c. DONOR rows whose UserID has no matching USERS row
SELECT COUNT(*) AS Orphaned_Donors
  FROM DONOR d
  LEFT JOIN USERS u ON u.UserID = d.UserID
 WHERE u.UserID IS NULL;

-- 4d. BLOOD_INVENTORY rows whose BankID has no matching BLOOD_BANK row
SELECT COUNT(*) AS Orphaned_Inventory
  FROM BLOOD_INVENTORY bi
  LEFT JOIN BLOOD_BANK bb ON bb.BankID = bi.BankID
 WHERE bb.BankID IS NULL;

-- 4e. DONATION rows whose DonorID has no matching DONOR row
SELECT COUNT(*) AS Donations_No_Donor
  FROM DONATION dn
  LEFT JOIN DONOR d ON d.DonorID = dn.DonorID
 WHERE d.DonorID IS NULL;

-- 4f. DONATION rows whose BankID has no matching BLOOD_BANK row
SELECT COUNT(*) AS Donations_No_Bank
  FROM DONATION dn
  LEFT JOIN BLOOD_BANK bb ON bb.BankID = dn.BankID
 WHERE bb.BankID IS NULL;

-- 4g. BLOOD_REQUEST rows whose HospitalID has no matching HOSPITAL row
SELECT COUNT(*) AS Requests_No_Hospital
  FROM BLOOD_REQUEST br
  LEFT JOIN HOSPITAL h ON h.HospitalID = br.HospitalID
 WHERE h.HospitalID IS NULL;

-- 4h. BLOOD_REQUEST rows whose InventoryID has no matching BLOOD_INVENTORY row
SELECT COUNT(*) AS Requests_No_Inventory
  FROM BLOOD_REQUEST br
  LEFT JOIN BLOOD_INVENTORY bi ON bi.InventoryID = br.InventoryID
 WHERE bi.InventoryID IS NULL;


-- =============================================================================
--  VALIDATION 5 — UNIQUE CONSTRAINT CHECKS
--  Expected: Duplicates = 0 for every row
-- =============================================================================

-- 5a. Duplicate emails in USERS
SELECT COUNT(*) - COUNT(DISTINCT Email) AS Duplicate_Emails
  FROM USERS;

-- 5b. Duplicate CNICs in DONOR
SELECT COUNT(*) - COUNT(DISTINCT CNIC) AS Duplicate_CNICs
  FROM DONOR;

-- 5c. Duplicate phone numbers in BLOOD_BANK
SELECT COUNT(*) - COUNT(DISTINCT ContactNo) AS Duplicate_Bank_Phones
  FROM BLOOD_BANK;

-- 5d. Duplicate phone numbers in HOSPITAL
SELECT COUNT(*) - COUNT(DISTINCT ContactNo) AS Duplicate_Hospital_Phones
  FROM HOSPITAL;

-- 5e. Duplicate (BankID, BloodType) pairs in BLOOD_INVENTORY
SELECT COUNT(*) - COUNT(DISTINCT CONCAT(BankID, '-', BloodType)) AS Duplicate_Inventory_Pairs
  FROM BLOOD_INVENTORY;


-- =============================================================================
--  VALIDATION 6 — DATA INTEGRITY / BUSINESS RULE CHECKS
--  Expected: Violations = 0 for every row
-- =============================================================================

-- 6a. Donors whose LastDonationDate is before their DateOfBirth (impossible)
SELECT COUNT(*) AS DOB_After_Donation_Violations
  FROM DONOR
 WHERE LastDonationDate <= DateOfBirth;

-- 6b. Donation records where ExpiryDate is not after DonationDate
SELECT COUNT(*) AS Expiry_Before_Donation_Violations
  FROM DONATION
 WHERE ExpiryDate <= DonationDate;

-- 6c. Inventory rows with negative units
SELECT COUNT(*) AS Negative_Inventory_Violations
  FROM BLOOD_INVENTORY
 WHERE UnitsAvailable < 0;

-- 6d. Donation UnitsDonated outside allowed range (must be 1 or 2)
SELECT COUNT(*) AS Invalid_Units_Donated
  FROM DONATION
 WHERE UnitsDonated NOT BETWEEN 1 AND 2;

-- 6e. Blood request UnitsRequired outside allowed range (must be 1–10)
SELECT COUNT(*) AS Invalid_Units_Required
  FROM BLOOD_REQUEST
 WHERE UnitsRequired NOT BETWEEN 1 AND 10;


-- =============================================================================
--  VALIDATION 7 — SUMMARY / ANALYTICAL CHECKS
--  Confirms the data makes sense at a high level
-- =============================================================================

-- 7a. Blood type distribution across all donors
SELECT BloodType,
       COUNT(*) AS DonorCount
  FROM DONOR
 GROUP BY BloodType
 ORDER BY DonorCount DESC;

-- 7b. Total blood units available per blood type across all banks
SELECT BloodType,
       SUM(UnitsAvailable) AS TotalUnits,
       COUNT(*)            AS BankLocations,
       MIN(UnitsAvailable) AS MinStock,
       MAX(UnitsAvailable) AS MaxStock
  FROM BLOOD_INVENTORY
 GROUP BY BloodType
 ORDER BY TotalUnits DESC;

-- 7c. Blood request breakdown by Status and UrgencyLevel
SELECT Status,
       UrgencyLevel,
       COUNT(*) AS RequestCount
  FROM BLOOD_REQUEST
 GROUP BY Status, UrgencyLevel
 ORDER BY Status, UrgencyLevel;

-- 7d. Donations per bank (top 10 most active banks)
SELECT bb.Name AS BankName,
       bb.City,
       COUNT(dn.DonationID)  AS TotalDonations,
       SUM(dn.UnitsDonated)  AS TotalUnitsDonated
  FROM BLOOD_BANK bb
  LEFT JOIN DONATION dn ON dn.BankID = bb.BankID
 GROUP BY bb.BankID, bb.Name, bb.City
 ORDER BY TotalDonations DESC
 LIMIT 10;

-- 7e. Hospitals with the most blood requests (top 10)
SELECT h.Name AS HospitalName,
       h.City,
       COUNT(br.RequestID)   AS TotalRequests,
       SUM(br.UnitsRequired) AS TotalUnitsRequested
  FROM HOSPITAL h
  LEFT JOIN BLOOD_REQUEST br ON br.HospitalID = h.HospitalID
 GROUP BY h.HospitalID, h.Name, h.City
 ORDER BY TotalRequests DESC
 LIMIT 10;

-- 7f. User role distribution
SELECT Role,
       COUNT(*) AS UserCount
  FROM USERS
 GROUP BY Role
 ORDER BY UserCount DESC;

-- End of Validation Queries | Commit: M5: Data populated validation queries added
