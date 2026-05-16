**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

# **BloodLink**
### A Centralized Blood Bank & Donor Management System

## **Normalization Report — Milestone 2**

Step 1: 1NF → 2NF → 3NF | Step 2: Redundancy Removal


**Sheharyar Khan & Khawaja Haris Khan**

BCS-A | Database Systems | May 2026


Page 1  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

## **Step 1 — Apply Normalization**


Each table from the original Milestone 1 schema is evaluated in sequence: 1NF → 2NF → 3NF. For each normal form, any violation is
identified, the corrective change is documented, and the reason is explained. If a table already satisfies a normal form with no changes, a
justification is provided.


**1.1 First Normal Form (1NF)**

1NF requires: (a) each column holds atomic (indivisible) values, (b) each row is unique (identified by a primary key), and (c) there are no
repeating groups or multi-valued attributes.


**Table: USERS**



|Issue Found|Change Made|Why|
|---|---|---|
|Role column stores an ENUM<br>— this is atomic (one value<br>per row). No mult-valued<br>atributes found. UserID is the<br>PK, guaranteeing row<br>uniqueness.|No change required.|All columns are single-valued. ENUM is<br>treated as a constrained atomic domain. The<br>table is already in 1NF.|


**Table: BLOOD_BANK**









|Issue Found|Change Made|Why|
|---|---|---|
|Locaton stores a full address<br>string (e.g., 'Plot 12, Gulshan,<br>Karachi'). This is technically a<br>composite value packed into<br>a single VARCHAR.|Locaton is split into: City (VARCHAR<br>100) and Address (VARCHAR 255).<br>ContactNo is already atomic.|1NF mandates atomicity. A full address mixes<br>city, area, and street — splitng ensures each<br>atribute is independently queryable and truly<br>atomic.|


**Table: HOSPITAL**









|Issue Found|Change Made|Why|
|---|---|---|
|Same issue: Locaton is a<br>composite address string,<br>identcal to BLOOD_BANK.|Locaton split into City (VARCHAR 100)<br>and Address (VARCHAR 255), matching<br>the BLOOD_BANK fx.|Consistency and atomicity — city-level<br>queries (e.g., 'all hospitals in Karachi') become<br>straightorward without string parsing.|


**Table: DONOR**









|Issue Found|Change Made|Why|
|---|---|---|
|All columns are atomic.<br>DonorID is the PK. BloodType<br>is an ENUM (atomic). CNIC<br>has a UNIQUE constraint<br>confrming no duplicates. No<br>repeatng groups.|No change required.|The table satsfes all 1NF conditons. Each<br>feld stores exactly one value per row; no<br>mult-valued or composite atributes exist.|


**Table: DONATION**







Page 2  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan



|Issue Found|Change Made|Why|
|---|---|---|
|All columns are atomic.<br>DonatonID is the PK. No<br>repeatng groups.|No change required.|Single-valued columns, unique rows via PK.<br>The table is already in 1NF.|


**Table: BLOOD_INVENTORY**







|Issue Found|Change Made|Why|
|---|---|---|
|All columns are atomic.<br>BloodType is an ENUM.<br>LastUpdated is a TIMESTAMP.<br>No repeatng groups.|No change required.|Every atribute holds a single, indivisible<br>value. The table is in 1NF.|


**Table: BLOOD_REQUEST**










|Issue Found|Change Made|Why|
|---|---|---|
|All columns are atomic.<br>RequestID is the PK. Status<br>and UrgencyLevel are ENUMs<br>(atomic). InventoryID is<br>NULLABLE but stll single-<br>valued per row.|No change required.|No mult-valued atributes or repeatng<br>groups. The table satsfes 1NF.|



**1.2 Second Normal Form (2NF)**

2NF applies to tables with composite primary keys. It requires that every non-key attribute is fully functionally dependent on the entire
composite key — not just part of it. Tables with a single-column PK are automatically in 2NF once in 1NF.


**Tables with single-column PKs — automatic 2NF**

USERS (UserID), BLOOD_BANK (BankID), HOSPITAL (HospitalID), DONOR (DonorID), DONATION (DonationID), BLOOD_INVENTORY
(InventoryID), BLOOD_REQUEST (RequestID) — all have single-attribute primary keys. Partial dependency is structurally impossible with a
single-column PK; therefore all seven tables are already in 2NF. No changes required.


**Composite key check — BLOOD_INVENTORY**








|Issue Found|Change Made|Why|
|---|---|---|
|Although InventoryID is the<br>PK, the combinaton (BankID,<br>BloodType) is a natural<br>unique composite and could<br>be considered a candidate<br>key. Checking: UnitsAvailable<br>and LastUpdated depend on<br>the full (BankID, BloodType)<br>pair — not on BankID alone or<br>BloodType alone.|No change required. A UNIQUE<br>constraint on (BankID, BloodType) is<br>added as best practce to enforce the<br>candidate key.|Full functonal dependency exists. No partal<br>dependency violaton. The table is in 2NF. The<br>UNIQUE constraint prevents duplicate<br>inventory entries per blood type per bank.|



Page 3  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan


**1.3 Third Normal Form (3NF)**

3NF requires that no non-key attribute is transitively dependent on the primary key through another non-key attribute. Every non-key
attribute must depend directly on the PK — nothing else.


**Table: USERS**



|Issue Found|Change Made|Why|
|---|---|---|
|ReferenceID stores the ID of<br>either a Donor or a Blood<br>Bank Admin depending on the<br>Role value. This creates an<br>implicit transitve<br>dependency: Role → what<br>ReferenceID points to. The<br>meaning of ReferenceID<br>depends on Role (a non-key<br>atribute).|ReferenceID is removed from USERS.<br>The link between a user account and<br>their entty (Donor or Blood Bank<br>Admin) is established by the FK UserID<br>in the DONOR and BLOOD_BANK tables<br>respectvely, which already exist in the<br>schema.|Having ReferenceID depend on the value of<br>Role is a transitve dependency. The<br>referental integrity is already enforced<br>through the child tables; ReferenceID is<br>redundant and violates 3NF.|


**Table: DONOR**









|Issue Found|Change Made|Why|
|---|---|---|
|IsEligible is derived from<br>LastDonatonDate (a donor is<br>eligible if 90+ days have<br>passed since last donaton).<br>This is a transitve<br>dependency: DonorID →<br>LastDonatonDate →<br>IsEligible.|IsEligible is removed as a stored<br>column. Eligibility is computed at query<br>tme using a VIEW or applicaton logic:<br>IsEligible = (LastDonatonDate IS NULL<br>OR DATEDIFF(CURDATE(),<br>LastDonatonDate) >= 90).|Storing a derived value creates a transitve<br>dependency and risks data inconsistency<br>(e.g., eligibility not updated afer a new<br>donaton). Removing it enforces 3NF and<br>ensures correctness.|
|ContactNo in DONOR: a<br>donor's contact number<br>depends only on the donor<br>(DonorID), not transitvely<br>through any other non-key<br>atribute. No violaton.|No change required.|ContactNo → DonorID directly. No transitve<br>chain through any other non-key column.<br>Already in 3NF.|


**Table: BLOOD_BANK**









|Issue Found|Change Made|Why|
|---|---|---|
|Afer the 1NF split,<br>BLOOD_BANK has: BankID,<br>AdminUserID, Name, City,<br>Address, ContactNo. All non-<br>key atributes depend only on<br>BankID. No transitve<br>dependencies.|No change required.|Name, City, Address, ContactNo, and<br>AdminUserID all describe the bank directly.<br>No atribute depends on another non-key<br>atribute. The table is in 3NF.|


**Table: HOSPITAL**







|Issue Found|Change Made|Why|
|---|---|---|
|Afer the 1NF split, HOSPITAL|No change required.|No transitve dependencies exist. The table is|


Page 4  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan



|Issue Found|Change Made|Why|
|---|---|---|
|has: HospitalID, AdminUserID,<br>Name, City, Address,<br>ContactNo. Identcal structure<br>to BLOOD_BANK. All<br>atributes depend directly on<br>HospitalID.||in 3NF.|


**Table: DONATION**







|Issue Found|Change Made|Why|
|---|---|---|
|ExpiryDate: Blood expiry<br>depends on the type of<br>donaton and donaton date<br>— it could be argued as a<br>transitve dependency<br>(DonorID → BloodType →<br>ExpiryDate). However,<br>ExpiryDate is explicitly<br>recorded per donaton (not<br>derived), as diferent<br>donatons of the same blood<br>type may be processed<br>diferently. It depends on<br>DonatonID directly.|No change required. ExpiryDate<br>remains as an explicit per-donaton<br>recorded atribute.|ExpiryDate is a stored fact about this specifc<br>donaton event, not computed from another<br>non-key atribute. No transitve dependency.<br>Table is in 3NF.|


**Table: BLOOD_INVENTORY**









|Issue Found|Change Made|Why|
|---|---|---|
|UnitsAvailable and<br>LastUpdated both depend<br>directly on InventoryID (or the<br>candidate key BankID +<br>BloodType). No non-key<br>atribute depends on another<br>non-key atribute.|No change required.|Direct dependency on PK. No transitve chain.<br>Table is in 3NF.|


**Table: BLOOD_REQUEST**












|Issue Found|Change Made|Why|
|---|---|---|
|BloodType is stored in<br>BLOOD_REQUEST. If<br>InventoryID is provided (not<br>NULL), BloodType could be<br>derived from<br>BLOOD_INVENTORY via<br>InventoryID. This creates a<br>potental transitve<br>dependency: RequestID →<br>InventoryID → BloodType.|BloodType is retained in<br>BLOOD_REQUEST. InventoryID is<br>NULLABLE (a request may be unfulflled<br>with no inventory match). When<br>InventoryID is NULL, BloodType cannot<br>be derived from it — so BloodType<br>must be stored independently. A<br>CHECK or trigger ensures consistency<br>when InventoryID is not NULL.|The NULLABLE FK breaks the transitve<br>dependency in the classical sense. Since<br>InventoryID may not exist (pending requests),<br>BloodType must be a direct atribute.<br>Retaining it is both correct and required for<br>operatonal completeness. No 3NF violaton.|



Page 5  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

## **Step 2 — Remove Duplicates & Redundancy**


All tables are examined for redundant columns, repeated data, overlapping attributes, or data that can be derived rather than stored.





|Table / Column|Action Taken & Justification|
|---|---|
|**USERS — ReferenceID**|REMOVED. This column was already identfed as violatng 3NF. The relatonship<br>between a User and their Donor/Admin record is captured by the UserID FK in<br>DONOR and BLOOD_BANK, making ReferenceID entrely redundant.|
|**DONOR — IsEligible**|REMOVED. IsEligible = (LastDonatonDate IS NULL OR DATEDIFF(CURDATE(),<br>LastDonatonDate) >= 90) is a derived boolean that duplicates informaton<br>already present in LastDonatonDate. Storing it risks inconsistency and wastes<br>space.|
|**BLOOD_BANK — Locaton HOSPITAL**<br>**— Locaton**|RESTRUCTURED. The single Locaton VARCHAR was split into City and Address<br>(1NF fx). This also removes implicit duplicaton where the city name was<br>embedded inside the full address string.|
|**BLOOD_INVENTORY — BloodType vs**<br>**DONATION — BloodType**|NO CHANGE. BloodType appears in DONOR, DONATION, BLOOD_INVENTORY,<br>and BLOOD_REQUEST. This is intentonal denormalizaton for operatonal<br>reasons: each entty records the blood type relevant to that record<br>independently. Foreign key chains would require mult-join queries for every<br>blood-availability lookup, hurtng performance in a real-tme medical system.|
|**HOSPITAL & BLOOD_BANK — parallel**<br>**structure**|NO MERGE. Despite similar columns (AdminUserID, Name, City, Address,<br>ContactNo), hospitals and blood banks are fundamentally diferent enttes with<br>diferent roles in the system. Merging them into a single table with a type<br>discriminator would violate clean design and complicate queries.|
|**DONATION — DonorID FK implies**<br>**BloodType**|NO CHANGE. BloodType in DONATION is not strictly derivable at query tme<br>without a join, and donors can theoretcally update blood type records (rare but<br>possible). Storing it per donaton preserves historical accuracy.|


Page 6  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

## **Final Normalized Schema (Post-Normalization)**


The following tables reflect all changes made during normalization. Removed columns are excluded. Added constraints are noted.


**USERS (updated)**

|Column|Type|Constraints|
|---|---|---|
|**UserID**|INT|PK, AUTO_INCREMENT|
|**Email**|VARCHAR(150)|NOT NULL, UNIQUE|
|**PasswordHash**|VARCHAR(255)|NOT NULL|
|**Role**|ENUM('Donor','BankAdmin','HospitalA<br>dmin')|NOT NULL|
|**CreatedAt**|TIMESTAMP|DEFAULT CURRENT_TIMESTAMP|



**BLOOD_BANK (updated — Location split)**

|Column|Type|Constraints|
|---|---|---|
|**BankID**|INT|PK, AUTO_INCREMENT|
|**AdminUserID**|INT|FK → USERS(UserID), NOT NULL|
|**Name**|VARCHAR(150)|NOT NULL|
|**City**|VARCHAR(100)|NOT NULL|
|**Address**|VARCHAR(255)|NOT NULL|
|**ContactNo**|VARCHAR(20)|NULLABLE|



**HOSPITAL (updated — Location split)**

|Column|Type|Constraints|
|---|---|---|
|**HospitalID**|INT|PK, AUTO_INCREMENT|
|**AdminUserID**|INT|FK → USERS(UserID), NOT NULL|
|**Name**|VARCHAR(150)|NOT NULL|
|**City**|VARCHAR(100)|NOT NULL|
|**Address**|VARCHAR(255)|NOT NULL|
|**ContactNo**|VARCHAR(20)|NULLABLE|



**DONOR (updated — IsEligible removed)**

|Column|Type|Constraints|
|---|---|---|
|**DonorID**|INT|PK, AUTO_INCREMENT|
|**UserID**|INT|FK → USERS(UserID), NOT NULL|
|**FullName**|VARCHAR(100)|NOT NULL|



Page 7  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

|Column|Type|Constraints|
|---|---|---|
|**CNIC**|CHAR(15)|NOT NULL, UNIQUE|
|**BloodType**|ENUM('A+','A-','B+','B-','AB+','AB-','O+'<br>,'O-')|NOT NULL|
|**DateOfBirth**|DATE|NOT NULL|
|**ContactNo**|VARCHAR(20)|NULLABLE|
|**LastDonatonDate**|DATE|NULLABLE|



**DONATION (unchanged)**

|Column|Type|Constraints|
|---|---|---|
|**DonatonID**|INT|PK, AUTO_INCREMENT|
|**DonorID**|INT|FK → DONOR(DonorID), NOT NULL|
|**BankID**|INT|FK → BLOOD_BANK(BankID), NOT<br>NULL|
|**DonatonDate**|DATE|NOT NULL|
|**UnitsDonated**|INT|NOT NULL|
|**ExpiryDate**|DATE|NOT NULL|



**BLOOD_INVENTORY (UNIQUE constraint added)**

|Column|Type|Constraints|
|---|---|---|
|**InventoryID**|INT|PK, AUTO_INCREMENT|
|**BankID**|INT|FK → BLOOD_BANK(BankID), NOT<br>NULL|
|**BloodType**|ENUM('A+','A-','B+','B-','AB+','AB-','O+'<br>,'O-')|NOT NULL|
|**UnitsAvailable**|INT|NOT NULL, DEFAULT 0|
|**LastUpdated**|TIMESTAMP|DEFAULT CURRENT_TIMESTAMP ON<br>UPDATE CURRENT_TIMESTAMP|



Note: UNIQUE(BankID, BloodType) constraint added to enforce candidate key.


**BLOOD_REQUEST (unchanged)**






|Column|Type|Constraints|
|---|---|---|
|**RequestID**|INT|PK, AUTO_INCREMENT|
|**HospitalID**|INT|FK → HOSPITAL(HospitalID), NOT NULL|
|**InventoryID**|INT|FK →<br>BLOOD_INVENTORY(InventoryID),<br>NULLABLE|



Page 8  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

|Column|Type|Constraints|
|---|---|---|
|**BloodType**|ENUM('A+','A-','B+','B-','AB+','AB-','O+'<br>,'O-')|NOT NULL|
|**UnitsRequired**|INT|NOT NULL|
|**UrgencyLevel**|ENUM('Critcal','High','Normal')|NOT NULL|
|**Status**|ENUM('Pending','Fulflled','Cancelled')|NOT NULL, DEFAULT 'Pending'|
|**RequestDate**|DATE|NOT NULL, DEFAULT CURDATE()|



Page 9  |  BloodLink — Database Systems Lab  |  May 2026


**BloodLink** |  Normalization Report  |  BCS-A  |  Sheharyar Khan & Khawaja Haris Khan

## **Summary of All Changes**







|Table|NF Stage|Change|Impact|
|---|---|---|---|
|**BLOOD_BANK**|**1NF**|Locaton → City + Address|Atomicity achieved; city-level<br>queries enabled|
|**HOSPITAL**|**1NF**|Locaton → City + Address|Same as above|
|**USERS**|**3NF**|ReferenceID removed|Transitve dependency &<br>redundancy eliminated|
|**DONOR**|**3NF**|IsEligible removed|Derived column removed;<br>computed via query|
|**BLOOD_INVENTORY**|**2NF**|UNIQUE(BankID, BloodType)<br>added|Candidate key enforced;<br>duplicates prevented|
|**All others**|**1NF/2NF/3NF**|No structural change|Already normalized; confrmed<br>with justfcaton|


Page 10  |  BloodLink — Database Systems Lab  |  May 2026


