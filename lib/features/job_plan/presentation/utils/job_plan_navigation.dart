/*
Tujuan: Normalisasi deep link Job Plan menuju modul utama.
Caller: App router dan test navigasi.
Dependensi: Uri.
Main Functions: JobPlanNavigation.redirect.
Side Effects: Tidak ada.
*/
abstract class JobPlanNavigation {
  static String? redirect(Uri uri) {
    const oldRoot = '/job-plans/v2';
    if (uri.path != oldRoot && !uri.path.startsWith('$oldRoot/')) return null;
    if (uri.path == '$oldRoot/create') {
      return uri
          .replace(path: '/plans', queryParameters: uri.queryParameters)
          .toString();
    }
    return uri
        .replace(
          path: uri.path.replaceFirst(oldRoot, '/plans'),
          queryParameters: {
            ...uri.queryParameters,
            if (uri.path == oldRoot) 'tab': 'status',
          },
        )
        .toString();
  }
}
