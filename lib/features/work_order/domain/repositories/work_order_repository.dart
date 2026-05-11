/*
Tujuan: Kontrak repository Work Order untuk list, detail, create, approval, dan extension.
Caller: WorkOrderBloc.
Dependensi: Either, Failure, WorkOrder entity.
Main Functions: getWorkOrders, getWorkOrderById, createWorkOrder, approveWorkOrder.
Side Effects: Tidak langsung; diimplementasikan oleh data layer.
*/
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_order.dart';

abstract class WorkOrderRepository {
  /// List WO (ACTIVE atau DONE)
  Future<Either<Failure, List<WorkOrder>>> getWorkOrders({
    String view = 'ACTIVE',
    int page = 1,
    int limit = 30,
  });

  /// Detail WO by ID (merge Redis state)
  Future<Either<Failure, WorkOrder>> getWorkOrderById(String woId);

  /// Buat WO baru
  Future<Either<Failure, WorkOrder>> createWorkOrder({
    required String carId,
    required String targetDivId,
    required String jobDetail,
    String? notes,
    required String targetDate,
    String? panelName,
    String? sectionName,
    String? panelCategory,
    bool addPanelToMaster = false,
    double? targetHours,
  });

  /// Approve WO di stage saat ini
  Future<Either<Failure, Map<String, dynamic>>> approveWorkOrder({
    required String woId,
    double? estimatedHours,
    String? notes,
    String? picId,
  });

  /// Reject WO dengan alasan wajib
  Future<Either<Failure, void>> rejectWorkOrder({
    required String woId,
    required String rejectReason,
  });

  // Extension (countdown)
  Future<Either<Failure, void>> requestDeadlineExtension({
    required String woId,
    required String newDeadline,
    required String reason,
  });

  Future<Either<Failure, void>> respondDeadlineExtension({
    required String woId,
    required bool approve,
    String? note,
  });

  Future<Either<Failure, void>> requestHourExtension({
    required String woId,
    required double requestedHours,
    required String reason,
  });

  Future<Either<Failure, void>> respondHourExtension({
    required String woId,
    required bool approve,
  });

  /// Dropdown master data (cars, panels, divisions)
  Future<Either<Failure, Map<String, dynamic>>> getDropdowns({
    String? carId,
    String? divisionId,
  });
}
