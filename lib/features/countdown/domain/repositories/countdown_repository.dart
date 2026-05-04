library;

import '../entities/countdown_entities.dart';

abstract class CountdownRepository {
  /// Level 1: list unit berdasarkan user_id.
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  });

  /// Level 2: list divisi untuk sebuah unit (car_id).
  Future<List<CountdownDivision>> getDivisions(String carId);

  /// Level 3: list section/panel untuk divisi tertentu (car_id + division_id).
  Future<List<CountdownSection>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
  });

  /// Level 4: list jobdesc per panel (car_id + division_id + panel_id).
  /// Mendukung filter search dan status.
  Future<List<CountdownJobdesc>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
  });


  /// Level 5: detail aktual per countdown_id.
  Future<List<CountdownDetailItem>> getDetails(String countdownId);

  Future<List<CountdownJobdesc>> getRevisionRequests({String? carId});

  Future<void> requestRevision({
    required String countdownId,
    required double requestedHours,
    required String requestedDeadline,
    required String reason,
  });

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
    String? notes,
  });
}
