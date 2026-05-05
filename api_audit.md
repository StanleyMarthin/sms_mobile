# Audit API Coverage: Mobile vs MOBILE_API_CONTRACT.md

Referensi: [/home/sahrulr/Documents/SM-MIS/be_sms/MOBILE_API_CONTRACT.md](file:///home/sahrulr/Documents/SM-MIS/be_sms/MOBILE_API_CONTRACT.md)

---

## Legend
- ✅ Sesuai kontrak
- ⚠️ Minor gap / perlu perhatian
- ❌ Bug / mismatch yang perlu difix

---

## 1. Auth (sm_login)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `POST /sm/auth/device-init` | `ApiEndpoints.deviceInit` | `http://...:8080/sm/auth/device-init` | ✅ |
| `POST /api/v1/auth/login` | payload: `employeeId`, `password`, `fcmToken` | id: `employeeId`, pw: `password`, fcm: `fcmToken` | ✅ |
| Login response parse | `rawData['token']`, `rawData['user']` | `data.token`, `data.user` | ✅ |

---

## 2. Tasks (sm_tasks :8086)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `GET /sm/tasks` | query: `type`, `date`, `userId` | query wajib: **`userId`** + `date` | ✅ |
| `POST /sm/tasks` (start) | JSON: `action: "start"`, `plandailyId`, `userId`, `startTime`, `photoBefore1/2` | JSON: `action: "start"`, `plandailyId`, `userId`, `photoBefore1/2` | ✅ |
| `PUT /sm/tasks` (submit) | multipart: `action`, `plandailyId`, `userId`, `startTime`, `finishTime`, `progressPercent`, `status`, photos | JSON: `action: "submit"`, `startTime`, `finishTime`, `progressPercent`, `dailyNotes`, photos | ✅ |
| GET response mapping | `division.divisionName`, `unit.unitId`, `task.namaPanel`, `task.jobName` | Sama | ✅ |

**Fix yang dibutuhkan:**
- Tambah `userId` ke query GET tasks
- Start task: ganti multipart ke JSON POST dengan `action: "start"`
- Submit: tambah `action: "submit"`, `startTime` ke payload

---

## 3. Job Plan (sm_job_plan :8083)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `GET /sm/job-plans` | query: [status](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/presentation/widgets/wo_card.dart#624-643), `role`, `userId`, `divisionId`, `limit`, `offset` | ✅ | ✅ |
| `POST /sm/job-plans` (create) | `action: "create"/"create-additional"`, `creatorRoleId`, `plans[{coreId, assignedUserId, taskDate, targetStartHours, targetFinishHours, isOvertime, isRework, isPriority}]` | `action: "create"`, `creatorRoleId`, `plans[{coreId, assignedUserId, taskDate, jobDescription, targetStartHours, targetFinishHours}]` | ✅ |
| `PUT /sm/job-plans` (approve) | `action: "approve"/"reject"`, `role`, `plans[{planId}]` | `action: "approve"`, `role`, `plans[{planId}]` | ✅ |
| Response parse `created_ids` | `createData['created_ids']` | `data.created_ids` | ✅ |

---

## 4. QC (sm_job_QC :8088)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `GET /sm/qc/monitoring` | query: `userId`, `divisionId` | ✅ | ✅ |
| `POST /sm/qc` (create) | `action: "create"`, `userId`, `coreId`, `resultStatus`, `estimatedReworkHours`, `kdRemainingHours`, `notes` | Sama | ✅ |
| `PUT /sm/qc` (validate) | `action: "validate"`, `userId`, `qcId`, `finalRemainingHours` dari input user, `advisorNotes` | Sama | ✅ |
| GET monitoring response | Parse `data.units[].jobdescs[]` untuk KD, `data.divisions[].units[].jobdescs[]` untuk role lain | ✅ | ✅ |

---

## 5. Work Order (sm_wo :8093)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `GET /sm/wo` | query: `reqType: ALL`, `status: ALL`, `view: INCOMING`, `page`, `limit` | ✅ | ✅ |
| `POST /sm/wo` (create) | `action: "create"`, `userId`, `reqType: WO_INTERNAL`, `carId`, `targetId`, `jobOrderItemDetail`, `estimatedCostOrHours`, `targetDate` | Sama | ✅ |
| `POST /sm/wo` (approve) | `action: "approve"`, `userId`, `reqId`, `notes` | Sama | ✅ |
| `POST /sm/wo/extensions` (request-dl) | [action](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/warehouse_request/data/repositories/warehouse_repository_impl.dart#19-62), `userId`, `reqId`, `requestedValue`, `reason` | Sama | ✅ |
| `POST /sm/wo/extensions` (reject-dl/hours) | ✅ | ✅ | ✅ |
| GET response parse | Maps `reqId`, `reqNumber`, `coreId`, `targetName`, [detail](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/countdown/presentation/widgets/revision_approval_tab.dart#206-224), [status](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/presentation/widgets/wo_card.dart#624-643) | ✅ | ✅ |
| Division resolve [_resolveDivisionId](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/data/datasources/remote_work_order_datasource.dart#348-355) | Resolve via backend countdown divisions (`user_id` + `car_id`), fallback current session division | Seharusnya dari session/API | ✅ |

---

## 6. PR / WOV (sm_pr :8096)

| Endpoint | Mobile (PR) | Kontrak | Status |
|---|---|---|---|
| `GET /sm/pr` | query: [status](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/presentation/widgets/wo_card.dart#624-643), `role` | Tidak ada parameter `role` di kontrak | ⚠️ `role` mungkin tidak dikenali |
| `PUT /sm/pr/{req_id}/finalize` (approve) | `action: "approve"`, `userId` | `PUT /sm/pr/{req_id}/finalize` | ✅ |
| `GET /sm/pr` response | Parse `data['items']` | Kontrak tidak mendokumentasikan GET-list response shape | ⚠️ Perlu verifikasi di BE |
| WOV `GET /sm/pr` | query: [status](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/presentation/widgets/wo_card.dart#624-643), `role` | ⚠️ | ⚠️ |
| WOV `POST` (update_status) | `action: "update_status"`, `purchases: [{reqId, status}]` | Tidak ada di kontrak | ⚠️ Perlu konfirmasi BE |

---

## 7. Countdown (sm_countdown :8090)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| Level 1 `GET ?user_id` | Memetakan `car_id`, `unit_name`, `overall_progress` | Kontrak level 1 = list unit, tapi response contoh menunjukkan **list divisi** bukan unit | ⚠️ Perlu verifikasi response shape level 1 |
| Level 2 `GET ?user_id&car_id` | ✅ list divisi | `division_id`, `division_name`, `division_progress` | ✅ |
| Level 3 `GET ?...&division_id` | list section/panel | ✅ | ✅ |
| Level 4 `GET ?...&panel_id` | list jobdesc | `countdown_id`, `task_category`, [status](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/presentation/widgets/wo_card.dart#624-643), `progress`, `target_hours_revised`, `remaining_hours`, `deadline_date`, `job_name` | ✅ |
| Level 5 `GET ?countdown_id` | `detail_id`, `employee_name`, `work_date`, `start_time`, `finish_time`, `billed_hours`, `progress_percent`, `task_status` | ✅ | ✅ |
| `POST` (mark_qc_ready) | `action: "mark_qc_ready"`, `user_id`, `countdown_id` | Sama | ✅ |
| `POST` (request_revision) | Hit BE via repository → datasource remote (`action: "request_revision"`, `user_id`, `countdown_id`, `requested_hours`, `revised_deadline`, `reason`) | `POST /sm/countdown`, `action: "request_revision"` | ✅ |
| `GET ?approvals=true` (revision list) | `user_id`, `approvals: true` | ✅ | ✅ |
| `POST` (submit_approval) | `action: "submit_approval"`, `user_id`, `request_id`, `is_approved`, `approved_hours`, `approved_deadline` | `action: "submit_approval"` di kontrak (tersirat) | ✅ |

---

## 8. Warehouse (sm_warehouse :8091)

| Endpoint | Mobile | Kontrak | Status |
|---|---|---|---|
| `GET /sm/warehouse/logs` | query: `userId`, `approvalStatus`, `limit: 200`, `offset: 0` | query: `userId`, `approvalStatus`, `limit`, `offset` | ✅ |
| `POST /sm/warehouse` (create) | `action: "create"`, `userId`, `employeeId`, `transactionType`, `itemCategory`, `itemName`, `qty`, `uom`, `divisionId`, `carId`, `coreId`, ... | `action: "create"`, `userId`, `employeeId`, `transactionType`, `itemCategory`, `itemName`, `qty`, `uom`, `divisionId`, `carId`, `coreId`, `notes` | ✅ |
| `PUT /sm/warehouse` (approve) | `action: "approve"/"reject"`, `userId`, `logId`, `notes` | `action: "approve"`, `userId`, `logId`, `notes` | ✅ |
| `PUT /sm/warehouse` (return) | `action: "return"`, `userId`, `logId` | Tidak di kontrak resmi | ⚠️ Perlu konfirmasi |
| `PUT /sm/warehouse` (install) | `action: "install"`, `userId`, `logId` | Tidak di kontrak resmi | ⚠️ Perlu konfirmasi |
| GET logs response | Parse `data['logs']` array | `data.logs` array | ✅ |

---

## Ringkasan: Perlu Fix

| # | Prioritas | File | Masalah |
|---|---|---|---|
| 1 | ✅ Selesai | [api_task_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/task_execution/data/datasources/api_task_datasource.dart) | GET tasks sekarang mengirim `userId` |
| 2 | ✅ Selesai | [countdown_dialogs.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/countdown/presentation/widgets/countdown_dialogs.dart) | `request_revision` sudah hit BE via repository/datasource remote |
| 3 | ✅ Selesai | [remote_pr_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/pr/data/datasources/remote_pr_datasource.dart) | Approve PR sudah pakai PUT `/pr/{id}/finalize` |
| 4 | ✅ Selesai | [api_task_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/task_execution/data/datasources/api_task_datasource.dart) | Start task sudah kirim `photoBefore1/2` di payload JSON |
| 5 | ✅ Selesai | [api_task_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/task_execution/data/datasources/api_task_datasource.dart) | Submit sudah kirim `action: submit` + `startTime` |
| 6 | ✅ Selesai | [remote_qc_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/qc/data/datasources/remote_qc_datasource.dart) | `finalRemainingHours` sekarang dari input user |
| 7 | ✅ Selesai | [remote_work_order_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/work_order/data/datasources/remote_work_order_datasource.dart) | `_resolveDivisionId` sekarang resolve dari API backend + fallback session, tanpa `DummyDivisions` |
| 8 | ✅ Selesai | [remote_warehouse_datasource.dart](file:///home/sahrulr/StudioProjects/sm_workshop/lib/features/warehouse_request/data/datasources/remote_warehouse_datasource.dart) | GET logs sudah kirim `approvalStatus` |
