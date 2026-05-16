# **Dataflow — BloodLink: A Centralized Blood Bank & Donor** **Management System**

**Overview**


BloodLink's dataflow follows a three-phase movement: **registration and intake →**
**operational transactions → output and fulfillment** . Data enters through user-facing
forms, flows through a chain of dependent tables, and exits as query results,
eligibility reports, and inventory status views.


**Phase 1 — Data Entry Points (Where Data Enters)**


There are three distinct entry points into the system:


**1. User Registration** All human actors — donors, blood bank admins, and hospital
admins — register through the system. This creates a record in the `USERS` table first.
The Role field determines what happens next: if the user is a Donor, a corresponding
record is created in `DONOR` . If they are a BankAdmin or HospitalAdmin, a record is
created in `BLOOD_BANK` or `HOSPITAL` respectively. No downstream table can be
populated until a valid `UserID` exists — USERS is the root entry point of the entire
system.


**2. Donation Recording** When a donor visits a blood bank and donates, staff manually
log the event. This enters the `DONATION` table and requires both a valid `DonorID` and
a valid `BankID` to already exist. The donation date and units donated are recorded
here. Simultaneously, the corresponding `BLOOD_INVENTORY` record for that bank and
blood type is updated — `UnitsAvailable` increases and `LastUpdated` is refreshed.


**3. Blood Request Submission** Hospitals submit blood requests through the system
when they need a specific blood type. This enters the `BLOOD_REQUEST` table and
requires a valid `HospitalID` . At the time of submission, `InventoryID` may be NULL if
no matching inventory has been confirmed yet — it gets linked later when a blood
bank fulfills the request.


**Phase 2 — Internal Data Movement (How Data Flows Through**
**Tables)**


The tables have a clear dependency chain:


USERS ├──► DONOR ──────────────────► DONATION ──► BLOOD_INVENTORY
(update) ├──► BLOOD_BANK ──────────────► DONATION         │
└───────────► BLOOD_INVENTORY └──► HOSPITAL ───────────────►
BLOOD_REQUEST ◄── BLOOD_INVENTORY (link)


**Key dependency rules:**


  - `DONOR`, `BLOOD_BANK`, and `HOSPITAL` all depend on `USERS`   - none can exist without a
parent user account.

  - `DONATION` depends on both `DONOR` and `BLOOD_BANK`   - it is the junction event linking a
donor to a specific bank.

  - `BLOOD_INVENTORY` depends on `BLOOD_BANK`   - every inventory record belongs to
exactly one bank, for exactly one blood type (enforced by the UNIQUE constraint on BankID +
BloodType).

  - `BLOOD_REQUEST` depends on `HOSPITAL` (mandatory) and `BLOOD_INVENTORY`
(optional/nullable) — a request can exist before any inventory is matched to it, reflecting
real-world pending requests.


**Inventory update flow:** When a donation is recorded, BloodLink does not store a
static inventory count permanently in DONATION. Instead,
`BLOOD_INVENTORY.UnitsAvailable` is the live running total that gets updated each
time a donation is logged or a request is fulfilled. This means the inventory table
reflects the current real-world state at all times, not a historical snapshot.


**Request fulfillment flow:** When a hospital's request is matched to available
inventory, `BLOOD_REQUEST.InventoryID` is updated from NULL to the relevant
`InventoryID`, `Status` changes from `Pending` to `Fulfilled`, and
`BLOOD_INVENTORY.UnitsAvailable` is decremented by `UnitsRequired` .


**Phase 3 — Data Outputs (What Comes Out)**


BloodLink produces the following outputs from the stored data:


**Eligibility Query** The system queries the `DONOR` table joined with `DONATION` to
determine whether a donor is currently eligible to donate again. Since `IsEligible`
was removed during normalization, eligibility is computed on the fly: a donor is
eligible if `LastDonationDate` is NULL or if 90 or more days have passed since their
last donation date. This is used to filter available donors when a blood bank needs to
call eligible donors for a specific blood type.


**Inventory Status Report** A query across `BLOOD_INVENTORY` joined with `BLOOD_BANK`
produces a per-bank, per-blood-type availability report. This tells hospital admins
which banks currently have stock of a required blood type and how many units are
available, which directly informs which bank they submit a request to.


**Donation History per Donor** A query on `DONATION` filtered by `DonorID` produces a
full history of when a donor donated, how many units, and at which bank. This is
used by blood bank staff to verify a donor's history and set `LastDonationDate`
correctly.


**Request Status Dashboard** A query on `BLOOD_REQUEST` joined with `HOSPITAL` and
`BLOOD_INVENTORY` gives hospital admins a live view of all their submitted requests —


which are Pending, which are Fulfilled, which were Cancelled, and what the urgency
level is.


**Critical Shortage Alert (Query Output)** A query on `BLOOD_INVENTORY` where
`UnitsAvailable = 0` or below a threshold, grouped by `BloodType`, identifies which
blood types are critically low across all banks. This output can be used to trigger
donor outreach.


**Summary Table**


**Stage** **Action** **Tables Involved**
Entry User registers USERS

Donor/Bank/Hospital profile
Entry DONOR, BLOOD_BANK, HOSPITAL
created

DONATION, BLOOD_INVENTORY
Entry Donation logged
(update)
Entry Blood request submitted BLOOD_REQUEST



Internal [Request matched to ]



BLOOD_REQUEST (update),

Internal [Request matched to ]

inventory BLOOD_INVENTORY (update)

Output Donor eligibility check DONOR, DONATION



inventory



Output Inventory availability report [BLOOD_INVENTORY, ]

BLOOD_BANK
Output Donation history DONATION, DONOR

BLOOD_REQUEST, HOSPITAL,
Output Request status dashboard
BLOOD_INVENTORY
Output Critical shortage alert BLOOD_INVENTORY


