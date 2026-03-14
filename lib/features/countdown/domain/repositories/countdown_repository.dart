library;

import '../entities/countdown_entities.dart';

abstract class CountdownRepository {
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  });

  Future<List<CountdownJobdesc>> getCountdowns(String carId);

  Future<List<CountdownDetailItem>> getDetails(String countdownId);
}