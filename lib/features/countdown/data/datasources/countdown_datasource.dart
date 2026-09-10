/*
Tujuan: Kontrak datasource Countdown untuk flow Divisi dan Tracking Master Panel.
Caller: CountdownRepositoryImpl.
Dependensi: Tidak ada; implementasi remote/local menyediakan data.
Main Functions: CountdownDataSource.
Side Effects: Tidak ada langsung.
*/

abstract class CountdownDataSource {
  Future<List<Map<String, dynamic>>> getUnits();

  Future<List<Map<String, dynamic>>> getDivisions(String carId);

  Future<Map<String, dynamic>> getMasterPanelTracking(String unitId);

  Future<Map<String, dynamic>> getMasterPanelDetail({
    required String unitId,
    required int panelId,
  });

  Future<List<Map<String, dynamic>>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  });

  Future<List<Map<String, dynamic>>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  });

  Future<List<Map<String, dynamic>>> getDetails(String countdownId);

  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  });

  Future<List<Map<String, dynamic>>> getRevisionRequests({String? carId});

  Future<void> processRevisionRequest({
    required String requestId,
    required bool approved,
    required double approvedHours,
    required String approvedDeadline,
  });

  Future<void> markAsQcReady(String countdownId);

  Future<void> moApproveRevision({
    required String requestId,
    required bool approved,
    String? note,
  });

  Future<void> submitRevisionToApproval(String requestId);
}
