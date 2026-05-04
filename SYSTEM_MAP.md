# Project Summary
- **Tujuan Aplikasi**: Workshop Management System (SM-MIS) untuk mendigitalkan proses manajemen bengkel skala besar. Mencakup fitur attendance, login, countdown panel progress, pengelolaan task execution (mekanik), quality control (QC), modul job plan, permintaan gudang (warehouse), purchase request (PR), dan push notification.
- **Tech Stack Utama**:
  - **Mobile (Frontend)**: Flutter 3.x (Dart) menggunakan arsitektur Clean Architecture (Domain - Data - Presentation) & Feature-First directory. 
  - **Backend (API)**: Python (FastAPI), dengan arsitektur Microservices (terbagi ke beberapa container service mandiri).
  - **Database & State**: MariaDB/MySQL (Raw query via `pymysql`), Redis (Session management & PubKey sharing untuk EdDSA JWT).
  - **Infrastruktur**: Docker Compose untuk deployment backend.
- **Pola Arsitektur Singkat**: Mobile menggunakan pola modular per-feature (misal: `auth`, `qc`, `warehouse`). Backend menggunakan Microservices yang berkomunikasi state melalui *Redis Cache* dan langsung direct ke MySQL.

---

# Core Logic Flow (Function-Level Flowchart)

### Mobile Request Flow
`Button Trait/Page -> Presentation (Bloc/Provider) -> Domain (Usecase) -> Data (Repository + ApiClient) -> HTTP Request`

### Auth & Session Flow (Backend)
`SmWorkshopApp[Mobile] -> sm_api_splash/main.py[Generate EdDSA Token] -> sm_login/main.py[login() & DB Check] -> Redis[set session:emp_id] -> Mobile[Save Session]`

### Task ke QC Workflow (Berdasarkan Konteks Laporan)
`sm_tasks/main.py[submit_task] -> DB[Tasks: WAITING_QC] -> sm_job_QC/main.py[qc_inspect] -> Service[Calculate Rework/Pass] -> sm_notification/main.py[trigger_fcm] -> FCM API -> Mobile[Notifikasi]`

---

# Clean Tree
Berikut merupakan top-level directory dan modul penting (hanya source code relevan):

```text
[Mobile: sm_workshop]
├── lib
│   ├── core/              # Global Setup
│   │   ├── auth/          # RBAC (Role-Based Access Control)
│   │   ├── config/        # App configs & environment variables
│   │   ├── di/            # Dependency Injection (injection.dart)
│   │   ├── network/       # api_client.dart (Dio/HTTP Setup)
│   │   ├── security/      # device_signing_service.dart
│   │   └── services/      # FCM Service, Alarms, Warmup runtime 
│   ├── features/          # App Features (Data - Domain - Presentation)
│   │   ├── auth/
│   │   ├── countdown/
│   │   ├── job_plan/
│   │   ├── qc/
│   │   ├── task_execution/
│   │   └── warehouse_request/
│   └── main.dart          # Entry Point

[Backend: be_sms]
├── docker-compose.yml     # Orkestrasi seluruh microservices
├── *.sql                  # File dump schematics & Seed data (sms_db-*.sql)
├── sm_api_splash/         # Temp JWT generator API
├── sm_countdown/          # Service Countdown dashboard
├── sm_job_QC/             # Service Quality Control Inspector
├── sm_job_plan/           # Service Job Plan (Planner KD)
├── sm_login/              # Core Auth Service
├── sm_notification/       # Centralized Gateway FCM
├── sm_pr/                 # Service Purchase Request
├── sm_tasks/              # Service Mechanic Tasks
├── sm_warehouse/          # Service Inventory/Warehouse
└── sm_wo/                 # Service Work Order progress
```

---

# Module Map (The Chapters)

## Mobile Project
- `lib/main.dart`: Fungsi main() & root `SmWorkshopApp`; berperan sebagai inisiator aplikasi, session, state, dan rendering theme.
- `lib/core/network/api_client.dart`: Class client Http utama; peran modul mem-bypass komunikasi network dan inject token Auth ke Header secara terpusat.
- `lib/core/auth/rbac.dart` & `role_guard.dart`: Class pemroses matrix validasi permissions; menahan navigasi fitur jika role tidak sesuai standar akses.
- `lib/core/services/fcm_service.dart`: Integrasi Firebase token; memuat listener push notification di background maupun foreground.
- `lib/features/task_execution/*`: Kumpulan state & controller; melayani logic mekanik untuk report kerja, overtime, sampai selesai (`WAITING_QC`).

## Backend Project
- `docker-compose.yml`: Root config container deployment; menentukan mapping port API eksternal dan link network antar container.
- `sm_api_splash/app/main.py`: `create_temp_token()`; berperan mengeluarkan token sementara untuk bypass keamanan attestation sebelum login.
- `sm_login/app/main.py`: `login()`; menangani validasi JWT, cek DB tabel pegawai, enkripsi BCrypt, simpan state Redis, dan return Session.
- `sm_notification/app/main.py`: `send_fcm()`; bertindak sebagai jembatan tunggal untuk service lain yang ingin mem-push notifikasi via SDK admin Firebase.
- `sm_job_QC/app/main.py`: handler role inspector; service yang memutuskan hasil inspeksi (Pass / Rework / Auto-Create Revision Tasks).
- `sm_warehouse/app/main.py`: fungsi inventaris; menangani validasi pengeluaran sparepart yang di-*attach* ke ID Work Order / Task.

---

# Data & Config
- **Lokasi Config Utama**: 
  - Mobile: `.env` (jika ada) atau statik di `lib/core/config/app_config.dart`.
  - Backend: Masing-masing folder service memiliki file `.env-dev` yang dipanggil melalui library Python Pydantic/Decouple (misal: `REDIS_HOST`, `DB_PASS`).
- **Skema Data**: 
  - Tidak ada ORM; skema murni raw SQL berbasis entitas `sm_employee`, `sm_role`, `sm_user_devices`, `sys_permissions`, dsb. 
  - Relasi utamanya adalah `Employee -> Role -> Permissions`, dan `Device_ID -> FCM Token`.
- **Database Migrations/Seed**: Terangkum di file statis seperti `sms_db-sms_db-2026.sql`, `seed_perms.sql`, `fix_all_perms.sql` yang berlokasi di root backend`/home/sahrulr/Documents/SM-MIS/be_sms/`.
- **Session/Cache Artifacts**: Disimpan secara live di container `redis:7-alpine` pada key `session:{employee_id}`.

---

# External Integrations
- **Firebase Cloud Messaging (FCM)**: Dipanggil oleh modul mobile `fcm_service.dart` (untuk registrasi device/token) dan modul microservice `sm_notification` (menggunakan Firebase-Admin payload push config) ke Google API.

---

# Risks / Blind Spots
- **Tanpa ORM layer (Backend)**: FastAPI memanggil MySQL menggunakan sintaks *hardcoded string* (`cursor.execute()`). Struktur relasi antar-tabel rumit untuk dilacak hanya dari *source code analysis*, harus membedah file dump `.sql`.
- **Fragmentasi Environment Variables**: Tiap microservice memiliki file `.env-dev` terpisah. Perlu dijaga sinkronisasi datanya secara manual.
- **Port Mapping Clash**: Setiap container API punya port eksternal (8081, 8083, 8084, dst). Membutuhkan API gateway atau NGINX (yang belum tampak dipusatkan di proxy layer) agar Flutter request lebih sederhana. Peta port ada di `API_CONTRACT.md`.
