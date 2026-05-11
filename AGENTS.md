ATURAN NAVIGASI & KONTEKS

Mandatory Map Check:
Setiap awal sesi baru, WAJIB baca SYSTEM_MAP.md di root folder sebagai kompas utama arsitektur, tech stack, dan lokasi fungsi kunci. Jangan lakukan blind scan.

Fallback Map:
Jika SYSTEM_MAP.md belum ada atau diduga usang, buat/perbarui dulu secara ringkas sebelum analisis lanjutan.

Trace-by-Function / Trace-by-Flow:
Gunakan peta untuk menentukan titik mulai, lalu telusuri alur berurutan:
Trigger/Entry Point -> Handler/Controller -> Business Logic/Service -> Data Access/Repository -> Database/Storage.

Universal Layer Mapping:
Jika istilah Controller/Service/Repo tidak dipakai, map ke padanan terdekat (Handler, Usecase, Domain, Adapter, DAO, dll).

Universal Exclusions:
Selalu abaikan: node_modules, .venv, venv, env, vendor, target, .gradle, bin, obj, pkg, .git, .vscode, .idea, __pycache__, dist, build, tmp, coverage, .next, .nuxt, .cache

Super Efisien:
- Minim command, minim file read.
- File >500 baris: baca per blok fungsi/class terkait, bukan full file kecuali diminta.

Pre-Edit Trace Note:
Sebelum edit, tulis singkat (1-2 kalimat): file target + alur fungsi yang akan disentuh.

Persetujuan Inisiatif:
Jika ada perubahan di luar request user, wajib minta izin sebelum eksekusi.

Mandatory TDD (Test-Driven Development):
Setiap pembuatan fitur baru atau perbaikan logic (Bloc, Usecase, Service), WAJIB terapkan TDD. Tulis/perbarui test file di folder `test/` yang sesuai sebelum melakukan implementasi kode.

Modularitas:
Pecah logika ke modul/file kecil sesuai tanggung jawab (Single Responsibility).

HARD INSTRUCTION DOKUMENTASI (WAJIB):
Setiap file yang dibuat/diubah wajib punya header doc singkat di paling atas:
- Tujuan: tujuan file/module
- Caller: pemanggil/pengguna utama
- Dependensi: service/repo/API utama
- Main Functions: fungsi/class public/utama
- Side Effects: DB read/write, HTTP call, file I/O

Synchronized Map Update:
Jika menambah/menghapus file atau mengubah flow fungsi utama, WAJIB update SYSTEM_MAP.md di sesi yang sama.