from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
import mysql.connector
from mysql.connector import Error
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import date, datetime, timedelta
from functools import wraps
import os

app = Flask(__name__)
app.secret_key = 'bloodlink_secret_key_2026'

# ─── DB CONFIG ────────────────────────────────────────────────
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'KeepAway45@',          # ← Change to your MySQL root password
    'database': 'blood_bank_db',
    'charset': 'utf8mb4'
}

def get_db():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        print(f"DB Error: {e}")
        return None

def query(sql, params=None, fetchone=False, commit=False):
    conn = get_db()
    if not conn:
        return None
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, params or ())
        if commit:
            conn.commit()
            return cur.lastrowid
        if fetchone:
            return cur.fetchone()
        return cur.fetchall()
    except Error as e:
        print(f"Query Error: {e}")
        if commit:
            conn.rollback()
        return None
    finally:
        conn.close()

# ─── AUTH DECORATORS ──────────────────────────────────────────
def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in first.', 'warning')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

def role_required(*roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if session.get('role') not in roles:
                flash('Access denied.', 'danger')
                return redirect(url_for('dashboard'))
            return f(*args, **kwargs)
        return decorated
    return decorator

# ─── AUTH ROUTES ──────────────────────────────────────────────
@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email'].strip()
        password = request.form['password']
        user = query("SELECT * FROM USERS WHERE Email = %s", (email,), fetchone=True)
        if user and check_password_hash(user['PasswordHash'], password):
            session['user_id'] = user['UserID']
            session['email'] = user['Email']
            session['role'] = user['Role']
            flash(f"Welcome back! Logged in as {user['Role']}.", 'success')
            return redirect(url_for('dashboard'))
        flash('Invalid email or password.', 'danger')
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        email = request.form['email'].strip()
        password = request.form['password']
        role = request.form['role']
        existing = query("SELECT UserID FROM USERS WHERE Email = %s", (email,), fetchone=True)
        if existing:
            flash('Email already registered.', 'danger')
            return render_template('register.html')
        hashed = generate_password_hash(password)
        uid = query(
            "INSERT INTO USERS (Email, PasswordHash, Role) VALUES (%s, %s, %s)",
            (email, hashed, role), commit=True
        )
        if uid:
            flash('Account created! Please log in.', 'success')
            return redirect(url_for('login'))
        flash('Registration failed. Try again.', 'danger')
    return render_template('register.html')

@app.route('/logout')
def logout():
    session.clear()
    flash('Logged out successfully.', 'info')
    return redirect(url_for('login'))

# ─── DASHBOARD ────────────────────────────────────────────────
@app.route('/dashboard')
@login_required
def dashboard():
    role = session['role']
    stats = {}
    if role == 'BankAdmin':
        bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
        if bank:
            inv = query("SELECT SUM(UnitsAvailable) as total FROM BLOOD_INVENTORY WHERE BankID = %s", (bank['BankID'],), fetchone=True)
            donations = query("SELECT COUNT(*) as cnt FROM DONATION WHERE BankID = %s", (bank['BankID'],), fetchone=True)
            pending = query("SELECT COUNT(*) as cnt FROM BLOOD_REQUEST br JOIN BLOOD_INVENTORY bi ON br.InventoryID = bi.InventoryID WHERE bi.BankID = %s AND br.Status = 'Pending'", (bank['BankID'],), fetchone=True)
            stats = {
                'bank': bank,
                'total_units': inv['total'] or 0 if inv else 0,
                'donations': donations['cnt'] if donations else 0,
                'pending_requests': pending['cnt'] if pending else 0,
            }
    elif role == 'HospitalAdmin':
        hospital = query("SELECT * FROM HOSPITAL WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
        if hospital:
            reqs = query("SELECT COUNT(*) as cnt FROM BLOOD_REQUEST WHERE HospitalID = %s", (hospital['HospitalID'],), fetchone=True)
            pending = query("SELECT COUNT(*) as cnt FROM BLOOD_REQUEST WHERE HospitalID = %s AND Status = 'Pending'", (hospital['HospitalID'],), fetchone=True)
            fulfilled = query("SELECT COUNT(*) as cnt FROM BLOOD_REQUEST WHERE HospitalID = %s AND Status = 'Fulfilled'", (hospital['HospitalID'],), fetchone=True)
            stats = {
                'hospital': hospital,
                'total_requests': reqs['cnt'] if reqs else 0,
                'pending': pending['cnt'] if pending else 0,
                'fulfilled': fulfilled['cnt'] if fulfilled else 0,
            }
    elif role == 'Donor':
        donor = query("SELECT * FROM DONOR WHERE UserID = %s", (session['user_id'],), fetchone=True)
        if donor:
            donations = query("SELECT COUNT(*) as cnt FROM DONATION WHERE DonorID = %s", (donor['DonorID'],), fetchone=True)
            last = query("SELECT DonationDate FROM DONATION WHERE DonorID = %s ORDER BY DonationDate DESC LIMIT 1", (donor['DonorID'],), fetchone=True)
            eligible_date = None
            if last:
                eligible_date = last['DonationDate'] + timedelta(days=90)
            stats = {
                'donor': donor,
                'total_donations': donations['cnt'] if donations else 0,
                'last_donation': last['DonationDate'] if last else None,
                'eligible_date': eligible_date,
                'is_eligible': eligible_date is None or eligible_date <= date.today(),
            }
    # Global stats for all
    total_donors = query("SELECT COUNT(*) as cnt FROM DONOR", fetchone=True)
    total_banks = query("SELECT COUNT(*) as cnt FROM BLOOD_BANK", fetchone=True)
    critical = query("SELECT BloodType, SUM(UnitsAvailable) as total FROM BLOOD_INVENTORY GROUP BY BloodType ORDER BY total ASC LIMIT 3", )
    stats['global'] = {
        'total_donors': total_donors['cnt'] if total_donors else 0,
        'total_banks': total_banks['cnt'] if total_banks else 0,
        'critical_types': critical or [],
    }
    return render_template('dashboard.html', stats=stats, role=role)

# ─── BLOOD BANKS ──────────────────────────────────────────────
@app.route('/banks')
@login_required
def banks():
    if session.get('role') == 'BankAdmin':
        all_banks = query("""
            SELECT bb.*, u.Email as AdminEmail,
                   COALESCE(SUM(bi.UnitsAvailable),0) as TotalUnits
            FROM BLOOD_BANK bb
            JOIN USERS u ON bb.AdminUserID = u.UserID
            LEFT JOIN BLOOD_INVENTORY bi ON bb.BankID = bi.BankID
            WHERE bb.AdminUserID = %s
            GROUP BY bb.BankID
        """, (session['user_id'],))
    else:
        all_banks = query("""
            SELECT bb.*, u.Email as AdminEmail,
                   COALESCE(SUM(bi.UnitsAvailable),0) as TotalUnits
            FROM BLOOD_BANK bb
            JOIN USERS u ON bb.AdminUserID = u.UserID
            LEFT JOIN BLOOD_INVENTORY bi ON bb.BankID = bi.BankID
            GROUP BY bb.BankID
        """)
    if session.get('role') == 'BankAdmin':
        return render_template('my_bank.html', banks=all_banks)
    return render_template('banks.html', banks=all_banks)

@app.route('/banks/add', methods=['GET', 'POST'])
@login_required
@role_required('BankAdmin')
def add_bank():
    existing = query("SELECT BankID FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if existing:
        flash('You already have a registered blood bank.', 'warning')
        return redirect(url_for('banks'))
    if request.method == 'POST':
        name = request.form['name'].strip()
        city = request.form['city'].strip()
        address = request.form['address'].strip()
        contact = request.form['contact'].strip()
        result = query(
            "INSERT INTO BLOOD_BANK (AdminUserID, Name, City, Address, ContactNo) VALUES (%s,%s,%s,%s,%s)",
            (session['user_id'], name, city, address, contact), commit=True
        )
        if result:
            flash('Blood bank registered successfully!', 'success')
            return redirect(url_for('banks'))
        flash('Failed to register bank. Check phone format (0XXX-XXXXXXX).', 'danger')
    return render_template('bank_form.html', action='Add')

@app.route('/banks/edit/<int:bank_id>', methods=['GET', 'POST'])
@login_required
@role_required('BankAdmin')
def edit_bank(bank_id):
    bank = query("SELECT * FROM BLOOD_BANK WHERE BankID = %s AND AdminUserID = %s", (bank_id, session['user_id']), fetchone=True)
    if not bank:
        flash('Bank not found or access denied.', 'danger')
        return redirect(url_for('banks'))
    if request.method == 'POST':
        name = request.form['name'].strip()
        city = request.form['city'].strip()
        address = request.form['address'].strip()
        contact = request.form['contact'].strip()
        query(
            "UPDATE BLOOD_BANK SET Name=%s, City=%s, Address=%s, ContactNo=%s WHERE BankID=%s",
            (name, city, address, contact, bank_id), commit=True
        )
        flash('Bank updated!', 'success')
        return redirect(url_for('banks'))
    return render_template('bank_form.html', action='Edit', bank=bank)

# ─── DONORS ───────────────────────────────────────────────────
@app.route('/donors')
@login_required
def donors():
    search_type = request.args.get('blood_type', '')
    if search_type:
        all_donors = query("""
            SELECT d.*, u.Email,
                   CASE WHEN DATEDIFF(CURDATE(), d.LastDonationDate) >= 90 THEN 'Eligible' ELSE 'Not Eligible' END as EligibilityStatus
            FROM DONOR d JOIN USERS u ON d.UserID = u.UserID
            WHERE d.BloodType = %s
            ORDER BY d.FullName
        """, (search_type,))
    else:
        all_donors = query("""
            SELECT d.*, u.Email,
                   CASE WHEN DATEDIFF(CURDATE(), d.LastDonationDate) >= 90 THEN 'Eligible' ELSE 'Not Eligible' END as EligibilityStatus
            FROM DONOR d JOIN USERS u ON d.UserID = u.UserID
            ORDER BY d.FullName
        """)
    blood_types = ['A+','A-','B+','B-','AB+','AB-','O+','O-']
    return render_template('donors.html', donors=all_donors, blood_types=blood_types, selected=search_type)

@app.route('/donors/profile', methods=['GET', 'POST'])
@login_required
@role_required('Donor')
def donor_profile():
    donor = query("SELECT * FROM DONOR WHERE UserID = %s", (session['user_id'],), fetchone=True)
    if request.method == 'POST':
        full_name = request.form['full_name'].strip()
        cnic = request.form['cnic'].strip()
        blood_type = request.form['blood_type']
        dob = request.form['dob']
        contact = request.form['contact'].strip()
        last_donation = request.form['last_donation']
        if donor:
            query(
                "UPDATE DONOR SET FullName=%s, CNIC=%s, BloodType=%s, DateOfBirth=%s, ContactNo=%s, LastDonationDate=%s WHERE UserID=%s",
                (full_name, cnic, blood_type, dob, contact, last_donation, session['user_id']), commit=True
            )
            flash('Profile updated!', 'success')
        else:
            result = query(
                "INSERT INTO DONOR (UserID, FullName, CNIC, BloodType, DateOfBirth, ContactNo, LastDonationDate) VALUES (%s,%s,%s,%s,%s,%s,%s)",
                (session['user_id'], full_name, cnic, blood_type, dob, contact, last_donation), commit=True
            )
            if result:
                flash('Donor profile created!', 'success')
            else:
                flash('Failed. Check CNIC format (XXXXX-XXXXXXX-X) and phone format.', 'danger')
        return redirect(url_for('donor_profile'))
    blood_types = ['A+','A-','B+','B-','AB+','AB-','O+','O-']
    return render_template('donor_profile.html', donor=donor, blood_types=blood_types)

# ─── INVENTORY ────────────────────────────────────────────────
@app.route('/inventory')
@login_required
def inventory():
    if session.get('role') == 'HospitalAdmin':
        flash('Hospitals do not manage inventory. Use blood requests to obtain blood from banks.', 'info')
        return redirect(url_for('dashboard'))
    inv = query("""
        SELECT bi.*, bb.Name as BankName, bb.City
        FROM BLOOD_INVENTORY bi
        JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
        ORDER BY bb.Name, bi.BloodType
    """)
    return render_template('inventory.html', inventory=inv)

@app.route('/inventory/update', methods=['GET', 'POST'])
@login_required
@role_required('BankAdmin')
def update_inventory():
    bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if not bank:
        flash('Register your blood bank first.', 'warning')
        return redirect(url_for('add_bank'))
    blood_types = ['A+','A-','B+','B-','AB+','AB-','O+','O-']
    if request.method == 'POST':
        blood_type = request.form['blood_type']
        units = int(request.form['units'])
        existing = query("SELECT InventoryID FROM BLOOD_INVENTORY WHERE BankID=%s AND BloodType=%s", (bank['BankID'], blood_type), fetchone=True)
        if existing:
            query("UPDATE BLOOD_INVENTORY SET UnitsAvailable=%s, LastUpdated=CURDATE() WHERE BankID=%s AND BloodType=%s",
                  (units, bank['BankID'], blood_type), commit=True)
            flash(f'Inventory for {blood_type} updated to {units} units.', 'success')
        else:
            query("INSERT INTO BLOOD_INVENTORY (BankID, BloodType, UnitsAvailable) VALUES (%s,%s,%s)",
                  (bank['BankID'], blood_type, units), commit=True)
            flash(f'Inventory for {blood_type} added ({units} units).', 'success')
        return redirect(url_for('update_inventory'))
    my_inv = query("SELECT * FROM BLOOD_INVENTORY WHERE BankID=%s ORDER BY BloodType", (bank['BankID'],))
    return render_template('inventory_update.html', bank=bank, inventory=my_inv, blood_types=blood_types)

# ─── DONATIONS ────────────────────────────────────────────────
@app.route('/donations')
@login_required
def donations():
    role = session['role']
    if role == 'BankAdmin':
        bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
        if bank:
            dons = query("""
                SELECT dn.*, d.FullName as DonorName, d.BloodType, bb.Name as BankName
                FROM DONATION dn
                JOIN DONOR d ON dn.DonorID = d.DonorID
                JOIN BLOOD_BANK bb ON dn.BankID = bb.BankID
                WHERE dn.BankID = %s
                ORDER BY dn.DonationDate DESC
            """, (bank['BankID'],))
        else:
            dons = []
    elif role == 'Donor':
        donor = query("SELECT * FROM DONOR WHERE UserID = %s", (session['user_id'],), fetchone=True)
        if donor:
            dons = query("""
                SELECT dn.*, d.FullName as DonorName, d.BloodType, bb.Name as BankName
                FROM DONATION dn
                JOIN DONOR d ON dn.DonorID = d.DonorID
                JOIN BLOOD_BANK bb ON dn.BankID = bb.BankID
                WHERE dn.DonorID = %s
                ORDER BY dn.DonationDate DESC
            """, (donor['DonorID'],))
        else:
            dons = []
    else:
        dons = query("""
            SELECT dn.*, d.FullName as DonorName, d.BloodType, bb.Name as BankName
            FROM DONATION dn
            JOIN DONOR d ON dn.DonorID = d.DonorID
            JOIN BLOOD_BANK bb ON dn.BankID = bb.BankID
            ORDER BY dn.DonationDate DESC
        """)
    return render_template('donations.html', donations=dons, today=date.today())

@app.route('/donations/log', methods=['GET', 'POST'])
@login_required
@role_required('BankAdmin')
def log_donation():
    bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if not bank:
        flash('Register your blood bank first.', 'warning')
        return redirect(url_for('add_bank'))
    if request.method == 'POST':
        donor_id = int(request.form['donor_id'])
        units = int(request.form['units'])
        donation_date = request.form['donation_date']
        expiry_date = request.form['expiry_date']
        # Insert donation
        did = query(
            "INSERT INTO DONATION (DonorID, BankID, DonationDate, UnitsDonated, ExpiryDate) VALUES (%s,%s,%s,%s,%s)",
            (donor_id, bank['BankID'], donation_date, units, expiry_date), commit=True
        )
        if did:
            # Get donor blood type
            donor = query("SELECT BloodType FROM DONOR WHERE DonorID = %s", (donor_id,), fetchone=True)
            if donor:
                # Update inventory
                existing_inv = query("SELECT InventoryID, UnitsAvailable FROM BLOOD_INVENTORY WHERE BankID=%s AND BloodType=%s",
                                     (bank['BankID'], donor['BloodType']), fetchone=True)
                if existing_inv:
                    query("UPDATE BLOOD_INVENTORY SET UnitsAvailable=UnitsAvailable+%s, LastUpdated=CURDATE() WHERE InventoryID=%s",
                          (units, existing_inv['InventoryID']), commit=True)
                else:
                    query("INSERT INTO BLOOD_INVENTORY (BankID, BloodType, UnitsAvailable) VALUES (%s,%s,%s)",
                          (bank['BankID'], donor['BloodType'], units), commit=True)
                # Update last donation date on donor
                query("UPDATE DONOR SET LastDonationDate=%s WHERE DonorID=%s", (donation_date, donor_id), commit=True)
            flash('Donation logged and inventory updated!', 'success')
            return redirect(url_for('donations'))
        flash('Failed to log donation.', 'danger')
    eligible_donors = query("""
        SELECT d.DonorID, d.FullName, d.BloodType, d.LastDonationDate
        FROM DONOR d
        WHERE DATEDIFF(CURDATE(), d.LastDonationDate) >= 90
        ORDER BY d.FullName
    """)
    return render_template('log_donation.html', bank=bank, donors=eligible_donors)

# ─── BLOOD REQUESTS ───────────────────────────────────────────
@app.route('/requests')
@login_required
def blood_requests():
    role = session['role']
    if role == 'HospitalAdmin':
        hospital = query("SELECT * FROM HOSPITAL WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
        if hospital:
            reqs = query("""
                SELECT br.*, h.Name as HospitalName,
                       bi.BloodType as InvBloodType, bb.Name as BankName
                FROM BLOOD_REQUEST br
                JOIN HOSPITAL h ON br.HospitalID = h.HospitalID
                LEFT JOIN BLOOD_INVENTORY bi ON br.InventoryID = bi.InventoryID
                LEFT JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
                WHERE br.HospitalID = %s
                ORDER BY br.RequestDate DESC
            """, (hospital['HospitalID'],))
        else:
            reqs = []
    elif role == 'BankAdmin':
        bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
        if bank:
            reqs = query("""
                SELECT br.*, h.Name as HospitalName,
                       bi.BloodType as InvBloodType, bb.Name as BankName
                FROM BLOOD_REQUEST br
                JOIN HOSPITAL h ON br.HospitalID = h.HospitalID
                LEFT JOIN BLOOD_INVENTORY bi ON br.InventoryID = bi.InventoryID
                LEFT JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
                WHERE bb.BankID = %s OR br.InventoryID IS NULL
                ORDER BY br.UrgencyLevel DESC, br.RequestDate DESC
            """, (bank['BankID'],))
        else:
            reqs = []
    else:
        reqs = query("""
            SELECT br.*, h.Name as HospitalName,
                   bi.BloodType as InvBloodType, bb.Name as BankName
            FROM BLOOD_REQUEST br
            JOIN HOSPITAL h ON br.HospitalID = h.HospitalID
            LEFT JOIN BLOOD_INVENTORY bi ON br.InventoryID = bi.InventoryID
            LEFT JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
            ORDER BY br.RequestDate DESC
        """)
    return render_template('requests.html', requests=reqs, role=role)

@app.route('/requests/new', methods=['GET', 'POST'])
@login_required
@role_required('HospitalAdmin')
def new_request():
    hospital = query("SELECT * FROM HOSPITAL WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if not hospital:
        flash('Register your hospital first.', 'warning')
        return redirect(url_for('add_hospital'))
    blood_types = ['A+','A-','B+','B-','AB+','AB-','O+','O-']
    if request.method == 'POST':
        blood_type = request.form['blood_type']
        units = int(request.form['units'])
        urgency = request.form['urgency']
        # Find matching inventory
        inv = query("SELECT InventoryID FROM BLOOD_INVENTORY WHERE BloodType=%s AND UnitsAvailable >= %s LIMIT 1",
                    (blood_type, units), fetchone=True)
        inv_id = inv['InventoryID'] if inv else None
        result = query(
            "INSERT INTO BLOOD_REQUEST (HospitalID, InventoryID, BloodType, UnitsRequired, UrgencyLevel) VALUES (%s,%s,%s,%s,%s)",
            (hospital['HospitalID'], inv_id, blood_type, units, urgency), commit=True
        )
        if result:
            flash('Blood request submitted!', 'success')
            return redirect(url_for('blood_requests'))
        flash('Failed to submit request.', 'danger')
    return render_template('new_request.html', hospital=hospital, blood_types=blood_types)

@app.route('/requests/fulfill/<int:request_id>', methods=['POST'])
@login_required
@role_required('BankAdmin')
def fulfill_request(request_id):
    req = query("SELECT * FROM BLOOD_REQUEST WHERE RequestID = %s AND Status = 'Pending'", (request_id,), fetchone=True)
    if not req:
        flash('Request not found or already handled.', 'danger')
        return redirect(url_for('blood_requests'))
    bank = query("SELECT * FROM BLOOD_BANK WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if not bank:
        flash('No blood bank associated.', 'danger')
        return redirect(url_for('blood_requests'))
    inv = query("SELECT * FROM BLOOD_INVENTORY WHERE BankID=%s AND BloodType=%s AND UnitsAvailable >= %s",
                (bank['BankID'], req['BloodType'], req['UnitsRequired']), fetchone=True)
    if not inv:
        flash(f'Insufficient {req["BloodType"]} inventory to fulfill this request.', 'danger')
        return redirect(url_for('blood_requests'))
    # Deduct inventory
    query("UPDATE BLOOD_INVENTORY SET UnitsAvailable=UnitsAvailable-%s, LastUpdated=CURDATE() WHERE InventoryID=%s",
          (req['UnitsRequired'], inv['InventoryID']), commit=True)
    # Update request
    query("UPDATE BLOOD_REQUEST SET Status='Fulfilled', InventoryID=%s WHERE RequestID=%s",
          (inv['InventoryID'], request_id), commit=True)
    flash('Request fulfilled successfully!', 'success')
    return redirect(url_for('blood_requests'))

@app.route('/requests/cancel/<int:request_id>', methods=['POST'])
@login_required
def cancel_request(request_id):
    hospital = query("SELECT * FROM HOSPITAL WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if hospital:
        query("UPDATE BLOOD_REQUEST SET Status='Cancelled' WHERE RequestID=%s AND HospitalID=%s AND Status='Pending'",
              (request_id, hospital['HospitalID']), commit=True)
        flash('Request cancelled.', 'info')
    return redirect(url_for('blood_requests'))

# ─── HOSPITALS ────────────────────────────────────────────────
@app.route('/hospitals')
@login_required
def hospitals():
    if session.get('role') == 'HospitalAdmin':
        all_hospitals = query("""
            SELECT h.*, u.Email as AdminEmail,
                   COUNT(br.RequestID) as TotalRequests,
                   SUM(CASE WHEN br.Status='Pending' THEN 1 ELSE 0 END) as PendingRequests,
                   SUM(CASE WHEN br.Status='Fulfilled' THEN 1 ELSE 0 END) as FulfilledRequests
            FROM HOSPITAL h
            JOIN USERS u ON h.AdminUserID = u.UserID
            LEFT JOIN BLOOD_REQUEST br ON h.HospitalID = br.HospitalID
            WHERE h.AdminUserID = %s
            GROUP BY h.HospitalID
        """, (session['user_id'],))
        return render_template('my_hospital.html', hospitals=all_hospitals)
    else:
        all_hospitals = query("""
            SELECT h.*, u.Email as AdminEmail
            FROM HOSPITAL h JOIN USERS u ON h.AdminUserID = u.UserID
        """)
        return render_template('hospitals.html', hospitals=all_hospitals)

@app.route('/hospitals/add', methods=['GET', 'POST'])
@login_required
@role_required('HospitalAdmin')
def add_hospital():
    existing = query("SELECT HospitalID FROM HOSPITAL WHERE AdminUserID = %s", (session['user_id'],), fetchone=True)
    if existing:
        flash('You already have a registered hospital.', 'warning')
        return redirect(url_for('hospitals'))
    if request.method == 'POST':
        name = request.form['name'].strip()
        city = request.form['city'].strip()
        address = request.form['address'].strip()
        contact = request.form['contact'].strip()
        result = query(
            "INSERT INTO HOSPITAL (AdminUserID, Name, City, Address, ContactNo) VALUES (%s,%s,%s,%s,%s)",
            (session['user_id'], name, city, address, contact), commit=True
        )
        if result:
            flash('Hospital registered!', 'success')
            return redirect(url_for('hospitals'))
        flash('Failed. Check phone format (0XXX-XXXXXXX).', 'danger')
    return render_template('hospital_form.html', action='Add')

@app.route('/hospitals/edit/<int:hospital_id>', methods=['GET', 'POST'])
@login_required
@role_required('HospitalAdmin')
def edit_hospital(hospital_id):
    hospital = query("SELECT * FROM HOSPITAL WHERE HospitalID=%s AND AdminUserID=%s", (hospital_id, session['user_id']), fetchone=True)
    if not hospital:
        flash('Hospital not found or access denied.', 'danger')
        return redirect(url_for('hospitals'))
    if request.method == 'POST':
        name = request.form['name'].strip()
        city = request.form['city'].strip()
        address = request.form['address'].strip()
        contact = request.form['contact'].strip()
        query("UPDATE HOSPITAL SET Name=%s, City=%s, Address=%s, ContactNo=%s WHERE HospitalID=%s",
              (name, city, address, contact, hospital_id), commit=True)
        flash('Hospital updated!', 'success')
        return redirect(url_for('hospitals'))
    return render_template('hospital_form.html', action='Edit', hospital=hospital)

# ─── REPORTS / ALERTS ─────────────────────────────────────────
@app.route('/reports')
@login_required
def reports():
    if session.get('role') == 'HospitalAdmin':
        flash('Reports are not available for hospitals. Track your requests under Requests.', 'info')
        return redirect(url_for('blood_requests'))
    # Critical shortage (< 5 units)
    shortages = query("""
        SELECT bi.BloodType, SUM(bi.UnitsAvailable) as total, COUNT(bi.BankID) as bank_count
        FROM BLOOD_INVENTORY bi
        GROUP BY bi.BloodType
        HAVING total < 5
        ORDER BY total ASC
    """)
    # Inventory summary
    inv_summary = query("""
        SELECT bi.BloodType, SUM(bi.UnitsAvailable) as total
        FROM BLOOD_INVENTORY bi
        GROUP BY bi.BloodType
        ORDER BY bi.BloodType
    """)
    # Eligible donors count
    eligible = query("""
        SELECT BloodType, COUNT(*) as cnt
        FROM DONOR
        WHERE DATEDIFF(CURDATE(), LastDonationDate) >= 90
        GROUP BY BloodType
    """)
    # Recent donations
    recent_donations = query("""
        SELECT dn.DonationDate, d.FullName, d.BloodType, dn.UnitsDonated, bb.Name as BankName
        FROM DONATION dn
        JOIN DONOR d ON dn.DonorID = d.DonorID
        JOIN BLOOD_BANK bb ON dn.BankID = bb.BankID
        ORDER BY dn.DonationDate DESC LIMIT 10
    """)
    return render_template('reports.html',
                           shortages=shortages,
                           inv_summary=inv_summary,
                           eligible=eligible,
                           recent_donations=recent_donations)

# ─── API ENDPOINTS ────────────────────────────────────────────
@app.route('/api/inventory')
def api_inventory():
    blood_type = request.args.get('blood_type')
    if blood_type:
        data = query("""
            SELECT bb.Name as bank, bb.City, bi.BloodType, bi.UnitsAvailable, bi.LastUpdated
            FROM BLOOD_INVENTORY bi JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
            WHERE bi.BloodType = %s AND bi.UnitsAvailable > 0
        """, (blood_type,))
    else:
        data = query("""
            SELECT bb.Name as bank, bb.City, bi.BloodType, bi.UnitsAvailable, bi.LastUpdated
            FROM BLOOD_INVENTORY bi JOIN BLOOD_BANK bb ON bi.BankID = bb.BankID
        """)
    # Convert dates to strings
    for row in (data or []):
        if row.get('LastUpdated'):
            row['LastUpdated'] = str(row['LastUpdated'])
    return jsonify(data or [])

@app.route('/api/eligible-donors')
def api_eligible_donors():
    blood_type = request.args.get('blood_type')
    if blood_type:
        data = query("""
            SELECT d.FullName, d.BloodType, d.ContactNo
            FROM DONOR d
            WHERE d.BloodType = %s AND DATEDIFF(CURDATE(), d.LastDonationDate) >= 90
        """, (blood_type,))
    else:
        data = query("""
            SELECT d.FullName, d.BloodType, d.ContactNo
            FROM DONOR d
            WHERE DATEDIFF(CURDATE(), d.LastDonationDate) >= 90
        """)
    return jsonify(data or [])

if __name__ == '__main__':
    import os
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
