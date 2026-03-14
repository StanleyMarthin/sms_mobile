

| MOBILE API CONTRACT Restoration Workshop Management System Mobile Integration Specification  |  Version 1.0 |
| :---: |

| 27 API Endpoints | 4 Roles | 8 Modules | JWT Auth Method |
| :---: | :---: | :---: | :---: |

# **1\. Overview**

| Base URL  &  Authentication |
| :---- |

| Base URL | https://{host}/api/v1 |
| :---- | :---- |
| **Auth Header** | Authorization: Bearer {JWT\_TOKEN} |
| **Content-Type** | application/json  (multipart/form-data for file uploads) |

| Standard Response Format |
| :---- |

| Success Response {   "success": true,   "message": "Snackbar message",   "data": { ... } }  | Error Response {   "success": false,   "error": "ERROR\_CODE",   "message": "Pesan snackbar" }  |
| :---- | :---- |

# **2\. Role-Based Access Summary**

| Role | Menu Mobile | Capabilities |
| :---: | :---- | :---- |
| **OP** | Dashboard Tasks Warehouse Notifications Profile | Start Task Submit Task Warehouse Request Lihat notifikasi personal |
| **KD** | Dashboard Units Tasks Job Plan QC Warehouse Approval Notifications Profile | Create Job Plan Approve Warehouse Request QC Inspection Monitor Division Progress |
| **ADV** | Dashboard Units Tasks Review Task QC Validation Work Orders Notifications Profile | Quality Control Task Approval WO Approval Validasi QC |
| **PM** | Dashboard Units Tasks Job Plan Work Orders QC Validation Monitoring Notifications Profile | Global Access semua divisi Approve WO Final QC Validation Monitoring seluruh project |

# **3\. API Endpoint Index**

| Method | Endpoint | Description |
| :---: | :---- | :---- |
| **POST** | **/auth/device-init** | Device initialization & app version check |
| **POST** | **/auth/login** | User authentication, JWT generation |
| **GET** | **/tasks** | List tasks (role-filtered) |
| **POST** | **/job-plans** | Create daily job plan |
| **PATCH** | **/job-plans/{planId}/review** | Approve or reject job plan |
| **PUT** | **/job-plans/{id}** | Update job plan target/deadline |
| **POST** | **/tasks/start** | Start task execution (OP) |
| **POST** | **/tasks/submit** | Submit task result |
| **POST** | **/tasks/assign** | Assign task to mechanic |
| **POST** | **/tasks/checkpoint** | Record patrol checkpoint |
| **GET** | **/units/in-progress** | List units being worked on |
| **GET** | **/countdown** | Countdown / section progress |
| **GET** | **/countdown/{sectionId}/detail** | Countdown work history detail |
| **GET** | **/qc** | QC inbox / checkpoint queue |
| **POST** | **/qc** | Submit QC checkpoint by KD |
| **PUT** | **/qc/{qcId}/validate** | Stage validation by ADV or PM |
| **GET** | **/work-orders** | List all work orders |
| **POST** | **/work-orders** | Create new work order |
| **PUT** | **/work-orders/{reqId}/approve-advisor** | Advisor approval of WO |
| **PUT** | **/work-orders/{reqId}/approve-pm** | PM final approval of WO |
| **POST** | **/warehouse** | Warehouse transaction (borrow/take/return) |
| **PUT** | **/warehouse/{logId}/approve** | KD approve warehouse request |
| **GET** | **/warehouse** | Warehouse transaction logs |
| **GET** | **/monitoring/cars** | Car progress overview |
| **GET** | **/monitoring/cars/{carId}/divisions** | Division progress per car |
| **GET** | **/notifications** | Notification history |
| **GET** | **/users/profile** | User profile data |

# **4\. API Endpoint Details**

## **4.1  Auth Module**

| \#1  POST  /auth/device-init Device initialization, app version check, register/update device record |  |
| :---- | :---- |
| **Screen** | Splash Screen |
| **Role** | Guest (unauthenticated) |
| **Permission** | — |
| **Request Body** | {   "deviceId": "a1b2c3...",   "deviceModel": "Samsung S23",   "osVersion": "Android 14",   "appVersion": "1.0.1",   "timestamp": "2026-03-05T08:00:00Z",   "location": { "lat": \-6.2, "lng": 106.8 },   "hmacSignature": "abc123..." } |
| **Response OK** | {   "success": true,   "versionStatus": "LATEST",   "tempToken": "eyJhbGc...",   "validForServices": \["login"\] } |
| **Response Err** | {   "success": false,   "error": "FORCE\_UPDATE",   "message": "Harap update aplikasi ke versi terbaru" } |

| \#2  POST  /auth/login Authenticate user and return JWT with role, permissions, and user data |  |
| :---- | :---- |
| **Screen** | Login Screen |
| **Role** | Guest (unauthenticated) |
| **Permission** | — |
| **Request Body** | {   "employeeId": "EMP001",   "password": "password",   "fcmToken": "fcm\_token\_xyz" } |
| **Response OK** | {   "success": true,   "token": "eyJhbGc...",   "user": {     "fullname": "Adam",     "division": "Mechanic",     "grade": "Kepala Divisi",     "roleName": "KD",     "permissions": \["view\_tasks", "create\_job\_plan", "submit\_qc"\]   } } |
| **Response Err** | {   "success": false,   "error": "INVALID\_CREDENTIALS",   "message": "ID atau password salah" } |

## **4.2  Task Module**

| \#3  GET  /tasks List tasks filtered by role. OP: own tasks only. KD: division tasks. ADV/PM: all. |  |
| :---- | :---- |
| **Screen** | Task List |
| **Role** | OP / KD / ADV / PM |
| **Permission** | view\_tasks |
| **Request Body** | Query Params:   type=daily|overtime|plan   date=2026-03-05   divisionId=uuid   unitId=uuid   status=PROSES|DONE|ASSIGNED   page=1   limit=20 |
| **Response OK** | {   "success": true,   "type": "daily",   "filters": { "date": "2026-03-05", "divisionId": "uuid" },   "data": \[{     "planDailyId": "uuid",     "division": { "divisionId": "uuid", "divisionName": "Mechanic" },     "unit": { "unitId": "uuid", "unitName": "Ferrari F355" },     "employee": { "employeeId": "uuid", "employeeName": "Budi" },     "task": {       "namaPanel": "Panel A",       "jobName": "Pemasangan",       "jobDescription": "Pemasangan panel dashboard",       "startTime": "08:00",       "targetFinishTime": "12:00",       "is\_rework": 0     },     "status": "PROSES"   }\] } |
| **Response Err** | { "success": false, "error": "UNAUTHORIZED" } |

| \#4  POST  /job-plans Create daily job plan based on Core Job (Master Task). Validates against budget hours. |  |
| :---- | :---- |
| **Screen** | Task List / Create Job Plan |
| **Role** | KD / PM |
| **Permission** | create\_task |
| **Request Body** | {   "coreId": "uuid",   "assignedUserId": "uuid",   "taskDate": "2026-03-05",   "jobDescription": "Pemasangan panel listrik",   "targetStartHours": "08:00",   "targetFinishHours": "12:00",   "isOvertime": false,   "isRework": false,   "isPriority": false,   "note": "Prioritas selesai hari ini" } |
| **Response OK** | {   "success": true,   "message": "Job plan berhasil dibuat",   "plandailyId": "uuid" } |
| **Response Err** | {   "success": false,   "error": "OVER\_BUDGET",   "message": "Jam kerja melebihi budget yang tersedia" } |

| \#5  PATCH  /job-plans/{planId}/review Advisor or PM approves or rejects task. Approved tasks become visible to Operator. |  |
| :---- | :---- |
| **Screen** | Task List / Review Task |
| **Role** | ADV / PM |
| **Permission** | review\_task |
| **Request Body** | // Approve: { "action": "APPROVE" }   // Reject: {   "action": "REJECT",   "rejectNotes": "Harus bongkar dashboard dulu" } |
| **Response OK** | {   "success": true,   "status": "APPROVED" } // or {   "success": true,   "status": "REJECTED" } |
| **Response Err** | {   "success": false,   "error": "REJECT\_NOTE\_REQUIRED",   "message": "Catatan wajib diisi saat reject" } |

| \#6  PUT  /job-plans/{id} Update target hours or deadline on an existing Job Plan. |  |
| :---- | :---- |
| **Screen** | Edit Plan |
| **Role** | KD / PM |
| **Permission** | update\_plan |
| **Request Body** | {   "newTargetHours": 10.5,   "newDeadline": "2026-03-10" } |
| **Response OK** | {   "success": true,   "message": "Plan diupdate" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_ID",   "message": "Job plan tidak ditemukan" } |

| \#7  POST  /tasks/start Mechanic starts a task. Creates initial record in sm\_jobdesc\_actual. |  |
| :---- | :---- |
| **Screen** | Task List |
| **Role** | OP |
| **Permission** | submit\_task |
| **Request Body** | {   "plandailyId": "uuid",   "userId": "uuid",   "start\_time": "08:00",   "photoBefore": "\<file\>" } |
| **Response OK** | {   "success": true,   "message": "Task berhasil dimulai",   "startTime": "2026-03-05T08:01:00Z" } |
| **Response Err** | {   "success": false,   "error": "TASK\_ALREADY\_STARTED",   "message": "Task sudah dimulai sebelumnya" } |

| \#8  POST  /tasks/submit Submit actual work result for daily or overtime task. |  |
| :---- | :---- |
| **Screen** | Task List |
| **Role** | OP |
| **Permission** | submit\_tasks |
| **Request Body** | multipart/form-data:   plandailyId: uuid   finishTime: timestamp   breakDurationMinutes: 30   progressPercent: 100   status: DONE   photoProcess: \<file\>   photoAfter: \<file\>   dailyNotes: "Selesai tanpa kendala" |
| **Response OK** | {   "success": true,   "message": "Log kerja berhasil disimpan",   "actualLogId": "uuid",   "durationHours": 3.0,   "status": "DONE" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_TASK",   "message": "Task tidak valid atau tidak ditemukan" } |

| \#9  POST  /tasks/assign Assign task from master plan to a mechanic. |  |
| :---- | :---- |
| **Screen** | Task List |
| **Role** | KD / PM |
| **Permission** | submit\_tasks |
| **Request Body** | {   "coreId": "uuid",   "assignedUserId": "uuid",   "taskDate": "2026-03-05",   "plan\_starttime": "08:00",   "plan\_finishtime": "12:00",   "dailyTargetHours": 4.0,   "isOvertime": false } |
| **Response OK** | {   "success": true,   "message": "Tugas berhasil di-assign",   "plandailyId": "uuid" } |
| **Response Err** | {   "success": false,   "error": "OVER\_BUDGET",   "message": "Total jam melebihi budget pekerjaan" } |

| \#10  POST  /tasks/checkpoint Record patrol checkpoint to monitor mechanic progress. |  |
| :---- | :---- |
| **Screen** | Task List |
| **Role** | KD / ADV / PM |
| **Permission** | submit\_tasks |
| **Request Body** | {   "plandailyId": "uuid",   "progressFinal": 80,   "status": "onprogress",   "monitoringCheckpoints": \[     { "time": "09:00", "progress": 20, "note": "Mulai" },     { "time": "10:30", "progress": 40, "note": "Analisis" }   \] } |
| **Response OK** | {   "success": true,   "message": "Monitoring berhasil disimpan",   "totalCheckpoints": 4,   "progressFinal": 80 } |
| **Response Err** | {   "success": false,   "error": "INVALID\_TASK",   "message": "Task tidak ditemukan" } |

## **4.3  Countdown Module**

| \#11  GET  /units/in-progress List vehicles currently being worked on. KD only sees own division units. |  |
| :---- | :---- |
| **Screen** | Countdown \- Unit List |
| **Role** | KD / PM |
| **Permission** | view\_units |
| **Request Body** | Query Params:   division=mechanic   typeRestoration=full\_restoration |
| **Response OK** | {   "success": true,   "data": \[{     "carId": "uuid",     "unitName": "Ferrari F355",     "owner": "Mr. Silmy",     "progress": 45,     "status": "PROSES"   }\] } |
| **Response Err** | {   "success": false,   "error": "DATA\_NOT\_FOUND",   "message": "Tidak ada unit ditemukan" } |

| \#12  GET  /countdown List sections/core jobs of a selected unit with progress, hours, deadline, and QC-derived effective status. |  |
| :---- | :---- |
| **Screen** | Countdown \- Section List |
| **Role** | KD / PM |
| **Permission** | view\_countdown |
| **Request Body** | Query Params:   carId=uuid  (required)   page=1   limit=20   status=PROSES|WAITING\_QC|DONE   taskCategory=MAIN|ADDITIONAL  (optional backend filter, hidden in mobile UI)   sort=deadlineAsc |
| **Response OK** | {   "success": true,   "data": \[{     "sectionId": "CD-FIAT-001",     "panelName": "DASHBOARD DEPAN",     "taskCategory": "MAIN",     "progress": 100,     "status": "DONE",     "effectiveStatus": "WAITING_QC",     "estimatedHours": 16,     "workedHours": 16,     "remainingHours": 0,     "deadline": "2026-03-03",     "qcId": "qc-uuid",     "qcValidationStatus": "WAITING_KD",     "qcResultStatus": null,     "estimatedReworkHours": null,     "reworkDeadlineDate": null,     "qcNotes": null   }\],   "pagination": { "page": 1, "limit": 20, "total": 150, "hasNext": true } } |
| **Response Err** | {   "success": false,   "error": "CAR\_ID\_REQUIRED",   "message": "Parameter carId wajib diisi" } |

| \#13  GET  /countdown/{sectionId}/detail Work history detail for a specific section/core job. |  |
| :---- | :---- |
| **Screen** | Countdown \- Detail |
| **Role** | KD / PM |
| **Permission** | view\_countdown\_detail |
| **Request Body** | Path: /countdown/{sectionId}/detail Query Params:   page=1   limit=50 |
| **Response OK** | {   "success": true,   "data": \[{     "id": "1dabb310...",     "employeeName": "HARIS",     "job": "Assessment & Teardown",     "detailJob": "PEMBONGKARAN DASHBOARD DARI UNIT",     "workDate": "2026-03-01",     "startTime": "2026-03-01 08:00:00",     "finishTime": "2026-03-01 10:00:00",     "durationHours": 2,     "percentage": 10,     "status": "DONE"   }\],   "pagination": { "page": 1, "limit": 50, "total": 12 } } |
| **Response Err** | {   "success": false,   "error": "SECTION\_ID\_REQUIRED" } |

## **4.4  QC Module**

| \#14  GET  /qc QC inbox / checkpoint queue for items that need KD submit or ADV/PM validation. |  |
| :---- | :---- |
| **Screen** | QC List |
| **Role** | KD / ADV / PM |
| **Permission** | view\_qc |
| **Request Body** | Query Params:   date=2026-03-05   division=mechanic   validationScope=assigned|all |
| **Response OK** | {   "success": true,   "data": \[{     "qcId": "qc-uuid",     "coreId": "CD-FIAT-001",     "unitName": "Ferrari F355",     "panelName": "DASHBOARD DEPAN",     "jobName": "Dashboard Assembly",     "mechanicName": "HARIS",     "mechanicDivision": "mechanic",     "targetHoursRevised": 10,     "totalActualHours": 10,     "validationStatus": "WAITING_ADV",     "resultStatus": "TIDAK_LOLOS",     "qcNotes": "Belang di panel dashboard",     "kdRemainingHours": 12.0,     "estimatedReworkHours": 2.0,     "reworkDeadlineDate": "2026-03-06",     "kdCheckpointBy": "Adam",     "kdCheckpointAt": "2026-03-05T10:30:00Z",     "advValidatedBy": null,     "advValidatedAt": null,     "pmValidatedBy": null,     "pmValidatedAt": null   }] } |
| **Response Err** | {   "success": false,   "error": "INVALID\_FILTER",   "message": "Filter QC tidak valid" } |

| \#15  POST  /qc Submit QC checkpoint by Kepala Divisi. Rework hours and deadline are mandatory when result is TIDAK\_LOLOS. |  |
| :---- | :---- |
| **Screen** | QC Check |
| **Role** | KD |
| **Permission** | submit\_qc |
| **Request Body** | {   "coreId": "CD-FIAT-001",   "resultStatus": "TIDAK\_LOLOS",   "kdRemainingHours": 12.0,   "estimatedReworkHours": 2.0,   "reworkDeadlineDate": "2026-03-06",   "notes": "Belang di panel dashboard",   "checkedAt": "2026-03-05T10:30:00Z" } |
| **Response OK** | {   "success": true,   "message": "Checkpoint KD tercatat",   "data": {     "qcId": "qc-uuid-baru",     "validationStatus": "WAITING_ADV",     "resultStatus": "TIDAK_LOLOS"   } } |
| **Response Err** | {   "success": false,   "error": "INVALID\_STATUS",   "message": "Status QC tidak valid" } |

| \#16  PUT  /qc/{qcId}/validate Stage validation for ADV or PM. ADV moves item to WAITING\_PM, PM closes validation into VALIDATED. |  |
| :---- | :---- |
| **Screen** | QC Validate |
| **Role** | ADV / PM |
| **Permission** | validate\_qc |
| **Request Body** | {   "notes": "Validasi advisor selesai",   "validatedAt": "2026-03-05T13:00:00Z" } |
| **Response OK** | {   "success": true,   "message": "QC divalidasi",   "data": {     "qcId": "qc-uuid",     "validationStatus": "WAITING_PM",     "resultStatus": "TIDAK_LOLOS",     "advValidatedBy": "Budi",     "advValidatedAt": "2026-03-05T13:00:00Z",     "pmValidatedBy": null,     "pmValidatedAt": null   } } |
| **Response Err** | {   "success": false,   "error": "QC\_ALREADY\_VALIDATED",   "message": "QC sudah divalidasi sebelumnya" } |

## **4.5  Work Order Module**

| \#17  GET  /work-orders List WO Internal, WO Vendor, and Purchase Request with status filters. |  |
| :---- | :---- |
| **Screen** | Work Orders |
| **Role** | KD / ADV / PM |
| **Permission** | list\_work\_orders |
| **Request Body** | Query Params:   reqType=ALL|WO\_INTERNAL|WO\_VENDOR|PR   status=PENDING|APPROVED   view=INCOMING|OUTGOING   page=1   limit=20 |
| **Response OK** | {   "success": true,   "data": \[{     "reqId": "uuid",     "reqType": "WO\_VENDOR",     "reqNumber": "WOV/001",     "targetName": "Sinar Chrome",     "detail": "Bumper",     "status": "PENDING\_APPROVAL"   }\] } |
| **Response Err** | { "success": false, "error": "SERVER\_ERROR" } |

| \#18  POST  /work-orders Create WO Internal, WO Vendor, or Purchase Request. |  |
| :---- | :---- |
| **Screen** | Work Orders |
| **Role** | KD |
| **Permission** | create\_work\_order |
| **Request Body** | {   "reqType": "WO\_INTERNAL",   "carId": "uuid",   "targetId": "uuid-divisi",   "jobOrItemDetail": "Bongkar Mesin",   "estimatedCostOrHours": 3.0,   "targetDate": "2026-03-10" } |
| **Response OK** | {   "success": true,   "message": "Work Order berhasil dibuat",   "reqId": "uuid-wo" } |
| **Response Err** | {   "success": false,   "error": "VALIDATION\_ERROR",   "message": "Data tidak lengkap atau tidak valid" } |

| \#19  PUT  /work-orders/{reqId}/approve-advisor Advisor validates Work Order before forwarding to PM. |  |
| :---- | :---- |
| **Screen** | Work Orders |
| **Role** | ADV |
| **Permission** | approve\_wo\_advisor |
| **Request Body** | { "advisorNotes": "ACC, siap diteruskan ke PM" } |
| **Response OK** | {   "success": true,   "message": "WO disetujui Advisor" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_STATUS",   "message": "Status WO tidak sesuai untuk diapprove" } |

| \#20  PUT  /work-orders/{reqId}/approve-pm PM gives final approval. System auto-creates Countdown with budget hours. |  |
| :---- | :---- |
| **Screen** | Work Orders |
| **Role** | PM |
| **Permission** | approve\_wo\_pm |
| **Request Body** | { "pmNotes": "Lanjutkan pekerjaan" } |
| **Response OK** | {   "success": true,   "message": "WO disetujui PM dan countdown dibuat",   "countdownId": "uuid-countdown" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_STATUS",   "message": "WO belum melewati approval advisor" } |

## **4.6  Warehouse Module**

| \#21  POST  /warehouse All warehouse transactions: borrow tools, take parts/materials, or return items. |  |
| :---- | :---- |
| **Screen** | Warehouse Transaction |
| **Role** | OP |
| **Permission** | warehouse\_transaction |
| **Request Body** | // Borrow Tools: {   "transactionType": "PEMINJAMAN",   "itemCategory": "TOOLS",   "itemName": "Kunci T",   "qty": 1, "uom": "PCS",   "coreId": "uuid",   "notes": "Untuk buka dashboard" }   // Take Sparepart: {   "transactionType": "PENGAMBILAN",   "itemCategory": "SPARE\_PART",   "itemName": "Baut M10",   "qty": 10, "uom": "PCS",   "carId": "uuid", "coreId": "uuid" }   // Return Item: {   "transactionType": "PENGEMBALIAN",   "logId": "uuid-log",   "returnNotes": "Aman tidak ada kerusakan" } |
| **Response OK** | {   "success": true,   "message": "Warehouse transaction success",   "logId": "uuid-log" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_TRANSACTION",   "message": "Tipe transaksi tidak valid" } |

| \#22  PUT  /warehouse/{logId}/approve Kepala Divisi approves a warehouse request (material or sparepart). |  |
| :---- | :---- |
| **Screen** | Warehouse Approval |
| **Role** | KD |
| **Permission** | approve\_request |
| **Request Body** | { "notes": "Silakan ambil di gudang restorasi" } |
| **Response OK** | {   "success": true,   "message": "Request disetujui KD" } |
| **Response Err** | {   "success": false,   "error": "INVALID\_STATUS",   "message": "Request sudah diproses sebelumnya" } |

| \#23  GET  /warehouse View transaction history for borrowing, taking, and returning warehouse items. |  |
| :---- | :---- |
| **Screen** | Warehouse Logs |
| **Role** | KD / OP |
| **Permission** | list\_logs |
| **Request Body** | Query Params:   itemCategory=TOOLS|SPARE\_PART|BAHAN   status=OPEN|RETURNED|APPROVED   page=1   limit=20   tanggal=03/03/2026 |
| **Response OK** | {   "success": true,   "data": \[{     "logId": "uuid",     "transactionType": "PEMINJAMAN",     "itemName": "Kunci T",     "qty": 1,     "status": "OPEN",     "createdAt": "2026-03-05T08:00:00Z"   }\] } |
| **Response Err** | {   "success": false,   "error": "INVALID\_LOG",   "message": "Log tidak ditemukan" } |

## **4.7  Monitoring Module**

| \#24  GET  /monitoring/cars View progress per vehicle. KD sees own division only; ADV/PM see all divisions. |  |
| :---- | :---- |
| **Screen** | Progress Mobil |
| **Role** | KD / ADV / PM |
| **Permission** | list\_car\_progress |
| **Request Body** | Query Params:   status=IN\_PROGRESS|DONE   page=1   limit=20 |
| **Response OK** | {   "success": true,   "data": \[{     "carId": "uuid-car",     "unitName": "Ferrari F355",     "avgProgressPercentage": 65   }\] } |
| **Response Err** | {   "success": false,   "error": "DATA\_NOT\_FOUND",   "message": "Tidak ada data monitoring ditemukan" } |

| \#25  GET  /monitoring/cars/{carId}/divisions Per-division progress breakdown for a specific vehicle. |  |
| :---- | :---- |
| **Screen** | Progress Mobil Detail |
| **Role** | KD / ADV / PM |
| **Permission** | car\_progress\_detail |
| **Request Body** | Path Param: /monitoring/cars/{carId}/divisions |
| **Response OK** | {   "success": true,   "data": \[     { "divisionId": 1, "divisionName": "Body PAINT", "progressPercentage": 70 },     { "divisionId": 2, "divisionName": "BODY WORK", "progressPercentage": 55 },     { "divisionId": 3, "divisionName": "Interior", "progressPercentage": 60 }   \] } |
| **Response Err** | {   "success": false,   "error": "DATA\_NOT\_FOUND",   "message": "Data mobil tidak ditemukan" } |

## **4.8  Notifications & Profile**

| \#26  GET  /notifications Fetch notification history. Realtime via WebSocket; this endpoint is for history only. |  |
| :---- | :---- |
| **Screen** | Notifications |
| **Role** | All Roles |
| **Permission** | list\_notifications |
| **Request Body** | Query Params:   limit=10   page=1 |
| **Response OK** | {   "success": true,   "data": \[{     "id": "uuid",     "title": "WO Baru Masuk",     "body": "Bongkar bemper",     "isRead": false,     "createdAt": "2026-03-05T10:30:00Z"   }\] } |
| **Response Err** | {   "success": false,   "error": "UNAUTHORIZED",   "message": "Token tidak valid" } |

| \#27  GET  /users/profile Fetch logged-in user's profile data. |  |
| :---- | :---- |
| **Screen** | Profile |
| **Role** | All Roles |
| **Permission** | user\_profile |
| **Request Body** | Header only: Authorization: Bearer {token} |
| **Response OK** | {   "success": true,   "data": {     "employeeId": "EMP001",     "fullName": "Adam",     "email": "adam@system.com",     "role": "KD",     "division": "Body Repair",     "grade": "Senior",     "isActive": true   } } |
| **Response Err** | {   "success": false,   "error": "UNAUTHORIZED",   "message": "Token expired atau tidak valid" } |

# **5\. Status State Machines**

### **5.1  Job Plan Status Flow**

| Job Plan Status |  |  |
| :---: | :---: | :---: |
| PLAN\_CREATED | → | PENDING\_ADV |
| PENDING\_ADV | → | PENDING\_PM  or  REJECTED |
| PENDING\_PM | → | APPROVED  or  REJECTED |
| APPROVED | → | ON\_PROGRESS |
| ON\_PROGRESS | → | DONE |

### **5.2  Task Execution Status Flow**

| Task Execution Status |  |  |
| :---: | :---: | :---: |
| ASSIGNED | → | ON\_PROGRESS |
| ON\_PROGRESS | → | SUBMITTED |
| SUBMITTED | → | DONE |

### **5.3  QC Status Flow**

| QC Status |  |  |
| :---: | :---: | :---: |
| WAITING\_KD | → | WAITING\_ADV |
| WAITING\_ADV | → | WAITING\_PM |
| WAITING\_PM | → | VALIDATED |

Checkpoint Result Notes:

- `VALIDATED + LOLOS` means Countdown effective status becomes `DONE`.
- `VALIDATED + TIDAK_LOLOS` means Countdown effective status returns to `PROSES` with rework hours and deadline.
- Raw Countdown work can already be `DONE`, but mobile should show `WAITING_QC` until QC reaches `VALIDATED + LOLOS`.

### **5.4  Work Order Status Flow**

| Work Order Status |  |  |
| :---: | :---: | :---: |
| CREATED | → | PENDING\_TARGET\_KD |
| PENDING\_TARGET\_KD | → | PENDING\_ADVISOR |
| PENDING\_ADVISOR | → | PENDING\_PM |
| PENDING\_PM | → | APPROVED |
| APPROVED | → | COUNTDOWN\_CREATED |

### **5.5  Warehouse Transaction Status Flow**

| Warehouse Status |  |  |
| :---: | :---: | :---: |
| REQUESTED | → | PENDING\_KD  (bahan/sparepart) |
| PENDING\_KD | → | APPROVED |
| APPROVED  /  AUTO (tools) | → | TAKEN |
| TAKEN | → | RETURNED |

# **6\. Screen → API Mapping**

| Screen | Role | API | Description |
| :---- | :---- | :---- | :---- |
| Splash Screen | Guest | POST /auth/device-init | Validasi device dan versi aplikasi |
| Login Screen | Guest | POST /auth/login | Login user |
| Dashboard | All | GET /monitoring/cars | Menampilkan progress mobil |
| Task List | OP/KD/ADV/PM | GET /tasks | Daftar tugas |
| Start Task | OP | POST /tasks/start | Memulai pekerjaan |
| Submit Task | OP | POST /tasks/submit | Mengirim hasil pekerjaan |
| Create Job Plan | KD/PM | POST /job-plans | Membuat tugas untuk mekanik |
| Review Task | ADV/PM | PATCH /job-plans/{id}/review | Approve atau reject tugas |
| Units List | KD/ADV/PM | GET /units/in-progress | Mobil sedang dikerjakan |
| Countdown Section | KD/ADV/PM | GET /countdown | Detail pekerjaan mobil dengan effective status termasuk WAITING_QC |
| Countdown Detail | KD/ADV/PM | GET /countdown/{id}/detail | History pekerjaan |
| QC List | KD/ADV/PM | GET /qc | Daftar item checkpoint/QC sesuai tahap validasi |
| QC Form | KD | POST /qc | Submit checkpoint KD |
| QC Validation | ADV/PM | PUT /qc/{qcId}/validate | Validasi bertahap ADV lalu PM |
| Work Orders List | KD/ADV/PM | GET /work-orders | Daftar WO |
| Create WO | KD | POST /work-orders | Membuat WO |
| Approve WO (Advisor) | ADV | PUT /work-orders/{id}/approve-advisor | Approve advisor |
| Approve WO (PM) | PM | PUT /work-orders/{id}/approve-pm | Approve PM |
| Warehouse Request | OP | POST /warehouse | Request tools/bahan |
| Warehouse Approval | KD | PUT /warehouse/{id}/approve | Approval request |
| Warehouse Logs | OP/KD | GET /warehouse | History transaksi |
| Notifications | All | GET /notifications | List notifikasi |
| Profile | All | GET /users/profile | Data profil |

# **7\. Mobile UX & Integration Standards**

### **7.1  Snackbar Feedback Standard**

| Type | Trigger | Example Message |
| :---- | :---- | :---- |
| **SUCCESS** | success: true, with message | Snackbar.show("Task berhasil disimpan") |
| **ERROR** | success: false, with error code | Snackbar.show("Jam kerja melebihi budget") |
| **WARNING** | Duplicate action detected | Snackbar.show("Task sudah dimulai sebelumnya") |

### **7.2  Caching Strategy**

| Cache Target | TTL | Invalidation Trigger |
| :---- | :---- | :---- |
| Units List | 5 menit | WO approved / car added |
| Countdown Data | 5 menit | Task submit / QC submit |
| Task List | 5 menit | Job plan created / reviewed |
| User Profile | 30 menit | Profile updated |

### **7.3  Realtime Events (WebSocket / Firebase)**

| Event | Trigger | Target Role |
| :---- | :---- | :---- |
| task\_assigned | Job plan APPROVED | OP |
| task\_rejected | Job plan REJECTED | KD |
| task\_approved | Job plan APPROVED by PM | KD |
| wo\_created | WO dibuat oleh KD | ADV / PM |
| qc\_failed | QC TIDAK\_LOLOS | KD |
| warehouse\_approved | Warehouse request approved | OP |

| Mobile API Contract v1.0 Restoration Workshop Management System  |  Confidential |
| :---: |

