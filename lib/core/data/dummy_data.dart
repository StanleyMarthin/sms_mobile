/// Master dummy data for SM Workshop — based on ERD seed inserts.
///
/// These constants mirror the SQL seed data used by the backend and serve as
/// the single source of truth for local/offline-first mode.
library;

class _DummySeedDate {
  _DummySeedDate._();

  static DateTime get _base {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime at({int dayOffset = 0, int hour = 0, int minute = 0}) {
    return _base.add(
      Duration(days: dayOffset, hours: hour, minutes: minute),
    );
  }

  static String date({int dayOffset = 0}) =>
      _formatDate(at(dayOffset: dayOffset));

  static String time(int hour, [int minute = 0]) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static String shortDateTime({
    int dayOffset = 0,
    int hour = 0,
    int minute = 0,
  }) =>
      '${date(dayOffset: dayOffset)} ${time(hour, minute)}:00';

  static String isoDateTime({
    int dayOffset = 0,
    int hour = 0,
    int minute = 0,
  }) =>
      '${date(dayOffset: dayOffset)}T${time(hour, minute)}:00Z';

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

// ═══════════════════════════════════════════════════════════════
// sm_divisi
// ═══════════════════════════════════════════════════════════════

/// Division master data from `sm_divisi` table.
///
/// IDs and names match the production database exactly.
class DummyDivisions {
  DummyDivisions._();

  static const List<Map<String, dynamic>> all = [
    {'id': 0, 'name': 'DIREKSI', 'code': 'SM'},
    {'id': 1, 'name': 'MANAGEMENT', 'code': 'MSM'},
    {'id': 2, 'name': 'IT', 'code': 'IT'},
    {'id': 3, 'name': 'MANAGEMENT INFORMATION SYSTEM', 'code': 'MIS'},
    {'id': 4, 'name': 'DOKUMENTASI', 'code': 'DOC'},
    {'id': 5, 'name': 'CONTINUOUS IMPROVEMENT', 'code': 'CI'},
    {'id': 6, 'name': 'MECHANIC', 'code': 'MECYD'},
    {'id': 7, 'name': 'MECHANIC', 'code': 'MECFK'},
    {'id': 8, 'name': 'MECHANIC', 'code': 'MECIQ'},
    {'id': 9, 'name': 'MECHANIC', 'code': 'MECPR'},
    {'id': 10, 'name': 'BODY WORK', 'code': 'BDW'},
    {'id': 11, 'name': 'BODY PAINT', 'code': 'BDP'},
    {'id': 12, 'name': 'INTERIOR', 'code': 'INT'},
    {'id': 13, 'name': 'BUBUT', 'code': 'BBT'},
    {'id': 14, 'name': 'CHROME', 'code': 'CHR'},
    {'id': 15, 'name': 'PURCHASING', 'code': 'PRC'},
    {'id': 16, 'name': 'WAREHOUSE', 'code': 'WRH'},
    {'id': 17, 'name': 'MECHANIC', 'code': 'MECIM'},
  ];

  /// Lookup division ID by code.
  static int idOfCode(String code) =>
      all.firstWhere((d) => d['code'] == code, orElse: () => {'id': 1})['id']
          as int;

  /// Lookup division name by ID.
  static String nameOf(int id) => all.firstWhere((d) => d['id'] == id,
      orElse: () => {'name': 'UNKNOWN'})['name'] as String;
}

// ═══════════════════════════════════════════════════════════════
// sm_employee
// ═══════════════════════════════════════════════════════════════

/// Employee master data from `sm_employee` table.
///
/// Roles match `sm_role`: `pm`(15), `adv`(16), `kd`(17), `op`(18).
/// `employee_id` is the short name used for login (matches DB column).
/// `grade` matches DB column (HELPER III, TK. II, MECHANIC I, KEPALA DIVISI, ADVISOR, etc.).
/// `division_id` matches `sm_divisi.id` exactly from ERD.
/// `division` is the display name for the workshop area the employee works in.
class DummyEmployees {
  DummyEmployees._();

  static const List<Map<String, dynamic>> all = [
    // ── PM (role_id=15) — no employee in DB yet, placeholder ──
    {
      'id': 'pm-demo-001',
      'employee_id': 'HARDIAN',
      'full_name': 'HARDIAN',
      'role': 'pm',
      'division': 'MANAGEMENT',
      'divisionId': 1,
      'grade': 'PROJECT MANAGER',
      'password': 'pm123',
    },

    // ── Advisor (role_id=16, adv) ───────────────
    {
      'id': 'b3cc06eb-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'KANDI',
      'full_name': 'KANDI GUNAWAN',
      'role': 'adv',
      'division': 'MANAGEMENT',
      'divisionId': 1,
      'grade': 'ADVISOR',
      'password': 'adv123',
    },
    {
      'id': 'b3cc7ea8-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'RENDY',
      'full_name': 'SURYA RENDIWAZMAN',
      'role': 'adv',
      'division': 'MANAGEMENT',
      'divisionId': 1,
      'grade': 'ADVISOR',
      'password': 'adv123',
    },

    // ── KD / Kepala Divisi (role_id=17) ─────────
    {
      'id': 'b3cc9fab-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'YUDHA',
      'full_name': 'YUDHA AGUSTIANA',
      'role': 'kd',
      'division': 'MECHANIC',
      'divisionId': 6,
      'grade': 'KEPALA DIVISI',
      'password': 'kd123',
    },
    {
      'id': 'b3cbfe0d-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'IQBAL N',
      'full_name': 'IQBAL TAUFIK NURDIN',
      'role': 'kd',
      'division': 'MECHANIC',
      'divisionId': 8,
      'grade': 'KEPALA DIVISI',
      'password': 'kd123',
    },
    {
      'id': 'b3cc3cbc-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'PIKI',
      'full_name': 'PIKI HOERUL UMAM',
      'role': 'kd',
      'division': 'MECHANIC',
      'divisionId': 7,
      'grade': 'KEPALA DIVISI',
      'password': 'kd123',
    },
    {
      'id': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'RUHIAT',
      'full_name': 'RUHIAT SAEPULOH',
      'role': 'kd',
      'division': 'INTERIOR',
      'divisionId': 12,
      'grade': 'KEPALA DIVISI',
      'password': 'kd123',
    },
    {
      'id': 'b3cb2b95-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'ASEP MULYANA',
      'full_name': 'ASEP MULYANA',
      'role': 'kd',
      'division': 'BUBUT',
      'divisionId': 13,
      'grade': 'KEPALA DIVISI',
      'password': 'kd123',
    },

    {
      'id': 'b3cb2b95-op-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'UDIN BBT',
      'full_name': 'UDIN BUBUT',
      'role': 'op',
      'division': 'BUBUT',
      'divisionId': 13,
      'grade': 'MECHANIC II',
      'password': 'op123',
    },

    // ── Operator / Lapangan (role_id=18, op) — div_id=1 per ERD ──
    {
      'id': 'b3cb1075-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'ADAM',
      'full_name': 'ADAM HAFIYAN',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 6,
      'grade': 'HELPER III',
      'password': 'op123',
    },
    {
      'id': 'b3cb277a-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'ARIES',
      'full_name': 'ARIES RISFAN',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 7,
      'grade': 'MECHANIC I',
      'password': 'op123',
    },
    {
      'id': 'b3cb75bf-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'MAULANA',
      'full_name': 'DIAN MAULANA MAKBUL',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 8,
      'grade': 'MECHANIC I',
      'password': 'op123',
    },
    {
      'id': 'b3cb2954-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'ASEP',
      'full_name': 'ASEP KAMALUDIN',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 6,
      'grade': 'MECHANIC III',
      'password': 'op123',
    },
    {
      'id': 'b3cbf5d6-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'INDRA',
      'full_name': 'INDRA SUPRAPTO',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 8,
      'grade': 'MECHANIC II',
      'password': 'op123',
    },
    {
      'id': 'b3cc381a-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'NURSYAHID',
      'full_name': 'NURSYAHID',
      'role': 'op',
      'division': 'MECHANIC',
      'divisionId': 9,
      'grade': 'MECHANIC I',
      'password': 'op123',
    },

    // ── op — BODY WORK div (id=10) ─────────────
    {
      'id': 'b3cb1c6d-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'ADE',
      'full_name': 'ADE ROSANDI',
      'role': 'op',
      'division': 'BODY WORK',
      'divisionId': 10,
      'grade': 'TK. II',
      'password': 'op123',
    },
    {
      'id': 'b3cb1f0d-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'AGUS H',
      'full_name': 'AGUS HERMAYANDI',
      'role': 'op',
      'division': 'BODY WORK',
      'divisionId': 10,
      'grade': 'TK. III',
      'password': 'op123',
    },
    {
      'id': 'b3cc0caa-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'FAISAL',
      'full_name': 'MOCHAMAD SANDI FAISAL',
      'role': 'op',
      'division': 'BODY WORK',
      'divisionId': 10,
      'grade': 'HELPER I',
      'password': 'op123',
    },

    // ── op — INTERIOR div (id=12) ──────────────
    {
      'id': 'b3cb2386-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'AGUS R',
      'full_name': 'AGUS RUSMAWAN',
      'role': 'op',
      'division': 'INTERIOR',
      'divisionId': 12,
      'grade': 'HELPER III',
      'password': 'op123',
    },
    {
      'id': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'TARUNO',
      'full_name': 'TARUNO',
      'role': 'op',
      'division': 'INTERIOR',
      'divisionId': 12,
      'grade': 'TK. III',
      'password': 'op123',
    },

    // ── op — BODY PAINT div (id=11) ────────────
    {
      'id': 'b3cb6796-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'DENDI',
      'full_name': 'DENDI MULYADI',
      'role': 'op',
      'division': 'BODY PAINT',
      'divisionId': 11,
      'grade': 'TK. II',
      'password': 'op123',
    },
    {
      'id': 'b3cc4da5-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'RIZKY',
      'full_name': 'RIZKI RAHMADI',
      'role': 'op',
      'division': 'BODY PAINT',
      'divisionId': 11,
      'grade': 'TK. III',
      'password': 'op123',
    },

    // ── op — CHROME div (id=14) ────────────────
    {
      'id': 'b3cc54ae-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'SAMBAS',
      'full_name': 'SAMBAS NURHIKAM',
      'role': 'op',
      'division': 'CHROME',
      'divisionId': 14,
      'grade': 'HELPER II',
      'password': 'op123',
    },

    // ── op — WAREHOUSE div (id=16) ─────────────
    {
      'id': 'b3cb2d73-179b-11f1-8701-94e6f79805fd',
      'employee_id': 'BRIYAN',
      'full_name': 'BRIYAN',
      'role': 'op',
      'division': 'WAREHOUSE',
      'divisionId': 16,
      'grade': null,
      'password': 'op123',
    },
  ];
}

// ═══════════════════════════════════════════════════════════════
// cars
// ═══════════════════════════════════════════════════════════════

/// Car / project master data from `cars` table.
///
/// IDs match the production database (format: UNITNAME_CUSTOMER).
class DummyCars {
  DummyCars._();

  static const List<Map<String, dynamic>> all = [
    {
      'id': 'CHEVROLET_MRNYOMAN',
      'unit_name': 'CHEVROLET',
      'customer_name': 'Mr. NYOMAN',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2024-02-12',
      'status': 'In_Progress',
    },
    {
      'id': 'FERRARIF355_MRSILMY',
      'unit_name': 'FERRARI F355',
      'customer_name': 'Mr. SILMY',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2025-08-14',
      'status': 'In_Progress',
    },
    {
      'id': 'FIATMULTIPLA_MRJOKO',
      'unit_name': 'FIAT MULTIPLA',
      'customer_name': 'Mr. JOKO',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2026-03-01',
      'status': 'In_Progress',
    },
    {
      'id': 'JAGUARXK120_MRJAMES',
      'unit_name': 'JAGUAR XK120',
      'customer_name': 'Mr. JAMES',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2022-07-07',
      'status': 'In_Progress',
    },
    {
      'id': 'MB190SL_MRADRIAN',
      'unit_name': 'MB 190 SL',
      'customer_name': 'Mr. ADRIAN',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2018-01-17',
      'status': 'In_Progress',
    },
    {
      'id': 'MB500SEL_MRSILMY',
      'unit_name': 'MB 500 SEL',
      'customer_name': 'Mr. SILMY',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2023-07-11',
      'status': 'In_Progress',
    },
    {
      'id': 'MBBATMAN_MRICHSAN',
      'unit_name': 'MB BATMAN',
      'customer_name': 'Mr. ICHSAN',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2024-08-07',
      'status': 'In_Progress',
    },
    {
      'id': 'MBR129_MRDIKO',
      'unit_name': 'MB R129',
      'customer_name': 'Mr. DIKO',
      'is_margin': true,
      'restoration_type': 'General',
      'status': 'In_Progress',
    },
    {
      'id': 'PORSCHE911_MRHANDY',
      'unit_name': 'PORSCHE 911',
      'customer_name': 'Mr. HANDY',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2021-08-06',
      'status': 'In_Progress',
    },
    {
      'id': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unit_name': 'MB W124 E320 SPORTLINE',
      'customer_name': 'Mr. MARTHIN',
      'is_margin': true,
      'restoration_type': 'General',
      'status': 'In_Progress',
    },
    {
      'id': 'MB300D_MRHERRY',
      'unit_name': 'MB 300 D',
      'customer_name': 'Mr. HERRY',
      'is_margin': true,
      'restoration_type': 'General',
      'incoming_date': '2023-03-01',
      'status': 'In_Progress',
    },
  ];
}

// ═══════════════════════════════════════════════════════════════
// sm_qc_inspections support dummy data
// ═══════════════════════════════════════════════════════════════

/// QC inspection dummy rows aligned to `sm_qc_inspections` and related masters.
///
/// Uses car names and employee names that exist in the DB backup so QC screens
/// stay consistent with the single dummy source in this file.
class QcDummyData {
  QcDummyData._();

  static final List<Map<String, dynamic>> _all = [
    {
      'qcId': 'qc-int-f355-dashboard',
      'coreId': 'CD-INT-F355-001',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'panelName': 'DASHBOARD DEPAN',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'mechanicId': 'b3cbf19f-179b-11f1-8701-94e6f79805fd',
      'mechanicName': 'HARIS',
      'mechanicDivision': 'INTERIOR',
      'inspectorId': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'advisorId': 'b3cc06eb-179b-11f1-8701-94e6f79805fd',
      'inspectionDate': _DummySeedDate.shortDateTime(hour: 14, minute: 30),
      'totalActualHours': 10.0,
      'targetHoursRevised': 10.0,
      'qcStatus': 'PENDING',
      'date': _DummySeedDate.date(),
      'qcChecklist': [
        {'item': 'Jahitan lurus dan rapih', 'passed': true},
        {'item': 'Cover tidak bergelombang', 'passed': true},
        {'item': 'Fitting dashboard ke bracket', 'passed': null},
        {'item': 'Finishing list dan trim', 'passed': null},
      ],
      'qcNotes': null,
    },
    {
      'qcId': 'qc-int-w124-seat',
      'coreId': 'CD-INT-W124-001',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'panelName': 'DUDUKAN JOK DEPAN RH',
      'jobName': 'PEMASANGAN BUSA PELAPIS',
      'mechanicId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'mechanicName': 'TARUNO',
      'mechanicDivision': 'INTERIOR',
      'inspectorId': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'advisorId': 'b3cc7ea8-179b-11f1-8701-94e6f79805fd',
      'inspectionDate': _DummySeedDate.shortDateTime(dayOffset: -1, hour: 15),
      'totalActualHours': 8.0,
      'targetHoursRevised': 8.0,
      'qcStatus': 'APPROVED',
      'date': _DummySeedDate.date(dayOffset: -1),
      'qcChecklist': [
        {'item': 'Busa padat dan rata', 'passed': true},
        {'item': 'Pola cover sesuai kontur', 'passed': true},
        {'item': 'Pemasangan cover presisi', 'passed': true},
        {'item': 'Finishing jok bersih', 'passed': true},
      ],
      'qcNotes': 'QC lolos tanpa rework.',
    },
    {
      'qcId': 'qc-int-f355-seat-rework',
      'coreId': 'CD-INT-F355-004',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'panelName': 'DUDUKAN JOK DEPAN RH',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'mechanicId': 'b3cb2386-179b-11f1-8701-94e6f79805fd',
      'mechanicName': 'AGUS RUSMAWAN',
      'mechanicDivision': 'INTERIOR',
      'inspectorId': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'advisorId': 'b3cc06eb-179b-11f1-8701-94e6f79805fd',
      'inspectionDate':
          _DummySeedDate.shortDateTime(dayOffset: -1, hour: 11, minute: 30),
      'totalActualHours': 7.0,
      'targetHoursRevised': 7.0,
      'qcStatus': 'REWORK',
      'date': _DummySeedDate.date(dayOffset: -1),
      'qcChecklist': [
        {'item': 'Jahitan sisi kanan', 'passed': true},
        {'item': 'Tarikan cover dudukan', 'passed': false},
        {'item': 'Kerapihan pinggir cover', 'passed': false},
        {'item': 'Kebersihan finishing', 'passed': true},
      ],
      'qcNotes': 'Tarikan cover belum rata, perlu rework 2 jam.',
    },
    {
      'qcId': 'qc-int-w124-plafon',
      'coreId': 'CD-INT-W124-002',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'panelName': 'KAIN PLAFON',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'mechanicId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'mechanicName': 'TARUNO',
      'mechanicDivision': 'INTERIOR',
      'inspectorId': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'advisorId': 'b3cc06eb-179b-11f1-8701-94e6f79805fd',
      'inspectionDate': _DummySeedDate.shortDateTime(hour: 16, minute: 15),
      'totalActualHours': 6.0,
      'targetHoursRevised': 6.0,
      'qcStatus': 'VALIDATED_ADV',
      'date': _DummySeedDate.date(),
      'qcChecklist': [
        {'item': 'Tarikan kain plafon rata', 'passed': true},
        {'item': 'Lem merata', 'passed': true},
        {'item': 'Finishing pinggir plafon', 'passed': true},
        {'item': 'Kebersihan area kerja', 'passed': true},
      ],
      'qcNotes': 'Menunggu final validate PM.',
    },
  ];

  static List<Map<String, dynamic>> allForDate({required String date}) {
    return _all
        .where((item) => item['date'] == date)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<Map<String, dynamic>> seedAll() =>
      _all.map((item) => Map<String, dynamic>.from(item)).toList();

  static List<Map<String, dynamic>> forDivision(String division,
      {required String date}) {
    return _all
        .where((item) => item['date'] == date)
        .where((item) => item['mechanicDivision'] == division)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// sm_jobdesc_plan support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyJobPlans {
  DummyJobPlans._();

  static final List<Map<String, dynamic>> _all = [
    {
      'planId': 'plan-int-f355-doortrim',
      'coreId': 'CD-INT-F355-002',
      'carId': 'FERRARIF355_MRSILMY',
      'sourceType': 'COUNTDOWN',
      'sourceRefId': 'CD-INT-F355-002',
      'unitName': 'FERRARI F355',
      'panelName': 'DOORTRIM DEPAN LH',
      'assignedDivision': 'INTERIOR',
      'assignedUserId': 'b3cbf19f-179b-11f1-8701-94e6f79805fd',
      'assignedTo': 'HARIS',
      'description':
          'PENJAHITAN COVER / KAIN dan pemasangan doortrim depan kiri.',
      'targetHours': 4.0,
      'workDate': _DummySeedDate.date(),
      'startTime': '08:00',
      'finishTime': '12:00',
      'isOvertime': false,
      'deadline': _DummySeedDate.date(),
      'status': 'APPROVED',
      'note': 'Siap dieksekusi hari ini.',
    },
    {
      'planId': 'plan-int-w124-plafon',
      'coreId': 'CD-INT-W124-002',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'sourceType': 'COUNTDOWN',
      'sourceRefId': 'CD-INT-W124-002',
      'unitName': 'MB W124 E320 SPORTLINE',
      'panelName': 'KAIN PLAFON',
      'assignedDivision': 'INTERIOR',
      'assignedUserId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'assignedTo': 'TARUNO',
      'description': 'PEMASANGAN COVER / KAIN untuk plafon unit W124.',
      'targetHours': 3.0,
      'workDate': _DummySeedDate.date(),
      'startTime': '09:00',
      'finishTime': '12:00',
      'isOvertime': false,
      'deadline': _DummySeedDate.date(),
      'status': 'PENDING_PM',
      'note': 'Sudah lolos review advisor, tunggu PM.',
    },
    {
      'planId': 'plan-int-f355-seat-rework',
      'coreId': 'CD-INT-F355-004',
      'carId': 'FERRARIF355_MRSILMY',
      'sourceType': 'COUNTDOWN',
      'sourceRefId': 'CD-INT-F355-004',
      'unitName': 'FERRARI F355',
      'panelName': 'DUDUKAN JOK DEPAN RH',
      'assignedDivision': 'INTERIOR',
      'assignedUserId': 'b3cb2386-179b-11f1-8701-94e6f79805fd',
      'assignedTo': 'AGUS RUSMAWAN',
      'description': 'REWORK pemasangan cover jok depan kanan hasil QC reject.',
      'targetHours': 2.0,
      'workDate': _DummySeedDate.date(dayOffset: 1),
      'startTime': '08:00',
      'finishTime': '10:00',
      'isOvertime': true,
      'deadline': _DummySeedDate.date(dayOffset: 1),
      'status': 'PENDING_ADV',
      'note': 'Rework wajib selesai sebelum QC ulang.',
    },
    {
      'planId': 'plan-int-additional-p3k',
      'coreId': '',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'sourceType': 'ADDITIONAL',
      'sourceRefId': '',
      'unitName': 'MB W124 E320 SPORTLINE',
      'panelName': 'KOTAK P3K',
      'assignedDivision': 'INTERIOR',
      'assignedUserId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'assignedTo': 'TARUNO',
      'description': 'CLEANING PART dan perapihan kotak P3K tambahan.',
      'targetHours': 2.5,
      'workDate': _DummySeedDate.date(dayOffset: 1),
      'startTime': '13:00',
      'finishTime': '15:30',
      'isOvertime': false,
      'deadline': _DummySeedDate.date(dayOffset: 1),
      'status': 'REJECTED',
      'note': 'Deskripsi perlu diperjelas sebelum diajukan ulang.',
    },
  ];

  static List<Map<String, dynamic>> seedPlans() =>
      _all.map((item) => Map<String, dynamic>.from(item)).toList();
}

// ═══════════════════════════════════════════════════════════════
// sm_jobdesc_countdown support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyCountdownData {
  DummyCountdownData._();

  static final List<Map<String, dynamic>> _units = [
    {
      'carId': 'FIATMULTIPLA_MRJOKO',
      'unitName': 'FIAT MULTIPLA',
      'owner': 'Mr. JOKO',
      'progress': 0,
      'status': 'PLAN',
      'division': 'INTERIOR',
      'deliveryDate': '2026-06-30',
    },
    {
      'carId': 'MB500SEL_MRSILMY',
      'unitName': 'MB 500 SEL',
      'owner': 'Mr. SILMY',
      'progress': 0,
      'status': 'PLAN',
      'division': 'INTERIOR',
      'deliveryDate': '2026-08-15',
    },
  ];

  static final Map<String, List<Map<String, dynamic>>> _countdowns = {
    'FIATMULTIPLA_MRJOKO': [
      _countdownSeed(
        id: 'CD-INT-FIAT-001',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-01',
        deadlineDate: '2026-03-02',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-002',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'REPAIR PART / RANGKA',
        targetHoursInitial: 8.0,
        timeExtensionHours: 2.0,
        targetHoursRevised: 10.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-04',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-003',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'PEMASANGAN BUSA PELAPIS',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-04',
        deadlineDate: '2026-03-05',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-004',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-05',
        deadlineDate: '2026-03-06',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-005',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'PENJAHITAN COVER / KAIN',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-08',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-006',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'PEMASANGAN COVER / KAIN',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-09',
        deadlineDate: '2026-03-10',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-007',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DASHBOARD DEPAN',
        sectionName: 'I. DASHBOARD DEPAN',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-10',
        deadlineDate: '2026-03-11',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-008',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-01',
        deadlineDate: '2026-03-01',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-009',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'CLEANING PART',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-02',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-010',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'REPAIR PART / RANGKA',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-03',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-011',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PEMBENTUKAN BUSA',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-03',
        deadlineDate: '2026-03-05',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-012',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'SANDING PERAPIHAN',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-05',
        deadlineDate: '2026-03-06',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-013',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-07',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-014',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PEMOTONGAN BAHAN KAIN / KULIT',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-07',
        deadlineDate: '2026-03-08',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-015',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PENJAHITAN COVER / KAIN',
        targetHoursInitial: 10.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 10.0,
        startDate: '2026-03-08',
        deadlineDate: '2026-03-10',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-016',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'PEMASANGAN COVER / KAIN',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-11',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-017',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'DUDUKAN JOK DEPAN RH',
        sectionName: 'VI. SEAT JOK DEPAN',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-12',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-018',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-02',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-019',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'CLEANING PART',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-03',
        deadlineDate: '2026-03-03',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-020',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-04',
        deadlineDate: '2026-03-05',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-021',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'PEMBUATAN LUBANG / JALUR NAT',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-07',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-022',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'PEMOTONGAN BAHAN KAIN / KULIT',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-08',
        deadlineDate: '2026-03-09',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-023',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'PEMASANGAN PART KE UNIT',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-10',
        deadlineDate: '2026-03-11',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-024',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'KARPET LANTAI BAGIAN DEPAN RH',
        sectionName: 'III. KARPET LANTAI INTERIOR',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-12',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-025',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'PEREDAM LANTAI DEPAN RH',
        sectionName: 'PEREDAM',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-01',
        deadlineDate: '2026-03-01',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-026',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'PEREDAM LANTAI DEPAN RH',
        sectionName: 'PEREDAM',
        jobdesc: 'PEMOTONGAN BAHAN KAIN / KULIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-02',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-027',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'PEREDAM LANTAI DEPAN RH',
        sectionName: 'PEREDAM',
        jobdesc: 'PEMASANGAN PART KE UNIT',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-03',
        deadlineDate: '2026-03-04',
      ),
      _countdownSeed(
        id: 'CD-INT-FIAT-028',
        carId: 'FIATMULTIPLA_MRJOKO',
        panelName: 'PEREDAM LANTAI DEPAN RH',
        sectionName: 'PEREDAM',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-05',
        deadlineDate: '2026-03-05',
      ),
    ],
    'MB500SEL_MRSILMY': [
      _countdownSeed(
        id: 'CD-INT-MB500-001',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-01',
        deadlineDate: '2026-03-02',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-002',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'CLEANING PART',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-02',
        deadlineDate: '2026-03-03',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-003',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-03',
        deadlineDate: '2026-03-04',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-004',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEWARNAAN BAHAN',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-04',
        deadlineDate: '2026-03-06',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-005',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEMOTONGAN BAHAN KAIN / KULIT',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-07',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-006',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PENJAHITAN COVER / KAIN',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-07',
        deadlineDate: '2026-03-09',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-007',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEMASANGAN BUSA PELAPIS',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-10',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-008',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'PEMASANGAN PART KE UNIT',
        targetHoursInitial: 12.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 12.0,
        startDate: '2026-03-13',
        deadlineDate: '2026-03-15',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-009',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KAIN PLAFON',
        sectionName: 'V. PLAFON',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-15',
        deadlineDate: '2026-03-16',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-010',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-05',
        deadlineDate: '2026-03-05',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-011',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'CLEANING PART',
        targetHoursInitial: 3.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 3.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-06',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-012',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'REPAIR PART / RANGKA',
        targetHoursInitial: 6.0,
        timeExtensionHours: 2.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-07',
        deadlineDate: '2026-03-09',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-013',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'SANDING PERAPIHAN',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-10',
        deadlineDate: '2026-03-10',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-014',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'PEMBUATAN POLA',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-11',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-015',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'PEMOTONGAN BAHAN KAIN / KULIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-12',
        deadlineDate: '2026-03-12',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-016',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'PENJAHITAN COVER / KAIN',
        targetHoursInitial: 8.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 8.0,
        startDate: '2026-03-13',
        deadlineDate: '2026-03-14',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-017',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'PEMASANGAN COVER / KAIN',
        targetHoursInitial: 6.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 6.0,
        startDate: '2026-03-15',
        deadlineDate: '2026-03-16',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-018',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'DOORTRIM DEPAN RH',
        sectionName: 'VIII. DOORTRIM',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-17',
        deadlineDate: '2026-03-17',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-019',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KOTAK P3K',
        sectionName: 'II. DASHBORD BELAKANG',
        jobdesc: 'PEMBONGKARAN / PELEPASAN PART',
        targetHoursInitial: 1.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 1.0,
        startDate: '2026-03-06',
        deadlineDate: '2026-03-06',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-020',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KOTAK P3K',
        sectionName: 'II. DASHBORD BELAKANG',
        jobdesc: 'REPAIR PART / RANGKA',
        targetHoursInitial: 2.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 2.0,
        startDate: '2026-03-07',
        deadlineDate: '2026-03-07',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-021',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KOTAK P3K',
        sectionName: 'II. DASHBORD BELAKANG',
        jobdesc: 'PEMASANGAN COVER / KAIN',
        targetHoursInitial: 4.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 4.0,
        startDate: '2026-03-08',
        deadlineDate: '2026-03-09',
      ),
      _countdownSeed(
        id: 'CD-INT-MB500-022',
        carId: 'MB500SEL_MRSILMY',
        panelName: 'KOTAK P3K',
        sectionName: 'II. DASHBORD BELAKANG',
        jobdesc: 'FITTING PART KE UNIT',
        targetHoursInitial: 1.0,
        timeExtensionHours: 0.0,
        targetHoursRevised: 1.0,
        startDate: '2026-03-10',
        deadlineDate: '2026-03-10',
      ),
    ],
  };

  static final Map<String, List<Map<String, dynamic>>> _details = {};

  static Map<String, dynamic> _countdownSeed({
    required String id,
    required String carId,
    required String panelName,
    required String sectionName,
    required String jobdesc,
    required double targetHoursInitial,
    required double timeExtensionHours,
    required double targetHoursRevised,
    required String startDate,
    required String deadlineDate,
  }) {
    return {
      'id': id,
      'carId': carId,
      'panelName': panelName,
      'sectionName': sectionName,
      'jobdesc': jobdesc,
      'taskCategory': 'MAIN',
      'targetHoursInitial': targetHoursInitial,
      'timeExtensionHours': timeExtensionHours,
      'targetHoursRevised': targetHoursRevised,
      'totalActualHours': 0.0,
      'remainingHours': targetHoursRevised,
      'actualProgressPercent': 0,
      'status': 'PLAN',
      'qcLastStatus': null,
      'startDate': startDate,
      'deadlineDate': deadlineDate,
    };
  }

  static List<Map<String, dynamic>> units() =>
      _units.map((item) => Map<String, dynamic>.from(item)).toList();

  static Map<String, List<Map<String, dynamic>>> seedCountdowns() =>
      _countdowns.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => Map<String, dynamic>.from(item)).toList(),
        ),
      );

  static Map<String, List<Map<String, dynamic>>> seedDetails() => _details.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => Map<String, dynamic>.from(item)).toList(),
        ),
      );

  static List<Map<String, dynamic>> countdownsForCar(String carId) =>
      seedCountdowns()[carId] ?? <Map<String, dynamic>>[];

  static List<Map<String, dynamic>> detailsForCountdown(String countdownId) =>
      seedDetails()
          .values
          .expand((items) => items)
          .where((item) => item['countdownId'] == countdownId)
          .toList();
}

// ═══════════════════════════════════════════════════════════════
// summary_division_monitoring support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyMonitoringData {
  DummyMonitoringData._();

  static final List<Map<String, dynamic>> _cars = [
    {
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'owner': 'Mr. SILMY',
      'isMargin': true,
      'avgProgressPercentage': 78,
      'status': 'IN_PROGRESS',
      'remainingWorkHours': 512.0,
      'projectStartDate': '2023-07-11',
      'deliveryDate': '2026-05-30',
      'lastUpdateDate': '2026-03-11',
      'nextMilestone': 'Body paint final + interior finishing lock 15 April',
      'divisions': [
        {
          'divisionName': 'BODY WORK',
          'progressPercentage': 42,
          'weeklyWorkHours': 56.0,
          'remainingHours': 210.0,
          'blockedJobs': 3,
          'overdueJobs': 4,
          'forecastFinishDate': '2026-04-28',
          'note': 'Panel gap dan alignment pintu belum stabil.',
        },
        {
          'divisionName': 'BODY PAINT',
          'progressPercentage': 55,
          'weeklyWorkHours': 48.0,
          'remainingHours': 132.0,
          'blockedJobs': 2,
          'overdueJobs': 3,
          'forecastFinishDate': '2026-05-12',
          'note': 'Menunggu release panel dari body work.',
        },
        {
          'divisionName': 'INTERIOR',
          'progressPercentage': 88,
          'weeklyWorkHours': 42.0,
          'remainingHours': 70.0,
          'blockedJobs': 0,
          'overdueJobs': 1,
          'forecastFinishDate': '2026-04-10',
          'note': 'Tinggal fitting final dashboard dan jok depan.',
        },
        {
          'divisionName': 'CHROME',
          'progressPercentage': 35,
          'weeklyWorkHours': 24.0,
          'remainingHours': 100.0,
          'blockedJobs': 1,
          'overdueJobs': 2,
          'forecastFinishDate': '2026-05-20',
          'note': 'Vendor chrome masih tunggu batch finishing.',
        },
      ],
    },
    {
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'owner': 'Mr. MARTHIN',
      'isMargin': false,
      'avgProgressPercentage': 91,
      'status': 'IN_PROGRESS',
      'remainingWorkHours': 228.0,
      'projectStartDate': '2024-01-15',
      'deliveryDate': '2026-10-15',
      'lastUpdateDate': '2026-03-12',
      'nextMilestone': 'QC final interior dan assembly road test 20 April',
      'divisions': [
        {
          'divisionName': 'BODY WORK',
          'progressPercentage': 74,
          'weeklyWorkHours': 44.0,
          'remainingHours': 66.0,
          'blockedJobs': 0,
          'overdueJobs': 1,
          'forecastFinishDate': '2026-04-08',
          'note': 'Minor correction area bagasi.',
        },
        {
          'divisionName': 'BODY PAINT',
          'progressPercentage': 83,
          'weeklyWorkHours': 38.0,
          'remainingHours': 52.0,
          'blockedJobs': 0,
          'overdueJobs': 0,
          'forecastFinishDate': '2026-04-12',
          'note': 'Masuk polishing dan final buffing.',
        },
        {
          'divisionName': 'INTERIOR',
          'progressPercentage': 96,
          'weeklyWorkHours': 30.0,
          'remainingHours': 16.0,
          'blockedJobs': 0,
          'overdueJobs': 0,
          'forecastFinishDate': '2026-03-28',
          'note': 'Sudah masuk touch up kecil dan cleaning.',
        },
        {
          'divisionName': 'CHROME',
          'progressPercentage': 70,
          'weeklyWorkHours': 34.0,
          'remainingHours': 94.0,
          'blockedJobs': 1,
          'overdueJobs': 0,
          'forecastFinishDate': '2026-04-18',
          'note': 'Satu garnish depan masih vendor repair.',
        },
      ],
    },
    {
      'carId': 'CHEVROLET_MRNYOMAN',
      'unitName': 'CHEVROLET',
      'owner': 'Mr. NYOMAN',
      'isMargin': true,
      'avgProgressPercentage': 36,
      'status': 'IN_PROGRESS',
      'remainingWorkHours': 740.0,
      'projectStartDate': '2022-02-12',
      'deliveryDate': '2026-07-31',
      'lastUpdateDate': '2026-03-05',
      'nextMilestone': 'Lock scope tambahan body shell dan electrical audit',
      'divisions': [
        {
          'divisionName': 'BODY WORK',
          'progressPercentage': 36,
          'weeklyWorkHours': 52.0,
          'remainingHours': 280.0,
          'blockedJobs': 5,
          'overdueJobs': 6,
          'forecastFinishDate': '2026-06-25',
          'note': 'Panel bawah dan floor pan masih corrective fabrication.',
        },
        {
          'divisionName': 'BODY PAINT',
          'progressPercentage': 18,
          'weeklyWorkHours': 40.0,
          'remainingHours': 260.0,
          'blockedJobs': 4,
          'overdueJobs': 5,
          'forecastFinishDate': '2026-07-18',
          'note': 'Belum bisa masuk penuh sebelum body shell lock.',
        },
        {
          'divisionName': 'INTERIOR',
          'progressPercentage': 22,
          'weeklyWorkHours': 36.0,
          'remainingHours': 200.0,
          'blockedJobs': 2,
          'overdueJobs': 3,
          'forecastFinishDate': '2026-07-05',
          'note': 'Dashboard core part masih menunggu refurbish vendor.',
        },
      ],
    },
  ];

  static List<Map<String, dynamic>> cars() =>
      _cars.map((item) => Map<String, dynamic>.from(item)).map((item) {
        item['divisions'] = (item['divisions'] as List)
            .map((division) => Map<String, dynamic>.from(division as Map))
            .toList();
        return item;
      }).toList();
}

// ═══════════════════════════════════════════════════════════════
// notifications support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyNotificationsData {
  DummyNotificationsData._();

  static final List<Map<String, dynamic>> _items = [
    {
      'id': 'notif-qc-001',
      'title': 'QC Menunggu KD',
      'body': 'Dashboard depan Ferrari F355 siap checkpoint KD.',
      'isRead': false,
      'createdAt': _DummySeedDate.shortDateTime(hour: 16, minute: 10),
      'targetRoute':
          '/qc?qcId=qc-int-f355-dashboard&date=${_DummySeedDate.date()}',
      'roles': ['kd'],
    },
    {
      'id': 'notif-plan-001',
      'title': 'Plan Disetujui',
      'body': 'Task doortrim Ferrari F355 untuk HARIS sudah approved.',
      'isRead': true,
      'createdAt': _DummySeedDate.shortDateTime(hour: 7, minute: 45),
      'targetRoute': '/plans',
      'roles': ['op'],
    },
    {
      'id': 'notif-wo-001',
      'title': 'WO Menunggu Advisor',
      'body': 'Request chrome garnish Ferrari F355 menunggu approval advisor.',
      'isRead': false,
      'createdAt': _DummySeedDate.shortDateTime(hour: 9, minute: 15),
      'targetRoute': '/work-orders?woId=wo-int-f355-chrome',
      'roles': ['adv', 'pm'],
    },
    {
      'id': 'notif-wh-001',
      'title': 'Warehouse Approved',
      'body': 'Lem khusus interior untuk HARIS sudah disetujui KD.',
      'isRead': true,
      'createdAt':
          _DummySeedDate.shortDateTime(dayOffset: -1, hour: 15, minute: 20),
      'targetRoute': '/warehouse',
      'roles': ['op', 'kd'],
    },
    {
      'id': 'notif-monitoring-001',
      'title': 'Monitoring Update',
      'body': 'Progress Ferrari F355 naik menjadi 78%.',
      'isRead': true,
      'createdAt':
          _DummySeedDate.shortDateTime(dayOffset: -1, hour: 8, minute: 45),
      'targetRoute': '/monitoring?carId=FERRARIF355_MRSILMY',
      'roles': ['kd', 'adv', 'pm'],
    },
  ];

  static List<Map<String, dynamic>> all() =>
      _items.map((item) => Map<String, dynamic>.from(item)).toList();
}

// ═══════════════════════════════════════════════════════════════
// sm_warehouse support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyWarehouseData {
  DummyWarehouseData._();

  static final List<Map<String, dynamic>> _logs = [
    {
      'id': 'wh-int-001',
      'transactionType': 'PEMINJAMAN',
      'itemCategory': 'TOOLS',
      'carId': 'FERRARIF355_MRSILMY',
      'coreId': 'CD-INT-F355-002',
      'employeeId': 'b3cbf19f-179b-11f1-8701-94e6f79805fd',
      'requester': 'HARIS',
      'divisionId': 12,
      'division': 'INTERIOR',
      'itemName': 'Heat Gun',
      'qty': 1,
      'uom': 'PCS',
      'requestDate': _DummySeedDate.at(dayOffset: -1, hour: 8),
      'itemStatus': 'RELEASED',
      'approvalStatus': 'APPROVED',
      'notes': 'Untuk pemasangan cover doortrim.',
    },
    {
      'id': 'wh-int-002',
      'transactionType': 'PENGAMBILAN',
      'itemCategory': 'BAHAN',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'coreId': 'CD-INT-W124-002',
      'employeeId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
      'requester': 'TARUNO',
      'divisionId': 12,
      'division': 'INTERIOR',
      'itemName': 'Lem Kuning Interior',
      'qty': 2,
      'uom': 'KALENG',
      'requestDate': _DummySeedDate.at(hour: 9, minute: 30),
      'itemStatus': 'OPEN',
      'approvalStatus': 'PENDING_KD',
      'notes': 'Untuk pemasangan plafon W124.',
    },
    {
      'id': 'wh-int-003',
      'transactionType': 'PENGAMBILAN',
      'itemCategory': 'BAHAN',
      'carId': 'FERRARIF355_MRSILMY',
      'coreId': 'CD-INT-F355-004',
      'employeeId': 'b3cb2386-179b-11f1-8701-94e6f79805fd',
      'requester': 'AGUS RUSMAWAN',
      'divisionId': 12,
      'division': 'INTERIOR',
      'itemName': 'Benang Jahit Kulit',
      'qty': 3,
      'uom': 'ROLL',
      'requestDate': _DummySeedDate.at(dayOffset: -1, hour: 10),
      'itemStatus': 'OPEN',
      'approvalStatus': 'APPROVED',
      'notes': 'Dipakai untuk rework jok depan kanan.',
    },
    {
      'id': 'wh-int-004',
      'transactionType': 'PEMINJAMAN',
      'itemCategory': 'TOOLS',
      'carId': 'FERRARIF355_MRSILMY',
      'coreId': 'CD-INT-F355-001',
      'employeeId': 'b3cbf19f-179b-11f1-8701-94e6f79805fd',
      'requester': 'HARIS',
      'divisionId': 12,
      'division': 'INTERIOR',
      'itemName': 'Staple Gun',
      'qty': 1,
      'uom': 'PCS',
      'requestDate': _DummySeedDate.at(dayOffset: -2, hour: 8),
      'itemStatus': 'RETURNED',
      'approvalStatus': 'APPROVED',
      'notes': 'Aman tidak ada kerusakan',
      'returnDate': _DummySeedDate.at(dayOffset: -1, hour: 17),
    },
  ];

  static List<Map<String, dynamic>> seedLogs() =>
      _logs.map((item) => Map<String, dynamic>.from(item)).toList();
}

// ═══════════════════════════════════════════════════════════════
// sm_jobdesc_wo support dummy data
// ═══════════════════════════════════════════════════════════════

class DummyWorkOrders {
  DummyWorkOrders._();

  static final List<Map<String, dynamic>> _records = [
    {
      'id': 'wo-int-f355-chrome',
      'woNumber': 'WO/INT/2026/0042',
      'woType': 'WO',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'ownerName': 'Mr. SILMY',
      'panelName': 'DASHBOARD DEPAN',
      'partName': 'Garnish Dashboard',
      'jobdescName': 'Poles dan Rechrome',
      'coreId': 'CD-INT-F355-001',
      'description': 'Poles ulang garnish chrome dashboard depan.',
      'fromDivision': 'INTERIOR',
      'toDivision': 'CHROME',
      'estimatedHours': 4.0,
      'priority': 'NORMAL',
      'status': 'PENDING_ADVISOR',
      'notes': 'Garnish sudah dilepas dan siap dikirim ke chrome.',
      'requestedById': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'requestedByName': 'RUHIAT SAEPULOH',
      'createdAt': _DummySeedDate.isoDateTime(hour: 8),
      'deadline': _DummySeedDate.date(dayOffset: 3),
    },
    {
      'id': 'wo-int-w124-bubut',
      'woNumber': 'WO/INT/2026/0043',
      'woType': 'WO',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'ownerName': 'Mr. MARTHIN',
      'panelName': 'DASHBOARD DEPAN',
      'partName': 'Dudukan Asbak',
      'jobdescName': 'Bubut Dudukan',
      'coreId': 'CD-INT-W124-003',
      'description': 'Bubut dudukan kecil asbak dashboard depan.',
      'fromDivision': 'INTERIOR',
      'toDivision': 'BUBUT',
      'estimatedHours': 2.0,
      'priority': 'HIGH',
      'status': 'PENDING_PM',
      'notes': 'Sudah disetujui advisor, tinggal final PM.',
      'requestedById': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'requestedByName': 'RUHIAT SAEPULOH',
      'createdAt':
          _DummySeedDate.isoDateTime(dayOffset: -1, hour: 9, minute: 30),
      'deadline': _DummySeedDate.date(dayOffset: 2),
      'advisorApprovedAt': _DummySeedDate.isoDateTime(dayOffset: -1, hour: 11),
      'advisorApprovedBy': 'KANDI GUNAWAN',
    },
    {
      'id': 'wov-int-f355-approved',
      'woNumber': 'WOV/INT/2026/0015',
      'woType': 'WOV',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'ownerName': 'Mr. SILMY',
      'panelName': 'DUDUKAN JOK DEPAN RH',
      'partName': 'Cover Kulit Jok',
      'jobdescName': 'Emboss Ulang',
      'coreId': 'CD-INT-F355-004',
      'description':
          'Kirim cover kulit ke vendor emboss untuk penyesuaian tekstur.',
      'fromDivision': 'INTERIOR',
      'toDivision': 'Sinar Chrome',
      'estimatedHours': 8.0,
      'priority': 'HIGH',
      'status': 'APPROVED',
      'notes': 'Sudah dijemput vendor.',
      'requestedById': 'b3cc5298-179b-11f1-8701-94e6f79805fd',
      'requestedByName': 'RUHIAT SAEPULOH',
      'createdAt':
          _DummySeedDate.isoDateTime(dayOffset: -2, hour: 10, minute: 30),
      'deadline': _DummySeedDate.date(dayOffset: 1),
      'advisorApprovedAt': _DummySeedDate.isoDateTime(dayOffset: -2, hour: 12),
      'advisorApprovedBy': 'KANDI GUNAWAN',
      'pmApprovedAt': _DummySeedDate.isoDateTime(dayOffset: -2, hour: 14),
      'pmApprovedBy': 'PM DEMO',
      'approvedAt': _DummySeedDate.isoDateTime(dayOffset: -2, hour: 14),
    },
  ];

  static List<Map<String, dynamic>> seedRecords() =>
      List<Map<String, dynamic>>.from(_records);
}

// ═══════════════════════════════════════════════════════════════
// sm_jobdesc_plan / sm_jobdesc_actual support dummy task data
// ═══════════════════════════════════════════════════════════════

class DummyTaskExecutionData {
  DummyTaskExecutionData._();

  static final List<Map<String, dynamic>> _tasks = [
    {
      'plandailyId': 'pd-int-f355-doortrim-haris',
      'isOvertime': false,
      'coreId': 'CD-INT-F355-002',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'ownerName': 'Mr. SILMY',
      'panelName': 'DOORTRIM DEPAN LH',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'divisionName': 'INTERIOR',
      'status': 'PROSES',
      'isPanelLocked': true,
      'dailyTargetHours': 4.0,
      'targetHoursRevised': 8.0,
      'totalActualHours': 4.0,
      'remainingHours': 4.0,
      'taskDate': _DummySeedDate.date(),
      'createdAt': _DummySeedDate.isoDateTime(hour: 7),
      'startedAt': _DummySeedDate.isoDateTime(hour: 8),
      'completedAt': null,
      'taskCategory': 'MAIN',
      'jobDescription':
          'PENJAHITAN COVER / KAIN dan pemasangan doortrim depan kiri.',
      'lockedByName': null,
    },
    {
      'plandailyId': 'pd-int-w124-plafon-taruno',
      'isOvertime': false,
      'coreId': 'CD-INT-W124-002',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'ownerName': 'Mr. MARTHIN',
      'panelName': 'KAIN PLAFON',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'divisionName': 'INTERIOR',
      'status': 'ASSIGNED',
      'isPanelLocked': false,
      'dailyTargetHours': 3.0,
      'targetHoursRevised': 6.0,
      'totalActualHours': 0.0,
      'remainingHours': 6.0,
      'taskDate': _DummySeedDate.date(),
      'createdAt': _DummySeedDate.isoDateTime(hour: 7, minute: 10),
      'startedAt': null,
      'completedAt': null,
      'taskCategory': 'MAIN',
      'jobDescription': 'PEMASANGAN COVER / KAIN plafon unit W124.',
      'lockedByName': null,
    },
    {
      'plandailyId': 'pd-int-f355-seat-rework-agusr',
      'coreId': 'CD-INT-F355-004',
      'carId': 'FERRARIF355_MRSILMY',
      'unitName': 'FERRARI F355',
      'ownerName': 'Mr. SILMY',
      'panelName': 'DUDUKAN JOK DEPAN RH',
      'jobName': 'PEMASANGAN COVER / KAIN',
      'divisionName': 'INTERIOR',
      'status': 'DONE',
      'isPanelLocked': false,
      'dailyTargetHours': 2.0,
      'targetHoursRevised': 2.0,
      'totalActualHours': 2.0,
      'remainingHours': 0.0,
      'taskDate': _DummySeedDate.date(dayOffset: -1),
      'createdAt': _DummySeedDate.isoDateTime(dayOffset: -1, hour: 7),
      'startedAt': _DummySeedDate.isoDateTime(dayOffset: -1, hour: 8),
      'completedAt': _DummySeedDate.isoDateTime(dayOffset: -1, hour: 10),
      'taskCategory': 'MAIN',
      'jobDescription': 'REWORK tarikan cover dudukan jok depan kanan.',
      'lockedByName': null,
    },
    {
      'plandailyId': 'pd-int-additional-p3k-taruno',
      'coreId': '',
      'carId': 'MBW124E320SPORTLINE_MRMARTHIN',
      'unitName': 'MB W124 E320 SPORTLINE',
      'ownerName': 'Mr. MARTHIN',
      'panelName': 'KOTAK P3K',
      'jobName': 'CLEANING PART',
      'divisionName': 'INTERIOR',
      'status': 'ASSIGNED',
      'isPanelLocked': false,
      'dailyTargetHours': 2.5,
      'targetHoursRevised': 2.5,
      'totalActualHours': 0.0,
      'remainingHours': 2.5,
      'taskDate': _DummySeedDate.date(dayOffset: 1),
      'createdAt': _DummySeedDate.isoDateTime(hour: 7, minute: 30),
      'startedAt': null,
      'completedAt': null,
      'taskCategory': 'ADDITIONAL',
      'jobDescription': 'CLEANING PART dan perapihan kotak P3K tambahan.',
      'lockedByName': null,
    },
  ];

  static List<Map<String, dynamic>> seedTasks() =>
      _tasks.map((item) => Map<String, dynamic>.from(item)).toList();
}

class DummyTaskViewData {
  DummyTaskViewData._();

  static final List<Map<String, dynamic>> _tasks = [
    {
      'planDailyId': 'pd-view-int-001',
      'taskDate': _DummySeedDate.date(),
      'isOvertime': false,
      'division': {'divisionId': '12', 'divisionName': 'INTERIOR'},
      'unit': {'unitId': 'FERRARIF355_MRSILMY', 'unitName': 'FERRARI F355'},
      'employee': {
        'employeeId': 'b3cbf19f-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'HARIS',
      },
      'task': {
        'namaPanel': 'DOORTRIM DEPAN LH',
        'jobName': 'PEMASANGAN COVER / KAIN',
        'jobDescription':
            'PENJAHITAN COVER / KAIN dan pemasangan doortrim depan kiri.',
        'startTime': '08:00',
        'targetFinishTime': '12:00',
        'is_rework': 0,
        'breakDuration': 60,
      },
      'status': 'CHECK_PROGRESS',
      'checkpointHistory': [
        {
          'sessionNumber': 1,
          'startWorkTime': '08:00',
          'progress': 50,
          'checkpointTime': '10:30',
          'jobStatus': 'ON_PROGRESS',
          'actorRole': 'kd',
          'actorName': 'RUHIAT SAEPULOH',
          'isValidated': true,
          'reviewers': [
            {
              'role': 'adv',
              'name': 'KANDI GUNAWAN',
            },
            {
              'role': 'pm',
              'name': 'PM DEMO',
            },
          ],
        },
      ],
    },
    {
      'planDailyId': 'pd-view-int-002',
      'taskDate': _DummySeedDate.date(),
      'isOvertime': false,
      'division': {'divisionId': '12', 'divisionName': 'INTERIOR'},
      'unit': {
        'unitId': 'MBW124E320SPORTLINE_MRMARTHIN',
        'unitName': 'MB W124 E320 SPORTLINE',
      },
      'employee': {
        'employeeId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'TARUNO',
      },
      'task': {
        'namaPanel': 'KAIN PLAFON',
        'jobName': 'PEMASANGAN COVER / KAIN',
        'jobDescription': 'PEMASANGAN COVER / KAIN plafon unit W124.',
        'startTime': '09:00',
        'targetFinishTime': '12:00',
        'is_rework': 0,
        'breakDuration': 60,
      },
      'status': 'ASSIGNED',
    },
    {
      'planDailyId': 'pd-view-int-003',
      'taskDate': _DummySeedDate.date(dayOffset: -1),
      'isOvertime': true,
      'division': {'divisionId': '12', 'divisionName': 'INTERIOR'},
      'unit': {'unitId': 'FERRARIF355_MRSILMY', 'unitName': 'FERRARI F355'},
      'employee': {
        'employeeId': 'b3cb2386-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'AGUS RUSMAWAN',
      },
      'task': {
        'namaPanel': 'DUDUKAN JOK DEPAN RH',
        'jobName': 'PEMASANGAN COVER / KAIN',
        'jobDescription': 'REWORK tarikan cover dudukan jok depan kanan.',
        'startTime': '08:00',
        'targetFinishTime': '10:00',
        'is_rework': 1,
        'breakDuration': 30,
      },
      'status': 'DONE',
    },
    {
      'planDailyId': 'pd-view-int-004',
      'taskDate': _DummySeedDate.date(dayOffset: 1),
      'isOvertime': false,
      'division': {'divisionId': '12', 'divisionName': 'INTERIOR'},
      'unit': {
        'unitId': 'MBW124E320SPORTLINE_MRMARTHIN',
        'unitName': 'MB W124 E320 SPORTLINE',
      },
      'employee': {
        'employeeId': 'b3cc8541-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'TARUNO',
      },
      'task': {
        'namaPanel': 'KOTAK P3K',
        'jobName': 'CLEANING PART',
        'jobDescription': 'CLEANING PART dan perapihan kotak P3K tambahan.',
        'startTime': '13:00',
        'targetFinishTime': '15:00',
        'is_rework': 0,
        'breakDuration': 60,
      },
      'status': 'PLAN',
    },
    {
      'planDailyId': 'pd-view-bdw-001',
      'taskDate': _DummySeedDate.date(),
      'isOvertime': false,
      'division': {'divisionId': '10', 'divisionName': 'BODY WORK'},
      'unit': {'unitId': 'CHEVROLET_MRNYOMAN', 'unitName': 'CHEVROLET'},
      'employee': {
        'employeeId': 'b3cb1c6d-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'ADE ROSANDI',
      },
      'task': {
        'namaPanel': 'Fender Kiri Depan',
        'jobName': 'REPAIR PART / RANGKA',
        'jobDescription': 'Perbaikan ringan fender kiri depan Chevrolet.',
        'startTime': '08:00',
        'targetFinishTime': '12:00',
        'is_rework': 0,
        'breakDuration': 60,
      },
      'status': 'PROSES',
    },
    {
      'planDailyId': 'pd-view-bdp-001',
      'taskDate': _DummySeedDate.date(),
      'isOvertime': false,
      'division': {'divisionId': '11', 'divisionName': 'BODY PAINT'},
      'unit': {'unitId': 'FERRARIF355_MRSILMY', 'unitName': 'FERRARI F355'},
      'employee': {
        'employeeId': 'b3cb6796-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'DENDI MULYADI',
      },
      'task': {
        'namaPanel': 'Bumper Depan',
        'jobName': 'Epoxy Primer',
        'jobDescription': 'Epoxy primer bumper depan untuk persiapan cat.',
        'startTime': '08:00',
        'targetFinishTime': '11:00',
        'is_rework': 0,
        'breakDuration': 30,
      },
      'status': 'ASSIGNED',
    },
    {
      'planDailyId': 'pd-view-chr-001',
      'taskDate': _DummySeedDate.date(),
      'isOvertime': false,
      'division': {'divisionId': '14', 'divisionName': 'CHROME'},
      'unit': {'unitId': 'FERRARIF355_MRSILMY', 'unitName': 'FERRARI F355'},
      'employee': {
        'employeeId': 'b3cc54ae-179b-11f1-8701-94e6f79805fd',
        'employeeName': 'SAMBAS NURHIKAM',
      },
      'task': {
        'namaPanel': 'Grille Depan',
        'jobName': 'Re-chrome Grille',
        'jobDescription': 'Re-chrome grille depan unit Ferrari F355.',
        'startTime': '08:00',
        'targetFinishTime': '12:00',
        'is_rework': 0,
        'breakDuration': 60,
      },
      'status': 'PROSES',
    },
  ];

  static List<Map<String, dynamic>> seedTasks() =>
      _tasks.map((item) => Map<String, dynamic>.from(item)).toList();
}

// ═══════════════════════════════════════════════════════════════
// master_panels
// ═══════════════════════════════════════════════════════════════

/// Panel master data from `master_panels` table.
///
/// Grouped by division and category.
class DummyPanels {
  DummyPanels._();

  static const List<Map<String, String>> all = [
    // ── Mechanic — Engine (Tim Pak Yudha) ──────────────────
    {'division': 'MECHANIC', 'name': 'Blok Silinder', 'category': 'Engine'},
    {'division': 'MECHANIC', 'name': 'Head Silinder', 'category': 'Engine'},
    {
      'division': 'MECHANIC',
      'name': 'Kruk As (Crankshaft)',
      'category': 'Engine',
    },
    {
      'division': 'MECHANIC',
      'name': 'Piston & Stang Piston',
      'category': 'Engine',
    },
    {'division': 'MECHANIC', 'name': 'Klep / Valve', 'category': 'Engine'},
    {
      'division': 'MECHANIC',
      'name': 'Intake Manifold',
      'category': 'Engine',
    },
    {
      'division': 'MECHANIC',
      'name': 'Exhaust Manifold',
      'category': 'Engine',
    },
    {
      'division': 'MECHANIC',
      'name': 'Carter / Oil Pan',
      'category': 'Engine',
    },
    {
      'division': 'MECHANIC',
      'name': 'Timing Chain / Belt',
      'category': 'Engine',
    },
    {
      'division': 'MECHANIC',
      'name': 'Engine Mounting',
      'category': 'Engine',
    },

    // ── Mechanic — Undercarriage (Tim Pak Pratama) ─────────
    {
      'division': 'MECHANIC',
      'name': 'Shockbreaker Depan',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Shockbreaker Belakang',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Lower Arm',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Upper Arm',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Tie Rod & Long Tie Rod',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Ball Joint',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Link Stabilizer',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Bearing Roda',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Rack Steer',
      'category': 'Undercarriage',
    },
    {
      'division': 'MECHANIC',
      'name': 'Kaliper Rem',
      'category': 'Undercarriage',
    },

    // ── Mechanic — Electrical (Tim Pak Iqbal) ──────────────
    {
      'division': 'MECHANIC',
      'name': 'Alternator (Dinamo Ampere)',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Motor Starter',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'ECU / Komputer Mesin',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Wiring Harness Utama',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Relay & Fuse Box',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Aki & Kabel Massa',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Speedometer / Cluster',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Motor Power Window',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Saklar Dashboard',
      'category': 'Electrical',
    },
    {
      'division': 'MECHANIC',
      'name': 'Headlamp / Lampu Utama',
      'category': 'Electrical',
    },

    // ── Mechanic — Drivetrain & AC (Tim Pak Fiki) ──────────
    {
      'division': 'MECHANIC',
      'name': 'Gearbox Transmisi',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Kopling / Torque Converter',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Gardan (Differential)',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'As Roda (Drive Shaft)',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Kopel (Propeller Shaft)',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Kompresor AC',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Evaporator AC',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Kondensor AC',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Selang Freon & Pipa AC',
      'category': 'Drivetrain & AC',
    },
    {
      'division': 'MECHANIC',
      'name': 'Blower AC',
      'category': 'Drivetrain & AC',
    },

    // ── Body Work — Exterior ───────────────────────────────
    {
      'division': 'BODY WORK',
      'name': 'Mur Dudukan Plat Nomor',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Moulding Pintu Depan',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Angle Slider Sunroof',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Kaca Pintu Belakang LH',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Fender Kiri Depan',
      'category': 'Exterior',
    },
    {'division': 'BODY WORK', 'name': 'Kap Mesin', 'category': 'Exterior'},
    {
      'division': 'BODY WORK',
      'name': 'Lantai Dek Bawah',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Apron Depan',
      'category': 'Exterior',
    },
    {
      'division': 'BODY WORK',
      'name': 'Bagasi Belakang',
      'category': 'Exterior',
    },
    {'division': 'BODY WORK', 'name': 'Pilar A', 'category': 'Exterior'},

    // ── Body Paint — Exterior ──────────────────────────────
    {
      'division': 'BODY PAINT',
      'name': 'Bumper Depan',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Bumper Belakang',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Pintu Supir RH',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Pintu Penumpang LH',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Kap Mesin (Engine Hood)',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Roof / Atap',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Bagasi (Trunk Lid)',
      'category': 'Exterior',
    },
    {'division': 'BODY PAINT', 'name': 'Velg Set', 'category': 'Exterior'},
    {
      'division': 'BODY PAINT',
      'name': 'Handle Pintu Luar',
      'category': 'Exterior',
    },
    {
      'division': 'BODY PAINT',
      'name': 'Cover Spion',
      'category': 'Exterior',
    },

    // ── Interior (aligned to SQL master_panels) ───────────
    {
      'division': 'INTERIOR',
      'name': 'DASHBOARD DEPAN',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'ASBAK DASHBOARD DEPAN',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'COVER LACI DASHBOARD DEPAN',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'KAIN PLAFON',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'DOORTRIM DEPAN RH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'DOORTRIM DEPAN LH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'DUDUKAN JOK DEPAN RH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'DUDUKAN JOK DEPAN LH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'SENDERAN JOK DEPAN RH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'SENDERAN JOK DEPAN LH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'ARMREST JOK DEPAN',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'KARPET LANTAI BAGIAN DEPAN LH',
      'category': 'Interior',
    },
    {
      'division': 'INTERIOR',
      'name': 'KOTAK P3K',
      'category': 'Interior',
    },

    // ── Chrome — Exterior ──────────────────────────────────
    {
      'division': 'CHROME',
      'name': 'All Part Chrome (Set)',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'Bumper Depan Baja',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'List Kaca Depan',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'Handle Pintu Logam',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'Grill Radiator Utama',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'Emblem Logo Kap Mesin',
      'category': 'Exterior',
    },
    {
      'division': 'CHROME',
      'name': 'Rumah Lampu Depan',
      'category': 'Exterior',
    },
    {'division': 'CHROME', 'name': 'Knalpot Tip', 'category': 'Exterior'},
    {'division': 'CHROME', 'name': 'Spion Tanduk', 'category': 'Exterior'},
    {'division': 'CHROME', 'name': 'Wiper Arm', 'category': 'Exterior'},

    // ── Bubut — Part Custom ────────────────────────────────
    {
      'division': 'BUBUT',
      'name': 'Bushing Regulator Kaca',
      'category': 'Part Custom',
    },
    {'division': 'BUBUT', 'name': 'Frame Grill', 'category': 'Part Custom'},
    {
      'division': 'BUBUT',
      'name': 'Baud Kompressor AC',
      'category': 'Part Custom',
    },
    {
      'division': 'BUBUT',
      'name': 'Kleman Idle Control',
      'category': 'Part Custom',
    },
    {
      'division': 'BUBUT',
      'name': 'Piringan Cakram Depan',
      'category': 'Part Custom',
    },
    {
      'division': 'BUBUT',
      'name': 'Tromol Rem Belakang',
      'category': 'Part Custom',
    },
    {'division': 'BUBUT', 'name': 'Adaptor Velg', 'category': 'Part Custom'},
    {
      'division': 'BUBUT',
      'name': 'Bos Sayap Kaki-kaki',
      'category': 'Part Custom',
    },
    {
      'division': 'BUBUT',
      'name': 'As Roda (Drive Shaft)',
      'category': 'Part Custom',
    },
    {
      'division': 'BUBUT',
      'name': 'Dudukan Engine Mounting',
      'category': 'Part Custom',
    },
  ];

  /// Get panels for a given division name.
  static List<Map<String, String>> forDivision(String division) =>
      all.where((p) => p['division'] == division).toList();
}

// ═══════════════════════════════════════════════════════════════
// master_job_types
// ═══════════════════════════════════════════════════════════════

/// Job type master data from `master_job_types` table.
class DummyJobTypes {
  DummyJobTypes._();

  static const List<Map<String, dynamic>> all = [
    // ── Mechanic — Mesin Utama (Tim Pak Yudha) ─────────────
    {
      'division': 'MECHANIC',
      'job_name': 'Overhaul Head Silinder',
      'default_std_hours': 16.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Ring Piston',
      'default_std_hours': 24.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Skir Klep & Ganti Seal',
      'default_std_hours': 8.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Timing Chain Kit',
      'default_std_hours': 10.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Kuras Oli Mesin & Ganti Filter',
      'default_std_hours': 1.5,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Paking Carter (Cegah Rembes)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Kalibrasi Injektor / Karburator',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Cek & Uji Kompresi Mesin',
      'default_std_hours': 2.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Set Engine Mounting',
      'default_std_hours': 5.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Porting & Polish Saluran Intake',
      'default_std_hours': 12.0,
    },

    // ── Mechanic — Kaki-kaki & Suspensi (Tim Pak Pratama) ──
    {
      'division': 'MECHANIC',
      'job_name': 'Press & Ganti Bushing Arm',
      'default_std_hours': 6.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Shockbreaker Depan/Belakang',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Spooring & Balancing Bawah',
      'default_std_hours': 2.5,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Bearing Roda (Press)',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Servis / Kalibrasi Rack Steer',
      'default_std_hours': 8.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Setting Ketinggian Torsi / Per',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Kampas Rem Set',
      'default_std_hours': 2.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Kuras Minyak Rem (Bleeding)',
      'default_std_hours': 1.5,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti & Setting Tie Rod',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Pasang Karet Link Stabilizer',
      'default_std_hours': 2.0,
    },

    // ── Mechanic — Kelistrikan & Sensor (Tim Pak Iqbal) ────
    {
      'division': 'MECHANIC',
      'job_name': 'Urut Kabel Body (Rewiring Total)',
      'default_std_hours': 40.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Servis Alternator (Ganti IC/Carbon Brush)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Servis / Ganti Dinamo Starter',
      'default_std_hours': 3.5,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Reset / Remap ECU Sistem',
      'default_std_hours': 2.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Perbaikan Speedometer Mati',
      'default_std_hours': 5.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Modul & Motor Power Window',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Pasang Alarm / Central Lock Baru',
      'default_std_hours': 6.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Troubleshoot Lampu Konslet',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Box Sekring & Relay',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Perbaikan Switch / Saklar Dashboard',
      'default_std_hours': 3.5,
    },

    // ── Mechanic — Transmisi, Gardan & AC (Tim Pak Fiki) ───
    {
      'division': 'MECHANIC',
      'job_name': 'Turun Transmisi (Overhaul Matic/Manual)',
      'default_std_hours': 32.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Plat Kopling Set (Manual)',
      'default_std_hours': 8.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Kuras Oli Transmisi (Flushing)',
      'default_std_hours': 2.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Seal Pinion Gardan (Cegah Bocor)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Servis Kompresor AC & Ganti Magnet Clutch',
      'default_std_hours': 6.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Bongkar Dashboard & Ganti Evaporator',
      'default_std_hours': 14.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Vakum & Isi Freon AC',
      'default_std_hours': 1.5,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Cek & Las Kebocoran Selang AC',
      'default_std_hours': 3.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Balancing Propeller Shaft (Kopel)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'MECHANIC',
      'job_name': 'Ganti Bearing / Boot As Roda',
      'default_std_hours': 3.5,
    },

    // ── Body Work ──────────────────────────────────────────
    {
      'division': 'BODY WORK',
      'job_name': 'Pengelasan & Penambalan Keropos',
      'default_std_hours': 8.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Pembuatan Part Kustom (Making)',
      'default_std_hours': 12.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Fitting & Setting Awal Panel',
      'default_std_hours': 6.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Setting Akhir / Finishing Gap',
      'default_std_hours': 5.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Kerok Cat Sampai Plat Besi',
      'default_std_hours': 14.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Ketok Magic / Tarik Penyok',
      'default_std_hours': 4.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Pembongkaran Kaca Utama',
      'default_std_hours': 2.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Pemasangan Karet & List Body',
      'default_std_hours': 3.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Las Titik (Spot Welding)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'BODY WORK',
      'job_name': 'Pemotongan Plat Panel',
      'default_std_hours': 4.0,
    },

    // ── Body Paint ─────────────────────────────────────────
    {
      'division': 'BODY PAINT',
      'job_name': 'Pengecatan Primer (Epoxy Dasar)',
      'default_std_hours': 6.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Dempul Kasar (Pembangunan Body)',
      'default_std_hours': 10.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Dempul Halus (Finishing)',
      'default_std_hours': 8.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Amplas Halus & Persiapan Pengecatan',
      'default_std_hours': 6.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Masking & Penutupan Area Kaca',
      'default_std_hours': 2.5,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Pengecatan Warna Dasar (Base Coat)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Pengecatan Warna Utama',
      'default_std_hours': 6.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Clear Coat (Pernis)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Wet Sanding (Amplas Air)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'BODY PAINT',
      'job_name': 'Poles & Compound Akhir',
      'default_std_hours': 8.0,
    },

    // ── Interior (aligned to SQL master_job_types) ────────
    {
      'division': 'INTERIOR',
      'job_name': 'PEMBONGKARAN / PELEPASAN PART',
      'default_std_hours': 2.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'CLEANING PART',
      'default_std_hours': 2.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'CLEANING LEM BEKAS',
      'default_std_hours': 2.5,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'REPAIR PART / RANGKA',
      'default_std_hours': 4.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'SANDING PERAPIHAN',
      'default_std_hours': 3.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PEMBENTUKAN BUSA',
      'default_std_hours': 4.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PEMOTONGAN BAHAN KAIN / KULIT',
      'default_std_hours': 3.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PENJAHITAN COVER / KAIN',
      'default_std_hours': 4.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PEMASANGAN BUSA PELAPIS',
      'default_std_hours': 4.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PEMASANGAN COVER / KAIN',
      'default_std_hours': 4.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PERAKITAN KOMPONEN PART',
      'default_std_hours': 3.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'FITTING PART KE UNIT',
      'default_std_hours': 3.0,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'SETTING DAN PEMAKSIMALAN PART',
      'default_std_hours': 2.5,
    },
    {
      'division': 'INTERIOR',
      'job_name': 'PEMASANGAN PART KE UNIT',
      'default_std_hours': 3.0,
    },

    // ── Chrome ─────────────────────────────────────────────
    {
      'division': 'CHROME',
      'job_name': 'Pendataan & Pergelaran Part',
      'default_std_hours': 3.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Pembersihan Karat (Sandblasting)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Pengupasan Chrome Lama (Stripping)',
      'default_std_hours': 6.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Poles Dasar (Persiapan Plating)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Proses Chrome Plating',
      'default_std_hours': 8.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Polishing & Kilap Akhir',
      'default_std_hours': 4.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Quality Control (Pengecekan Bintik)',
      'default_std_hours': 1.5,
    },
    {
      'division': 'CHROME',
      'job_name': 'Pelapisan Tembaga Dasar (Copper Plating)',
      'default_std_hours': 5.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Bongkar Pasang Rivet Logo',
      'default_std_hours': 2.0,
    },
    {
      'division': 'CHROME',
      'job_name': 'Lapis Galvanis Rainbow (Baut)',
      'default_std_hours': 3.5,
    },

    // ── Bubut ──────────────────────────────────────────────
    {
      'division': 'BUBUT',
      'job_name': 'Pembuatan Bushing (Making)',
      'default_std_hours': 4.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Lapis Tembaga Tebal & Bubut Rata',
      'default_std_hours': 5.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Bubut Piringan Cakram / Tromol',
      'default_std_hours': 3.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Tap Ulir Drat Ulang',
      'default_std_hours': 1.5,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Pembuatan Adaptor Roda Kustom',
      'default_std_hours': 8.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Pemotongan & Bubut As Roda',
      'default_std_hours': 6.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Press Bearing Mesin / Roda',
      'default_std_hours': 2.5,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Pembuatan Bracket Knalpot',
      'default_std_hours': 4.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Galvanis Ulang Part Kecil',
      'default_std_hours': 2.0,
    },
    {
      'division': 'BUBUT',
      'job_name': 'Pembuatan Dudukan Engine Mounting',
      'default_std_hours': 7.0,
    },
  ];

  /// Get job types for a given division name.
  static List<Map<String, dynamic>> forDivision(String division) =>
      all.where((j) => j['division'] == division).toList();
}
