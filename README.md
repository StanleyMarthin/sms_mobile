# 🚀 Executive Summary & System Report: SM-MIS Workshop Mobile

Dokumen ini disusun sebagai laporan representasi arsitektur, fitur bisnis, dan capaian dari aplikasi **SM-MIS Workshop Mobile** beserta integrasi sistem *backend*-nya, ditujukan untuk evaluasi dan presentasi kepada jajaran Manajemen.

---

## 📌 1. Latar Belakang & Tujuan Utama
Sistem ini dibangun untuk **mendigitalisasi seluruh operasional bengkel (Workshop)** secara *end-to-end*, menggantikan pencatatan manual yang rentan terhadap inefisiensi dan manipulasi. Tujuan utama sistem ini adalah:
- **Transparansi Jam Kerja:** Melacak durasi pengerjaan secara akurat hingga level menit, membedakan antara waktu reguler, efisiensi kerja, dan jam lembur aktual.
- **Standarisasi Alur (SOP):** Mengunci alur kerja (*Work Order* $\rightarrow$ *Job Plan* $\rightarrow$ *Task Execution* $\rightarrow$ *Quality Control*) agar tidak bisa di-*bypass*.
- **Kendali Finansial (HPP):** Mengubah estimasi jam (*budget*) menjadi parameter pembatas (*pool*) yang diawasi sistem secara *real-time*.

---

## 🏗️ 2. Arsitektur Sistem (High-Level)
Sistem menggunakan pendekatan **Modern Microservices** untuk skalabilitas tinggi:
1. **Frontend (Mobile App):** Dibangun dengan **Flutter**, menjamin performa mulus di Android & iOS dengan antarmuka (UI) yang telah terstandardisasi penuh.
2. **Backend (API Services):** Dibangun dengan **Python (FastAPI)**, dibagi menjadi beberapa *microservices* mandiri (`sm_tasks`, `sm_job_plan`, `sm_warehouse`, dll).
3. **Database & Cache:** Memanfaatkan **MySQL** untuk penyimpanan permanen (RDBMS) dan **Redis** untuk *State Management* super cepat (seperti *Draft Plan*, *Shared Time Pool*, dan *Role Approval State*).

---

## ⚙️ 3. Alur Operasional Bengkel (End-to-End Workflow)
Sistem merajut operasional lapangan menjadi satu alur linier yang saling mengunci (*locked workflow*), meniadakan kemungkinan mekanik bekerja tanpa instruksi tertulis dan persetujuan budget.

## ⚙️ 3. Alur Operasional Bengkel (End-to-End Workflow)
Sistem merajut operasional lapangan menjadi satu alur yang saling mengunci, meniadakan kemungkinan mekanik bekerja tanpa instruksi tertulis dan persetujuan budget.

### A. Pendataan Awal & Penetapan Target (Countdown)
*(Langkah Paling Awal)* Semua aktivitas operasional bermula dari inspeksi dan pendataan awal kendaraan masuk.
- Hasil pendataan ini diklasifikasikan dan diubah menjadi *bundle* target pengerjaan per panel kendaraan yang disebut **Countdown**.
- Halaman *Countdown* bertindak sebagai "Papan Skor" utama proyek. Seluruh alokasi budget jam, persentase *progress*, dan durasi yang telah dipakai berpusat di sini.

### B. Distribusi Target Harian (Job Plan & Multijob)
*(Pembagian Tugas)* Berdasarkan *Countdown* yang aktif, Ketua Divisi (KD) akan memecahnya menjadi target kerja harian (*Job Plan*) untuk mekaniknya (PIC).
- KD berwenang mendistribusikan sisa jam *Countdown* ke dalam target harian yang rasional.
- Mendukung fitur **Multijob**, di mana beberapa tugas di panel yang sama ditumpuk menjadi satu penugasan agar efisiensi waktu mekanik maksimal.

### C. Dinamika Pengerjaan Lapangan (Additional, WO, WOV)
Di tengah jalan, kendala bengkel dikelola melalui tiga jalur tiket yang sangat spesifik dan memiliki struktur *approval* (persetujuan) berjenjang:
1. **Additional (Tambahan Internal):** Jika ditemukan kerusakan ekstra (misal karat tersembunyi) yang masih bisa diselesaikan oleh divisinya sendiri, maka ditambahkan tugas *Additional* ke dalam *Countdown*.
2. **WO (Work Order Lintas Divisi):** Jika penyelesaian panel membutuhkan campur tangan divisi lain di dalam bengkel (contoh: Divisi *Body* meminta Divisi Mekanik untuk menurunkan mesin), maka diajukan *Work Order* internal.
3. **WOV (Work Order Vendor):** Jika pekerjaan ternyata tidak memungkinkan atau di luar kapasitas internal bengkel, maka dibuatkan *WOV* untuk diserahkan ke pihak vendor/bengkel rekanan eksternal.

### D. Persediaan Material & Part Baru (Warehouse & PR)
*(Persiapan Eksekusi)* Sistem mengatur alur logistik bengkel dengan ketat:
- **Peminjaman Gudang:** Mekanik diwajibkan mengajukan permintaan material (seperti dempul, cat) melalui aplikasi (*Warehouse Request*), menjaga stok gudang tetap riil.
- **Purchase Request (PR):** Jika bagian mobil tidak mungkin di-restorasi/diperbaiki dan butuh penggantian *sparepart* baru, mekanik/divisi dapat mengajukan pengadaan barang (*Purchase*) kepada bagian *Purchasing*.

### E. Eksekusi Pekerjaan & Submit (Smart Time Tracking)
*(Lantai Produksi)* Di sinilah mekanik terjun melakukan tugas (*Task Execution*).
- Sistem mencatat waktu mulai dan selesai secara akurat, sekaligus otomatis mendiskon jam istirahat wajib bengkel agar tidak merugikan mekanik.
- Setelah selesai, mekanik melakukan **Submit** (laporan persentase pengerjaan beserta bukti foto). 
- Pada detik *Submit* inilah **Auto-Overtime Engine** bekerja menimbang efisiensi. Waktu yang meleset dari taksiran KD akan memotong sisa target, memicu *Leakage Notification* (teguran), atau secara tegas divonis sebagai *Overtime*.

### F. Quality Control (QC) & Penolakan (Reject)
*(Validasi Akhir)* Pekerjaan mekanik yang berstatus 100% Selesai wajib diuji oleh tim *Quality Control* (`READY_QC`).
- **Pass (Lulus):** Kendaraan dinyatakan layak dan bagian pekerjaan di panel tersebut selesai.
- **Tidak Lolos QC (Reject):** Jika ditolak, pekerjaan dikembalikan ke mekanik dengan instruksi tambahan. Mekanik harus memperbaiki menggunakan sisa budget waktunya. Jika perbaikan tersebut memakan waktu hingga sisa target/budget WO ludes, maka aturan **Overtime/Leakage** di atas akan otomatis menjeratnya.

### G. Kasus Khusus: Rework Murni & Garansi
Sistem membedakan secara tegas antara "Gagal QC" dengan **Rework Murni**. Rework Murni adalah perbaikan yang terjadi *setelah* QC lulus atau setelah mobil keluar (delivery), di mana biayanya mutlak **tidak ditagihkan ke customer**.
- **Rework Kesalahan Internal:** Contoh, mekanik mesin tidak sengaja menggores *body*. Divisi *Body* harus memoles ulang.
- **Rework Garansi:** Komplain pelanggan atas panel yang sama setelah mobil dibawa pulang.
Karena bersifat *Non-Billable* (tanggungan bengkel/mekanik), kasus Rework Murni ini hanya bisa diterbitkan melalui jalur pembuatan **Additional** dengan mengaktifkan *flag* khusus (`isRework = true`).

---

## 🛡️ 4. Fitur Unggulan: Auto-Overtime & Budget Engine
Ini adalah fitur bisnis paling canggih di dalam sistem untuk **mencegah kebocoran budget** dan **klaim lembur fiktif**. Perhitungan *Overtime* dan Performa kini 100% diambil alih oleh mesin *Backend* menggunakan **Multi-Layer Fallback Rule**:

1. **Strict Shift Rule (Time-Based):** 
   Setiap pekerjaan yang diselesaikan lewat dari jam pulang normal (17:00, atau 14:00 hari Sabtu) akan *langsung* dicatat sebagai Overtime.
2. **Shared Panel Pool (Jaring Pengaman 1):**
   Jika mekanik molor dari target harian yang ditetapkan KD, sistem akan mengecek apakah ada "sisa waktu" dari pekerjaan Multijob lain di panel yang sama. Waktu yang berlebih bisa saling disubstitusi.
3. **Unit Budget Fallback (Jaring Pengaman 2):**
   Jika Pool harian habis, sistem belum tentu memvonisnya sebagai lembur. Sistem akan melihat saldo total estimasi WO mobil tersebut (`wo_estimated_hours`). Jika masih ada alokasi, maka jam bocor tersebut ditutupi oleh sisa Unit Budget.
4. **Final Vonis Overtime:**
   Jika *Pool Panel* ludes **DAN** *Unit Budget* habis, barulah kelebihan waktu tersebut secara hukum disahkan sebagai **OVERTIME**.

### 🚨 Sistem Notifikasi Kinerja (Real-Time Push Notification)
Manajemen tidak perlu mengecek aplikasi setiap saat. Sistem secara otomatis menembakkan notifikasi *real-time* ke **KD, Advisor, Kepala Produksi, dan Manager Produksi**:
- 🟢 **Tugas Siap QC:** Pekerjaan tuntas dan siap diinspeksi.
- 🟡 **Tugas Melebihi Target (Leakage Warning):** Mekanik bekerja sangat lambat melebihi target KD, namun *berhasil diselamatkan* oleh Unit Budget (Tidak jadi Overtime tagihan, tapi performa SDM merah).
- 🔴 **Tugas Overtime:** Kelebihan jam kerja yang sudah tidak tertolong oleh budget apapun, sah merugikan perusahaan dan menjadi *Overtime*.

---

## 📈 5. Dampak Bisnis & Kesimpulan (Business Impact)
Penerapan sistem **SM-MIS Workshop Mobile** memberikan dampak masif pada operasional perusahaan:
1. **Akurasi HPP Terjamin:** Manajemen kini tahu pasti persis berapa *man-hours* produktif yang dihabiskan untuk satu kendaraan.
2. **Disiplin Mekanik Meningkat:** Sistem *Time Tracking* yang kejam (tidak bisa dimanipulasi dari sisi UI) dan pemotongan otomatis jam istirahat memaksa mekanik untuk jujur.
3. **Peringatan Dini Kebocoran:** Petinggi langsung di-ping (notifikasi) saat detik itu juga mekanik menyelesaikan tugas secara inefisien (*Leakage*), tanpa perlu menunggu laporan akhir bulan.
4. **Data-Driven Decision:** Perusahaan dapat dengan mudah menilai KPI Ketua Divisi (dalam mengestimasi target) dan mekanik (dalam eksekusi target) berbasis data historis yang rapi.

---
*Laporan ini dihasilkan dari rangkuman rilis pengembangan sistem terbaru (Versi Standardisasi UI & Multi-Job Overtime Engine).*
