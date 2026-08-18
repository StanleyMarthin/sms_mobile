<!--
Tujuan: Peta sistem aktual SM-MIS yang mencakup frontend Flutter dan konteks backend untuk tracing fitur, debugging, dan validasi arsitektur.
Caller: Developer, agent, dan reviewer.
Dependensi:
  Mobile — `lib/main.dart`, `lib/core/*`, `lib/features/*`, `pubspec.yaml`, `docs/mobile_api_contract (1).md`
  Backend — `be_sms/api/*`, `be_sms/docker-compose.yml`, `be_sms/redeploy_vps.sh`, file `.sql`
Main Functions: Startup flow, route map, DI graph, feature flow, service/endpoint map, role & divisi model, storage lokal, modul aktif vs legacy, blind spot.
Side Effects: Tidak ada. Wajib diperbarui saat flow utama, route, struktur modul, atau backend service berubah.
-->

# SYSTEM MAP

---

## 0. Verification Scope

- Last verified: 2026-06-25
- Source-of-truth priority (mobile):
  1. `lib/main.dart`
  2. `lib/core/router/app_router.dart`
  3. `lib/core/di/injection.dart`
  4. `lib/core/network/api_endpoints.dart`
  5. Remote datasource/repository per feature
  6. `docs/mobile_api_contract (1).md` — hanya sebagai konteks tambahan, bukan sumber kebenaran utama
- Source-of-truth priority (backend):
  1. `be_sms/docker-compose.yml` — port mapping dan orkestrasi container
  2. `be_sms/api/<service>/app/main.py` — implementasi endpoint per service
  3. `be_sms/sms_db-sms_db-202605081345.sql` — schema utama
  4. `be_sms/warehouse-sms_warehouse-202605081346.sql` — schema warehouse
- Backend source code tidak ada di workspace mobile. Deskripsi backend di dokumen ini diinfer dari kode mobile + kontrak endpoint, bukan dari implementasi backend lokal.

---

## 1. Project Snapshot

- Product name in UI: `Stanley Marthin System`
- Package/project identifiers: folder `sm_workshop`, pub package `sm_system`
- Platform: Flutter mobile (Android + iOS)
- App style: dark luxury workshop UI (gold accents) + light mode ala web SM-MIS
  (paper #f9f7f6, ink #261910, accent #f97316); toggle di app bar shell,
  persist di SharedPreferences (`theme_mode`)
- Architecture:
  - Feature-first folder structure `lib/features/*`
  - Layered split per feature: `data -> domain -> presentation`
  - DI via `get_it`
  - State via `flutter_bloc` + beberapa stateful page
  - Navigation via `go_router`
  - Remote-first runtime; local/mock datasource ada tapi bukan jalur runtime utama
- Storage/runtime:
  - Session dan small local state via `SharedPreferences`
  - FCM + local notification diinisialisasi saat startup
  - Wakelock enabled global di `main()`
  - Photo upload via presigned ticket → direct PUT ke object storage

---

## 2. Root Tree

```text
[Mobile: sm_workshop]
sm_workshop/
├── SYSTEM_MAP.md
├── README.md
├── pubspec.yaml
├── docs/
│   └── mobile_api_contract (1).md
├── test/
│   └── core/network/api_endpoints_test.dart
├── assets/images/
├── android/
├── ios/
└── lib/
    ├── main.dart
    ├── core/
    │   ├── auth/           # RBAC: rbac.dart, role_guard.dart
    │   ├── config/         # AppConfig, environment variables
    │   ├── constants/
    │   ├── data/           # dummy_data.dart, shared data models
    │   ├── di/             # injection.dart
    │   ├── errors/         # failures.dart, error_message.dart (friendlyMessage)
    │   ├── network/        # api_client.dart (Dio), api_endpoints.dart
    │   ├── presentation/   # feature_shell_page.dart
    │   ├── router/         # app_router.dart
    │   ├── security/       # device_signing_service.dart, app_secure_storage.dart
    │   ├── services/       # fcm_service, notification_inbox, upload, alarm_timer
    │   ├── session/        # session_manager.dart
    │   ├── theme/          # app_theme.dart, theme_controller.dart
    │   ├── utils/
    │   └── widgets/        # in_app_camera_page.dart
    └── features/
        ├── approvals/      # ada di kode, belum diroute
        ├── auth/
        ├── countdown/
        ├── dashboard/      # ada di kode, belum diroute (/dashboard → redirect /home)
        ├── home/
        ├── job_plan/
        ├── monitoring/
        ├── notifications/
        ├── pr/
        ├── profile/
        ├── qc/
        ├── task_execution/
        ├── warehouse_request/
        ├── work_order/
        └── wov/            # ada di kode, belum diroute

[Backend: be_sms]
be_sms/
├── api/                                          # ROOT SEMUA MICROSERVICE
│   ├── sm_api_splash/                            # Temp JWT generator — port 8080
│   ├── sm_login/                                 # Core Auth — port 8085
│   ├── sm_job_plan/                              # Job Plan — port 8083
│   ├── sm_tasks/                                 # Tasks — port 8086
│   ├── sm_job_QC/                               # QC — port 8088
│   ├── sm_countdown/                             # Countdown — port 8090
│   ├── sm_warehouse/                             # Warehouse — port 8091
│   ├── sm_wo/                                    # Work Order — port 8093
│   ├── sm_pr/                                    # PR + WOV — port 8096
│   └── sm_notification/                          # FCM Gateway (internal)
├── docker-compose.yml
├── redeploy_vps.sh                               # Script redeploy ke VPS
├── sms_db-sms_db-202605081345.sql               # Schema & seed utama
└── warehouse-sms_warehouse-202605081346.sql      # Schema & seed warehouse
```

---

## 3. Startup Flow

```text
main()
-> WidgetsFlutterBinding.ensureInitialized()
-> initializeDateFormatting('id_ID')
-> initDependencies()           # lib/core/di/injection.dart
-> SessionManager.init()        # lib/core/session/session_manager.dart
-> NotificationInboxService.init()
-> FCMService.init()
   -> if permission denied: SystemNavigator.pop()   ← app exit, tidak bisa skip
-> WakelockPlus.enable()        # global, sepanjang sesi
-> runApp(SmWorkshopApp)
-> MaterialApp.router(createRouter())
```

Files touched:
`main.dart` → `injection.dart` → `session_manager.dart` → `notification_inbox_service.dart` → `fcm_service.dart` → `app_router.dart` → `app_theme.dart`

**Catatan startup:**
- App tidak bisa skip FCM init. Jika permission notifikasi denied → app exit.
- Session restoration terjadi sebelum router dibuat → redirect logic di router bergantung pada session yang sudah loaded.
- Wakelock aktif unconditionally selama sesi app berjalan.

---

## 4. Navigation Map

### Active routes (`app_router.dart`)

| Route | Page | Query params | Notes |
|---|---|---|---|
| `/splash` | `SplashPage` | — | Device init + app version gate |
| `/login` | `LoginPage` | — | Login setelah temp token tersedia |
| `/home` | `HomePage` | — | Landing page utama pasca-login |
| `/dashboard` | redirect → `/home` | — | Legacy alias; `DashboardPage` tidak diroute |
| `/tasks` | `FeatureShellPage → TaskSectionPage(kind: tasks)` | `taskId`, `date` | Anggota → langsung `MechanicTaskPage`; KD → tab Monitoring/PIC Saya; management lain → `TaskViewPage` |
| `/overtime` | `FeatureShellPage → TaskSectionPage(kind: overtime)` | `taskId`, `date` | Sama dengan tasks |
| `/plans` | `FeatureShellPage → TaskSectionPage(kind: plan)` | `date`, `source`, `sourceRefId`, `autoOpenCreate` | Membuka `JobPlanPage` |
| `/countdown` | `FeatureShellPage → CountdownPage` | `carId` | PM/KP mendapat tab revision approval tambahan |
| `/monitoring` | `FeatureShellPage → MonitoringPage` | `carId` | Weekly monitoring overview |
| `/qc` | `FeatureShellPage → QcTab` | `qcId` | QC queue dan submit flow |
| `/work-orders` | `FeatureShellPage → WorkOrderPage` | `woId` | WO list aktif/selesai |
| `/warehouse` | `FeatureShellPage → WarehouseRequestPage` | — | Request/approval/storage tabs |
| `/pr` | `FeatureShellPage → PrPage` | — | Purchase Request list/create/approve |
| `/notifications` | `FeatureShellPage → NotificationsPage` | — | Local inbox history di device |
| `/profile` | `FeatureShellPage → ProfilePage` | — | Profile + logout |
| `/alarm` | `AlarmPage` | `extra` map | Route khusus alarm reminder; bukan menu navigasi |

### Router redirect rules

- `/splash` → selalu diizinkan masuk.
- Belum login + `tempToken == null` → redirect `/splash`.
- Belum login + `tempToken` ada → redirect `/login`.
- Sudah login + mencoba `/splash` atau `/login` → redirect `/home`.

---

## 5. Role & Access Hierarchy

### Dua sistem permission berjalan paralel

**1. Static frontend role map** — `lib/core/auth/rbac.dart`
- Enum `Permission`
- Menggerakkan konstruksi menu grid `HomePage`
- Menggerakkan `RoleGuard`, `RoleGuardAny`, `RoleGuardByRole`
- Alias role dinormalisasi di `getPermissions()` dan `UserRole.fromString()`

**2. Backend-driven string permission codes** — `lib/core/session/session_manager.dart`
- Konstanta di bawah `Perms`
- Disimpan dari login response ke session
- Dicek via `SessionManager.hasPerm()` dan `PermGuard`

> Jika backend permissions berkembang tapi FE role alias mapping tidak ikut diupdate, menu exposure dan fine-grained access bisa drift.

### Hierarki akses (tertinggi ke terendah)

```
MO  (Manager Operasional)   — akses semua unit yang dipegang
 └─ MP  (Manager/Pimpinan)  — akses all divisi dalam unit yang dipegang
     └─ KP  (Kepala Pool)   — akses semua unit
         └─ ADV  (Advisor)  — akses divisi yang dia pegang → all unit di bawah divisi itu
             └─ KD  (Kepala Divisi) — akses anggota divisi sendiri saja
```

**Alur eskalasi approval KD:**
```
KD → ADV (jika ada di divisi tersebut) → KP
KD → KP  (langsung, jika tidak ada ADV di divisi)
```

**Scope data per role:**

| Role | Scope Data |
|------|-----------|
| MO | Semua unit yang dipegang |
| MP | All divisi — dibatasi unit |
| KP | All unit |
| ADV | All unit — dibatasi divisi yang dipegang (termasuk sub-team) |
| KD | Anggota divisi sendiri (termasuk sub-team jika ada) |

### Normalized role aliases (mobile)

| Alias mobile | Mapped to |
|---|---|
| `op`, operator/lapangan | `op` |
| `kd` | `kd` |
| `adv` | `adv` |
| PM, management, broader aliases | `pm` |
| Warehouse/PPIC aliases | mapped per context |

`RemoteJobPlanDataSource` secara khusus menormalisasi role code ke: `KD`, `ADV`, `KP`, `MP`.

---

## 6. Divisi & Team Structure

Divisi dimodelkan dengan **self-referencing `parent_id`** pada tabel `sm_divisi`. Divisi besar (misal: Mechanic) dapat dibagi menjadi beberapa sub-team tanpa membuat divisi terpisah — tetap satu divisi dengan anak.

```sql
CREATE TABLE `sm_divisi` (
  `id`         int NOT NULL AUTO_INCREMENT,
  `name`       varchar(100) NOT NULL  COMMENT 'Bodyworks, BodyPaint, Chrome, Mechanic',
  `code`       varchar(10)  NOT NULL  COMMENT 'BDW, BDP, CHR, MEC',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `isteknis`   tinyint(1)   NOT NULL DEFAULT '1',
  `parent_id`  int DEFAULT NULL,  -- NULL = divisi induk; diisi = sub-team dari parent
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  CONSTRAINT `fk_divisi_parent`
    FOREIGN KEY (`parent_id`) REFERENCES `sm_divisi` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Contoh struktur Mechanic:**
```
id=1  name="Mechanic"    code="MEC"   parent_id=NULL  ← divisi induk
id=10 name="MEC Team A"  code="MEC-A" parent_id=1     ← sub-team
id=11 name="MEC Team B"  code="MEC-B" parent_id=1     ← sub-team
```

**Query wajib — selalu sertakan subtree saat filter divisi:**
```sql
SELECT e.*
FROM sm_employee e
JOIN sm_divisi d ON e.divisi_id = d.id
WHERE d.id = :divisi_id
   OR d.parent_id = :divisi_id;
```

> Query yang hanya `d.id = :divisi_id` tanpa `OR d.parent_id = :divisi_id` akan melewatkan seluruh anggota sub-team. Ini sumber bug scope yang paling umum.

---

## 7. Dependency Injection Map

Source: `lib/core/di/injection.dart`

### Core singletons (via GetIt)

- `SessionManager`
- `ApiClient`
- `UploadService`
- `LocalMockApiStore`
- `NotificationInboxService`

### Self-managed singletons

- `FCMService`
- `AlarmTimerService`

### Auth

```text
RemoteAuthDataSource
-> AuthRepositoryImpl
-> DeviceInitUseCase
-> LoginUseCase
-> AuthBloc
```

### Task execution

```text
TaskDraftStorage
RemoteTaskDataSource = ApiTaskDataSource
ViewTaskDataSource   = ApiViewTaskDataSource
-> TaskRepositoryImpl
-> ViewTaskRepositoryImpl
-> StartJobUseCase
-> TaskBloc
-> TaskViewBloc
```

### Job plan & work order

```text
RemoteJobPlanDataSource
-> JobPlanRepositoryImpl

WorkOrderRemoteDataSource
  depends on: ApiClient + SessionManager + JobPlanRepository
-> WorkOrderRepositoryImpl
-> WorkOrderBloc
```

### Feature singletons lainnya

```text
RemoteQcDataSource          -> QcRepositoryImpl
RemoteWarehouseDataSource   -> WarehouseRepositoryImpl
RemoteCountdownDataSource   -> CountdownRepositoryImpl
RemoteMonitoringDataSource  -> MonitoringRepositoryImpl
RemoteNotificationsDataSource -> NotificationsRepositoryImpl
RemoteProfileDataSource     -> ProfileRepositoryImpl
```

### DI gaps yang perlu diperhatikan

| Gap | Dampak |
|-----|--------|
| `RuntimeWarmupService` diimplementasi tapi tidak diregister/dipanggil dari startup | Warmup tidak aktif |
| `RemotePrDataSource` tidak diregister | `PrPage` buat langsung; tidak bisa di-mock via DI |
| `RemoteWovDataSource` tidak diregister | `WovPage` buat langsung; idem |
| `CountdownRepositoryImpl` diregister tanpa `qcDataSource` | Countdown-to-QC enrichment hook non-aktif |
| Local/mock datasources ada tapi bukan default runtime path | Bisa menyesatkan saat tracing |

---

## 8. Service & Endpoint Map

Source: `lib/core/network/api_endpoints.dart`

### Base host

- `AppConfig.baseUrl` dari `--dart-define=BASE_URL`
- Default fallback: `https://api.stanleymarthin.com`
- Format default gateway: `https://api.stanleymarthin.com/<path>`
- Format legacy eksplisit: `--dart-define=BASE_URL=http://108.136.189.225` → `scheme://host:port/<path>`
- `AppConfig.serviceOrigin()` hanya menambahkan port untuk origin non-gateway atau origin HTTPS yang sudah memakai port eksplisit.

### Active service map

| Service | Gateway path | Legacy port | Dikonsumsi oleh |
|---|---|---:|---|
| Device init / splash auth | `/sm/auth/device-init` | `8080` | Splash/auth bootstrap |
| Identity/session/profile | `/api/v1/auth/*`, `/api/v1/notifications`, `/api/v1/users/profile` | `8085` | Login, refresh, remote notif, profile |
| Job plan | `/sm/job-plans*` | `8083` | Job plan, WO dropdown reuse, PR car picker |
| Tasks | `/sm/tasks*` | `8086` | Operator task execution, management task monitoring, upload ticket |
| QC | `/sm/qc*`, `/sm/qc/monitoring*` | `8088` | QC queue/submit; QC monitoring data |
| Countdown | `/sm/countdown*`, `/sm/countdown/action`, `/sm/countdown/revision` | `8090` | Countdown, revision, monitoring synthesis |
| Warehouse | `/sm/warehouse*` | `8091` | Request/approval/storage/logs/upload |
| Work order | `/sm/wo*`, `/sm/wo/extensions` | `8093` | WO list/detail/create/approve/reject/extensions |
| Monitoring (via QC) | `/sm/qc/monitoring*` | `8088` | Monitoring unit & weekly report |
| Notifications (FCM Send) | `/sm/notify/send` | `8085` | Trigger remote push notifications |
| PR + WOV | `/sm/pr*`, `/sm/wov*` | `8096` | PR page, WOV helper page |

### Catatan penting endpoint

- Auth/profile/notifications menggunakan path style `/api/v1/...`; feature lain menggunakan `/sm/...`
- Gateway production sudah mem-proxy endpoint mobile melalui `https://api.stanleymarthin.com`; port langsung hanya mode legacy eksplisit.
- Monitoring list memakai endpoint QC `/sm/qc/monitoring`; drilldown tertentu masih bisa mensintesis data dari repeated countdown calls via `ApiEndpoints.countdown`.
- `docs/mobile_api_contract (1).md` menggambarkan style `/api/v1` yang lebih lama dan beberapa shape endpoint yang sudah tidak aktual. Gunakan `ApiEndpoints` + remote datasource sebagai kebenaran saat ini.

---

## 9. Core Runtime Components

### Session & storage

`lib/core/session/session_manager.dart` — menyimpan:
`tempToken`, `deviceId`, `token`, `refreshToken`, `userId`, `employeeId`, `fullName`, `role`, `divisionName`, `jabatan`, `divisionId`, `permissions`

`lib/core/security/app_secure_storage.dart`
- **Nama menyesatkan**: bukan encrypted secure storage.
- Thin wrapper di atas `SharedPreferences`.

### HTTP client

`lib/core/network/api_client.dart` — Dio-based:
- Auto-inject bearer token (kecuali `skipAuth`)
- Standard response unwrap + failure mapping
- Refresh token flow on `401`
- Retry dengan exponential backoff untuk network/`503`

### Device signing

`lib/core/security/device_signing_service.dart`:
- Generate + persist per-device Ed25519 keypair
- Build install-scoped device identity dari Android ID + local install ID
- Sign device init payload; kirim public key sampai server pinning confirmed

### Notification & FCM

- `lib/core/services/fcm_service.dart` — init Firebase, request permission, schedule/cancel task alarms
- `lib/core/services/notification_inbox_service.dart` — persist foreground/background payload ke local, convert ke app route, trigger on tap

### Upload pipeline

`lib/core/services/upload_service.dart`:
```text
feature page/bloc
-> UploadService.uploadPhoto(localPath, unit, division, job, panel, type)
-> GET upload ticket dari backend
-> terima upload_url + public_url
-> PUT binary langsung ke object storage
-> return public_url ke feature flow
```

---

## 10. Feature Flow Map

Format tracing: `Trigger/Entry → Page/State → Repository → Datasource → API/Storage`

### 10.1 Auth & login

```text
main.dart → /splash → SplashPage
-> kumpulkan: Android ID, install-scoped device ID, appVersion=1.0.1, lokasi kasar, Ed25519 signature
-> AuthBloc(DeviceInitRequested) → DeviceInitUseCase → RemoteAuthDataSource.deviceInit()
-> POST https://api.stanleymarthin.com/sm/auth/device-init
-> SessionManager.setDeviceAttestation(tempToken, deviceId)
-> /login

LoginPage
-> kumpulkan: employeeId, password, optional FCM token
-> AuthBloc(LoginRequested) → LoginUseCase → RemoteAuthDataSource.login()
-> POST https://api.stanleymarthin.com/api/v1/auth/login
-> SessionManager.login(...)
-> /home
```

### 10.2 Home & menu shell

```text
/home → HomePage
-> build menu grid dari static role map (rbac.dart)
-> user tap tile → context.push(route)
```

- Notification bell: baca `NotificationInboxService`, mark all read → push `/notifications`
- Logout tersedia dari `HomePage` dan `FeatureShellPage`

### 10.3 Task execution (operator & self-execution)

**Operator entry:**
```text
/tasks atau /overtime → TaskSectionPage → MechanicTaskPage
-> TaskBloc(LoadTodaysTasksEvent)
-> ApiTaskDataSource.getTodaysTasks()
-> GET 8086 /sm/tasks?userId=...&date=...&isOvertime=0|1
-> TaskDraftStorage.getAllDrafts()
```

**Start flow:**
```text
TaskStartSheet / StartTaskFlowEvent
-> optional UploadService.uploadPhoto(before photo)
-> StartJobUseCase → ApiTaskDataSource.startJobExecution()
-> POST 8086 /sm/tasks { action: start, plandailyId, userId, photoBefore1 }
-> TaskDraftStorage.saveDraft()
-> refresh GET /sm/tasks
```

**Submit flow:**
```text
TaskExecutionSheet / SubmitExecutionEvent
-> UploadService.uploadPhoto(process/before/after)
-> ApiTaskDataSource.submitTaskExecution()
-> PUT 8086 /sm/tasks { action: submit, ... }
-> TaskDraftStorage.deleteDraft(plandailyId)
-> refresh GET /sm/tasks
```

- FE operator sekarang menginfer sesi tertutup dari `completedAt` / progress / remaining hours saat hasil refresh GET `/sm/tasks` belum konsisten mengirim status terminal.
- Dampaknya: task yang sudah disubmit tidak lagi kembali ke CTA `Mulai`; partial submit tampil `Tercatat`, final submit tampil `Selesai`.
- Kontrak `/sm/tasks` untuk mobile task execution sekarang mengekspos blok semantik tambahan:
  - `planDaily` = jam kerja plan harian (`startTime`, `targetFinishTime`, `dailyTargetHours`)
  - `countdownCumulative` = target total, sisa aktual, akumulasi jam kerja, dan progress lintas hari
  - `executionLatest` = sesi aktual terakhir (`startedAt`, `completedAt`, `durationHours`, `status`)
- Field root lama masih dipertahankan untuk backward compatibility, tetapi parser mobile sekarang memprioritaskan blok semantik di atas.
- Detail operator menampilkan target harian, target total, sisa target, dan akumulasi dikerjakan; list tetap ringkas.
- `TaskExecutionSheet` menghitung progress submit terhadap target total (`targetHoursRevised`) dan meng-anchorkan waktu submit ke `taskDate`, bukan `DateTime.now()`.

**Alarm side effects:**
- `TaskBloc` timer tiap 15 detik untuk task in-progress
- Trigger `AlarmTimerService` reminders pada T-10, T-5, T-0
- Schedule/cancel local notification alarms via `FCMService.scheduleTaskAlarms()` / `cancelTaskAlarms()`

**Local state:** draft per-task di `SharedPreferences` key `task_draft_{plandailyId}`

### 10.4 Management task view & checkpointing

```text
/tasks atau /overtime (non-operator role) → TaskSectionPage → TaskViewPage
-> TaskViewBloc(LoadViewTasks)
-> ApiViewTaskDataSource.getViewTasks()
-> GET 8086 /sm/tasks dengan divisionID/unitID/isOvertime filters
```

- Progress monitoring management sekarang harus dibaca dari metrik kumulatif countdown (`target total - sisa`) dan checkpoint diposisikan sebagai riwayat sesi/approval, bukan satu-satunya sumber progress.

**Checkpoint flow:**
```text
TaskViewPage checkpoint dialog → TaskViewBloc
-> ApiViewTaskDataSource.saveCheckpoint()
-> POST 8086 /sm/tasks { action: checkpoint, ... }
-> refetch GET /sm/tasks
```

**Checkpoint review/edit flow:**
```text
ViewTaskCard timeline tap → TaskViewPage review dialog → TaskViewPage edit dialog
-> TaskViewBloc.updateCheckpointSession()
-> ApiViewTaskDataSource.updateCheckpointSession()
-> POST 8086 /sm/tasks { action: checkpoint, sessionNumber, ... }
-> refetch GET /sm/tasks
```

- Monitoring management tetap dicatat sebagai checkpoint pengawasan; tidak menulis ulang actual log anggota.

**Self-execution flow (ownership-first):**
- Management buka `MechanicTaskPage(forceOwnOnly: true)` dari `TaskViewPage`
- Kepala Divisi juga dapat membuka mode `PIC Saya` langsung dari tab di `TaskSectionPage`; anggota langsung masuk halaman PIC tanpa pemilih mode.
- Remote query menambahkan `scope=self` di `ApiTaskDataSource.getTodaysTasks()`

### 10.5 Job plan

```text
/plans → TaskSectionPage(kind: plan) → JobPlanPage
-> JobPlanRepositoryImpl → RemoteJobPlanDataSource
-> GET/POST/PUT 8083 /sm/job-plans*
```

Kemampuan runtime:
- Load personal plans, load approval queue, browse by date/division/unit
- Load dropdown masters dan users
- Save/get/delete draft (append mode untuk jobdesc baru; replace penuh untuk edit/hapus)
- Submit draft
- Create plan dari: countdown source, WO/WOV source, additional task source
- Approve, reject, resubmit, delete rejected, review, update
- Additional source picker sekarang mengambil master jobdesc dari dropdown yang sudah terfilter divisi dan menormalkan alias backend `job_name/name` sebelum ditampilkan ke user.
- Edit draft additional sekarang meng-hydrate ulang state form dari kombinasi `divisionId`, `carId`, `unitName`, dan `panelName`, jadi form tidak kosong walau draft hanya menyimpan id teknis.
- Source-of-truth baru untuk planning:
  - `sm_jobdesc_countdown.remaining_hours` = sisa aktual pekerjaan yang belum benar-benar dikerjakan
  - `sm_jobdesc_plan.dailyTargetHours` aktif + draft lokal = reservasi planning sementara
  - Validasi kapasitas planning sekarang memakai `available plan hours`, jadi membuat plan tidak lagi mengurangi `remaining_hours` aktual.
- Multi-job countdown di mobile tidak lagi dibagi rata buta; alokasi jam harian dibagi berurutan berdasarkan `availablePlanHours` tiap jobdesc.

Approver ADV/KP/MP: multi-select `setujui terpilih`, checkbox `pilih semua`, bottom sheet detail — kontrak notif dan endpoint approve single-item tidak berubah.

> `job_plan_page.dart` adalah file terbesar (6422 baris) dan mengandung picker dialog + form sub-pages secara monolitik.

### 10.6 Work order

```text
/work-orders → WorkOrderPage
-> WorkOrderBloc(LoadWorkOrders) → WorkOrderRemoteDataSource.getWorkOrders()
-> GET 8093 /sm/wo?view=ACTIVE|DONE
```

**Create:**
```text
FAB → WoCreatePage → WorkOrderBloc(CreateWorkOrder)
-> POST 8093 /sm/wo { action: create, ... }
```

Catatan flow aktif:
- KD pembuat hanya membuat WO + target tanggal.
- Field `QUOM` di mobile bersifat opsional; jika diisi akan dikirim sebagai `notes/catatan`, bukan field tabel terpisah.
- PIC dan jam kerja ditentukan di `WoDetailPage` saat stage `PENDING_KD_TARGET`.
- Mapper WO mobile menormalisasi alias backend lama seperti `PENDING_TARGET_KD` / `PENDING_PM`.

**Approval/extension:**
```text
WoDetailPage → WorkOrderBloc(ApproveWo / RejectWo / extension events)
-> POST 8093 /sm/wo { action: approve|reject }
-> POST 8093 /sm/wo/extensions { action: request-dl|approve-dl|... }
```

State machine: `PENDING_KD_TARGET` → `PENDING_ADVISOR` → `PENDING_KP` → `PENDING_MP` → `APPROVED` → `COUNTDOWN_CREATED` → `ON_PROGRESS` → `DONE`

Integrasi ke jobdesc/countdown:
- WO source di `JobPlanPage` membawa `sourceRefId` (req/WO id) dan `coreId` fallback dari `countdownId`.
- Status `APPROVED`, `COUNTDOWN_CREATED`, dan `ON_PROGRESS` tetap dianggap source yang masih relevan untuk WO-driven jobdesc.

Dropdown data WO create/detail diambil dari `JobPlanRepository.getDropdowns()`.

### 10.7 Countdown

```text
/countdown → CountdownPage
-> CountdownRepository.getUnits(role, division)
-> GET 8090 /sm/countdown?user_id=...
```

**Drilldown:**
```text
Unit    → getDivisions(carId)  → GET /sm/countdown?user_id=...&car_id=...
Division → getSections(...)    → GET /sm/countdown?...&division_id=...
Panel   → getJobdescs(...)     → GET /sm/countdown?...&panel_id=...
Detail  → getDetails(cntdwnId) → GET /sm/countdown?...&countdown_id=...
```

Sinkronisasi runtime:
- Saat WO final approved, backend diharapkan membuat row countdown lalu mengembalikan `coreId` atau `countdownId`; mobile memakai fallback keduanya.
- Aktual task execution yang sudah mulai/selesai dibaca kembali lewat countdown detail (`getDetails`) sehingga countdown, aktual, dan progress WO tetap saling terhubung.
- Level jobdesc countdown sekarang membawa dua angka terpisah:
  - `remaining_hours` = sisa aktual countdown
  - `available_plan_hours` / `reserved_plan_hours` = kapasitas yang masih boleh diplan vs yang sudah dibooking plan aktif

**Revision flow:**
```text
KD request  → POST 8090 /sm/countdown/revision
Submit appr → PUT 8090 /sm/countdown/action { action: submit_approval }
MO approve  → PUT 8090 /sm/countdown/action { action: approve_revision }
Mark QC rdy → PUT 8090 /sm/countdown/action { action: mark_qc_ready }
```

PM/KP mendapat tab revision approval tambahan; role lain hanya melihat countdown list.

### 10.8 Monitoring

```text
/monitoring → MonitoringPage
-> MonitoringRepository.getCars(canSeeAll, division)
-> RemoteMonitoringDataSource.getCars()
-> GET https://api.stanleymarthin.com/sm/qc/monitoring?userId=...
```

**Runtime reality:** 
Monitoring data sekarang dikonsumsi dari gateway melalui endpoint `/sm/qc/monitoring`. Namun, drilldown detail tertentu masih mungkin mensintesis data dari repeated countdown calls ke `/sm/countdown` jika endpoint monitoring belum menyediakan depth yang cukup.

Output: unit list sorted by delivery urgency, weekly report drilldown per unit/division, margin/non-margin filter.

### 10.9 QC

```text
/qc → QcTab → QcRepository.getDivisions()
-> RemoteQcDataSource.getQcDivisions()
```

- Non-management: hanya divisi session sendiri
- Management: build division list dari countdown units + countdown divisions

**QC queue:**
```text
QcUnitsPage → RemoteQcDataSource.getQcItemsByDivisionId()
-> GET 8088 /sm/qc/monitoring?userId=...&divisionId=...&page=...
```

**QC submit:**
```text
QcSubmitPage → collect: notes, duration, photos, optional rework fields
-> POST 8088 /sm/qc
Upload: GET 8088 /sm/qc/upload-ticket → PUT binary langsung
```

Recovery: QC page simpan pending recovery data di `SharedPreferences` (`pending_qc_item`) — bisa reopen unfinished QC submit setelah app interrupt.

### 10.10 Warehouse request & approval

```text
/warehouse → WarehouseRequestPage → WarehouseRepositoryImpl → RemoteWarehouseDataSource
```

**Tab behavior:**
- Approver: `Perlu Persetujuan`, `Semua Aktivitas` (Aktivitas memakai `DateFilterBar` per tanggal)
- Requester: `Pengajuan` (tanpa filter tanggal), `Sedang Dipakai`, `Riwayat` (memakai `DateFilterBar` per tanggal)

**Read flows:**
```text
getLogs()             → GET 8091 /sm/warehouse/logs
getMyItems()          → GET 8091 /sm/warehouse/my-items
getPendingApprovals() → GET 8091 /sm/warehouse/pending-approval
getStockCard()        → GET 8091 /sm/warehouse/stock-card
getStorageLocations() → GET 8091 /sm/warehouse/storage-locations
searchItems()         → GET 8091 /sm/warehouse/items/search
```

**Write flows:**
```text
Create   → POST 8091 /sm/warehouse { action: create }
Approve  → PUT  8091 /sm/warehouse { action: approve|reject }
Install  → PUT  ... { action: install }
Ready    → PUT  ... { action: ready }
Release  → PUT  ... { action: release }
Locate   → PUT  ... { action: locate }
Upload   → GET 8091 /sm/warehouse/upload-ticket → PUT binary
```

`ActiveJobPicker` digunakan requester untuk attach warehouse action ke job/task context aktif.

### 10.11 Purchase Request

```text
/pr → PrPage → direct RemotePrDataSource instantiation (tidak via DI)
-> GET 8096 /sm/pr
-> POST 8096 /sm/pr { action: create|approve }
-> PUT 8096 /sm/pr/{reqId}/finalize   (ada di datasource, belum jadi flow utama routed page)
```

### 10.12 Notifications

```text
FCM foreground/background payload
-> NotificationInboxService.save/persist → SharedPreferences
-> Home bell / NotificationsPage membaca local inbox
-> tap item → route resolution → context.push(targetRoute)
```

> Halaman notifications menggunakan local persisted inbox, **bukan** rendering langsung dari backend `/api/v1/notifications`.

### 10.13 Profile

```text
/profile → ProfilePage
-> ProfileRepository.getProfile() → GET https://api.stanleymarthin.com/api/v1/users/profile
-> fallback ke session values jika endpoint gagal
```

**Logout:**
```text
ProfilePage logout
-> RemoteProfileDataSource.logout()
-> TaskDraftStorage.clearAllDrafts()
-> SessionManager.logout()
-> /login
```

### 10.14 Alarm route

```text
Task time reminder eskalasi
-> AlarmTimerService.showForegroundAlarm()
-> appRouter.push('/alarm', extra: {...})
-> AlarmPage
```

Route support-only; bukan bagian menu navigasi.

---

## 11. Backend Microservices (inferred dari mobile)

Semua service di `be_sms/api/`. Redeploy via `be_sms/redeploy_vps.sh`.

| Service | Port | File utama | Fungsi utama |
|---|---:|---|---|
| sm_api_splash | 8080 | `api/sm_api_splash/app/main.py` | `create_temp_token()` — EdDSA JWT pre-login |
| sm_login | 8085 | `api/sm_login/app/main.py` | `login()` — validasi, BCrypt, Redis session |
| sm_job_plan | 8083 | `api/sm_job_plan/app/main.py` | Draft hydrate dari DB + approve flow |
| sm_tasks | 8086 | `api/sm_tasks/app/main.py` | CRUD task; dual scope default/`scope=self` |
| sm_job_QC | 8088 | `api/sm_job_QC/app/main.py` | `qc_inspect()` Pass/Rework/auto revision + Monitoring endpoint |
| sm_countdown | 8090 | `api/sm_countdown/app/main.py` | Countdown + revision action |
| sm_warehouse | 8091 | `api/sm_warehouse/app/main.py` | Inventaris sparepart + attach WO/Task |
| sm_wo | 8093 | `api/sm_wo/app/main.py` | WO progress + extensions |
| sm_pr | 8096 | `api/sm_pr/app/main.py` | PR + WOV |
| sm_notification | 8084 | `api/sm_notification/app/main.py` | `send_fcm()` — FCM gateway tunggal |

**sm_tasks dual scope:**
- Default: role-based monitoring; query divisi wajib sertakan traversal `parent_id`
- `scope=self`: override ke filter `assigned_user_id` (ownership-first)
- `checkpointHistory` disintesis dari actual execution jika belum ada checkpoint manual

**sm_job_plan draft hydration:**
`GET /sm/job-plans?action=draft` meng-hydrate dari `sm_jobdesc_countdown`, `cars`, `master_panels`, `sm_divisi` (join termasuk parent/child), `sm_employee` berdasarkan `coreId`/`assignedUserId`.

---

## 12. Database Files

| File | Isi | Lokasi |
|------|-----|--------|
| `sms_db-sms_db-202605081345.sql` | Schema utama seluruh sistem + seed | `/home/sahrulr/Documents/SM-MIS/be_sms/` |
| `warehouse-sms_warehouse-202605081346.sql` | Schema + seed khusus warehouse | `/home/sahrulr/Documents/SM-MIS/be_sms/` |

Relasi data utama:
```
sm_employee → sm_role → sys_permissions
sm_employee → sm_divisi (parent_id untuk sub-team)
sm_divisi   → sm_divisi (self-ref: parent_id → child sub-team)
sm_employee → sm_user_devices → FCM Token
Task        → planDaily → checkpointHistory
JobPlan     → coreId/assignedUserId → sm_jobdesc_countdown
Sparepart   → WO_ID / Task_ID (constraint sm_warehouse)
```

---

## 13. Active, Legacy & Placeholder Modules

### Aktif dan diroute

`auth`, `home`, `task_execution`, `job_plan`, `countdown`, `monitoring`, `qc`, `warehouse_request`, `work_order`, `pr`, `notifications`, `profile`

### Aktif tapi tidak diroute dari menu

`fcm_service`, `notification_inbox_service`, `upload_service`, `alarm_timer_service`, `device_signing_service`, `in_app_camera_page`

### Ada di kode, belum diroute

- `features/dashboard/` — `DashboardPage` + `OperatorDashboardOverviewPage`
- `features/approvals/` — `ApprovalsPage`
- `features/wov/` — `WovPage`
- `features/task_execution/.../tasks_page.dart`

### Local/mock tidak aktif di runtime

`LocalAuthDataSource`, `LocalCountdownDataSource`, `LocalMonitoringDataSource`, `LocalNotificationsDataSource`, `LocalJobPlanDataSource`, `LocalQcDataSource`, `LocalTaskDataSource`, `LocalViewTaskDataSource`, `LocalWarehouseDataSource`, `LocalProfileDataSource`, `LocalMockApiStore`, `core/data/dummy_data.dart`

### Placeholder/kosong

- `lib/core/services/deadline_alarm_service.dart` — file kosong
- `lib/core/services/permission_service.dart` — file kosong

---

## 14. Local Storage & Side Effects Summary

### SharedPreferences usage

| Data | Pengelola |
|------|-----------|
| Session payload | `AppSecureStorage` (wrapper SharedPrefs) |
| Task execution drafts | `TaskDraftStorage` (key: `task_draft_{plandailyId}`) |
| Notification inbox | `NotificationInboxService` |
| QC recovery state | `qc_page.dart` (key: `pending_qc_item`) |
| Camera recovery | `in_app_camera_page.dart` |
| Local mock store | `LocalMockApiStore` |

### Network side effects

- Semua feature API melalui `ApiClient` (Dio), kecuali direct upload PUT yang menggunakan `http`
- Refresh token flow terpusat di `ApiClient`
- Signed upload ticket dipakai oleh: task photos, QC photos, warehouse photos

### Device/runtime side effects

- Global wakelock aktif sepanjang sesi
- FCM permission wajib di startup — deny = app exit
- Local alarms dan modal reminder untuk task time threshold (T-10, T-5, T-0)

### Backend Redis usage & Time-Tracking (sm_job_plan & sm_tasks)

| Key Pattern | Fungsi | TTL |
|------|-----------|-----|
| `job_pool:{date}:{userId}:{carId}:{panelId}` | Menyimpan alokasi *Shared Target Hours* untuk pekerjaan Multijob pada panel yang sama. Didebit secara otomatis saat task disubmit. | 48 Jam |
| `draft_plan:{userId}` | Draft *Job Plan* sementara sebelum KD melakukan konfirmasi final submission. | - |

#### Auto-Overtime & Time-Tracking Fallback Rules (Backend)
Perhitungan lembur (OT) dan efisiensi waktu dilakukan sepenuhnya di backend melalui *multi-layer fallback*:
1. **Time-Based OT:** Melampaui jam 17:00 (14:00 Sabtu) -> Langsung Overtime.
2. **Budget-Based Fallback (Jaring 1 - Panel Pool):** Mengambil alokasi target dari `job_pool` (berbasis target KD). Jika minus, bocor ke Jaring 2.
3. **Budget-Based Fallback (Jaring 2 - Unit Budget):** Mengecek saldo total estimasi WO keseluruhan (`wo_estimated_hours - c_actual_hours`). Jika Unit Budget masih ada sisa, maka waktu bocor diselamatkan/disubstitusi oleh sisa tersebut (Bukan Overtime, tapi dikategorikan sebagai *Leakage*).
4. **Final OT:** Jika Panel Pool dan Unit Budget habis, sisa waktu sah dihitung sebagai Overtime resmi (`ot_hrs > 0`).

**Notifikasi Waktu (Push Notifications):**
- **Tugas Overtime:** Dikirim ketika `ot_hrs > 0` (gagal diselamatkan). Target: KD, ADV, KP, MP/PM.
- **Tugas Melebihi Target (Leakage):** Dikirim ketika aktual melampaui target KD harian, namun waktu bocornya berhasil diselamatkan oleh Unit Budget (tidak overbudget secara global, tapi efisiensi buruk). Target: KD, ADV, KP, MP/PM.

---

## 15. Trace Recipes

### Auth issue
```text
main.dart → SplashPage → AuthBloc → RemoteAuthDataSource → ApiEndpoints.deviceInit/login → SessionManager
```

### Task execution issue
```text
app_router.dart (/tasks|/overtime) → TaskSectionPage → MechanicTaskPage|TaskViewPage
→ TaskBloc|TaskViewBloc → TaskRepository|ViewTaskRepository
→ ApiTaskDataSource|ApiViewTaskDataSource → ApiEndpoints.tasks (/sm/tasks via gateway; legacy port 8086)
```

### Job plan issue
```text
/plans → TaskSectionPage(kind:plan) → JobPlanPage
→ JobPlanRepositoryImpl → RemoteJobPlanDataSource → ApiEndpoints.jobPlans* (/sm/job-plans via gateway; legacy port 8083)
```

### Work order issue
```text
/work-orders → WorkOrderPage|WoDetailPage|WoCreatePage → WorkOrderBloc
→ WorkOrderRepositoryImpl → WorkOrderRemoteDataSource
→ ApiEndpoints.workOrders|workOrderExtensions (/sm/wo via gateway; legacy port 8093)
```

### Countdown / monitoring issue
```text
/countdown|/monitoring → CountdownPage|MonitoringPage
→ CountdownRepositoryImpl|MonitoringRepositoryImpl
→ RemoteCountdownDataSource|RemoteMonitoringDataSource
→ ApiEndpoints.countdown* (/sm/countdown via gateway; legacy port 8090)
```

### Warehouse issue
```text
/warehouse → WarehouseRequestPage → WarehouseRepositoryImpl
→ RemoteWarehouseDataSource → ApiEndpoints.warehouse* (/sm/warehouse via gateway; legacy port 8091)
```

### Scope filter divisi bug
```text
Cek query di sm_tasks atau sm_job_plan apakah sudah:
WHERE d.id = :divisi_id OR d.parent_id = :divisi_id
Jika tidak → anggota sub-team (Mechanic team, dst) tidak ter-include
```

---

## 16. Risks / Blind Spots

| # | Area | Risiko | Mitigasi |
|---|------|--------|----------|
| 1 | **Dua sistem permission paralel** | Static FE role map dan backend permission string bisa drift jika backend berkembang tapi FE alias tidak diupdate | Sinkronkan `rbac.dart` setiap kali ada perubahan backend permission |
| 2 | **`AppSecureStorage` bukan encrypted** | Nama menyesatkan; data session di SharedPreferences (plain) | Migrasi ke `flutter_secure_storage` jika data sensitif perlu enkripsi |
| 3 | **Monitoring tanpa dedicated endpoint** | `RemoteMonitoringDataSource` mensintesis dari N countdown calls → boros request, lambat | Buat dedicated monitoring endpoint di backend |
| 4 | **DI gaps (PR, WOV, RuntimeWarmup)** | `PrPage`/`WovPage` instantiate datasource langsung; sulit di-mock | Daftarkan ke `injection.dart` |
| 5 | **Query divisi tanpa traversal `parent_id`** | Sub-team Mechanic (dan divisi lain dengan child) tidak ter-include di scope filter | Selalu `WHERE d.id = :id OR d.parent_id = :id` |
| 6 | **Tanpa ORM (backend)** | Query hardcoded string `cursor.execute()`. Relasi tabel hanya terbaca dari file `.sql` | Dokumentasikan skema relasi; gunakan ORM di service baru |
| 7 | **Fragmentasi `.env-dev`** | Tiap microservice punya file `.env-dev` sendiri; sinkronisasi manual | Gunakan `.env` shared atau secret manager |
| 8 | **Legacy port mode masih tersedia** | Build dengan `BASE_URL=http://108.136.189.225` tetap request ke port 8080–8096 langsung dan lebih rapuh dari gateway HTTPS | Production build harus memakai default `https://api.stanleymarthin.com`; legacy hanya untuk emergency/debug |
| 9 | **Redis tanpa persistensi** | Restart container Redis menghapus semua session aktif | Aktifkan `appendonly yes` atau set TTL |
| 10 | **File placeholder kosong** | `deadline_alarm_service.dart`, `permission_service.dart` — bisa menyesatkan saat tracing | Hapus atau isi implementasi |
| 11 | **`job_plan_page.dart` 6422 baris** | File monolitik, mixed responsibilities, rawan cross-feature coupling | Pecah ke sub-widget/page bertahap |

---

## 17. What Not To Assume

- Jangan asumsikan backend folder ada di workspace mobile.
- Jangan asumsikan `/dashboard` menggunakan `DashboardPage` — route redirect ke `/home`.
- Jangan asumsikan monitoring menggunakan dedicated backend monitoring endpoint di runtime.
- Jangan asumsikan halaman notifications di-render dari backend notification list — ini local inbox.
- Jangan asumsikan `AppSecureStorage` terenkripsi.
- Jangan asumsikan `CountdownRepositoryImpl` punya QC enrichment aktif — `qcDataSource` tidak diinjek di DI saat ini.

---

## 19. Development Rules

### TDD Mandatory (Test-Driven Development)
Semua fitur baru atau perbaikan bug yang melibatkan logic kompleks (Usecase, Repository, Bloc, Service) **WAJIB** diawali dengan pembuatan unit test atau widget test. 
- Alur: `Create Test (Red) -> Implementation (Green) -> Refactor`.
- Folder test harus mengikuti struktur folder `lib`.

---

## 20. Update Rule

File ini wajib diperbarui dalam sesi yang sama jika salah satu dari berikut berubah:

- Route name atau route target di `app_router.dart`
- Registrasi dependency di `injection.dart`
- API base port atau endpoint path di `api_endpoints.dart`
- Primary feature ownership dari page/repository/datasource
- Aktivasi/deaktivasi modul legacy (`dashboard`, `approvals`, `wov`)
- Hierarki role atau struktur divisi (`sm_divisi`, `parent_id`)
- Port atau service baru di `docker-compose.yml`
