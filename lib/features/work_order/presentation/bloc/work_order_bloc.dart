import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/work_order_repository.dart';
import 'work_order_event.dart';
import 'work_order_state.dart';

/// Unified BLoC for Work Order management.
///
/// Handles loading (all or own), CRUD, approve, reject, and extend deadline.
class WorkOrderBloc extends Bloc<WorkOrderEvent, WorkOrderState> {
  final WorkOrderRepository repository;

  /// Tracks whether we loaded all WOs or just the user's own.
  bool _isManagementView = false;

  WorkOrderBloc({required this.repository})
      : super(const WorkOrderInitial()) {
    on<LoadAllWorkOrders>(_onLoadAll);
    on<LoadMyWorkOrders>(_onLoadMy);
    on<SubmitWorkOrder>(_onSubmit);
    on<UpdateWorkOrder>(_onUpdate);
    on<DeleteWorkOrder>(_onDelete);
    on<ApproveWo>(_onApprove);
    on<RejectWo>(_onReject);
    on<ExtendWoDeadline>(_onExtend);
    on<RequestWoRevision>(_onRequestRevision);
    on<RespondWoRevision>(_onRespondRevision);
    on<RequestWoExtension>(_onRequestExtension);
    on<RespondWoExtension>(_onRespondExtension);
  }

  Future<void> _onLoadAll(
    LoadAllWorkOrders event,
    Emitter<WorkOrderState> emit,
  ) async {
    _isManagementView = true;
    emit(const WorkOrderLoading());
    final result = await repository.getAllWorkOrders();
    result.fold(
      (failure) =>
          emit(WorkOrderError(message: failure.message ?? 'Gagal memuat WO')),
      (wos) => emit(WorkOrderLoaded(workOrders: wos)),
    );
  }

  Future<void> _onLoadMy(
    LoadMyWorkOrders event,
    Emitter<WorkOrderState> emit,
  ) async {
    _isManagementView = false;
    emit(const WorkOrderLoading());
    final result = await repository.getMyWorkOrders();
    result.fold(
      (failure) =>
          emit(WorkOrderError(message: failure.message ?? 'Gagal memuat WO')),
      (wos) => emit(WorkOrderLoaded(workOrders: wos)),
    );
  }

  Future<void> _refreshAndEmit(
      Emitter<WorkOrderState> emit, String message) async {
    final refresh = _isManagementView
        ? await repository.getAllWorkOrders()
        : await repository.getMyWorkOrders();
    refresh.fold(
      (f) => emit(WorkOrderActionSuccess(workOrders: const [], message: message)),
      (wos) => emit(WorkOrderActionSuccess(workOrders: wos, message: message)),
    );
  }

  Future<void> _onSubmit(
    SubmitWorkOrder event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.submitWorkOrder(event.workOrder);
    await result.fold(
      (failure) async => emit(
          WorkOrderError(message: failure.message ?? 'Gagal mengirim WO')),
      (wo) async =>
          _refreshAndEmit(emit, 'WO berhasil dibuat: ${wo.woNumber}'),
    );
  }

  Future<void> _onUpdate(
    UpdateWorkOrder event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.updateWorkOrder(event.workOrder);
    await result.fold(
      (failure) async => emit(
          WorkOrderError(message: failure.message ?? 'Gagal memperbarui WO')),
      (_) async => _refreshAndEmit(emit, 'WO berhasil diperbarui'),
    );
  }

  Future<void> _onDelete(
    DeleteWorkOrder event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.deleteWorkOrder(event.woId);
    await result.fold(
      (failure) async => emit(
          WorkOrderError(message: failure.message ?? 'Gagal menghapus WO')),
      (_) async => _refreshAndEmit(emit, 'WO berhasil dihapus'),
    );
  }

  Future<void> _onApprove(
    ApproveWo event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result =
        await repository.approveWorkOrder(event.woId, event.approverName);
    await result.fold(
      (failure) async =>
          emit(WorkOrderError(message: failure.message ?? 'Gagal approve WO')),
      (wo) async {
        final msg = wo.isPendingPm
            ? 'Advisor approved — menunggu PM'
            : 'PM approved — WO disetujui ✓';
        await _refreshAndEmit(emit, msg);
      },
    );
  }

  Future<void> _onReject(
    RejectWo event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.rejectWorkOrder(
        event.woId, event.rejectedBy, event.reason);
    await result.fold(
      (failure) async =>
          emit(WorkOrderError(message: failure.message ?? 'Gagal reject WO')),
      (_) async => _refreshAndEmit(emit, 'WO ditolak'),
    );
  }

  Future<void> _onExtend(
    ExtendWoDeadline event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.extendDeadline(
        event.woId, event.newDeadline, event.reason);
    await result.fold(
      (failure) async => emit(WorkOrderError(
          message: failure.message ?? 'Gagal perpanjang deadline')),
      (_) async => _refreshAndEmit(emit, 'Deadline berhasil diperpanjang'),
    );
  }

  Future<void> _onRequestRevision(
    RequestWoRevision event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.requestRevision(
      woId: event.woId,
      requestedEstimatedHours: event.requestedEstimatedHours,
      requestedDeadline: event.requestedDeadline,
      reason: event.reason,
      reviewerName: event.reviewerName,
    );
    await result.fold(
      (failure) async => emit(
        WorkOrderError(message: failure.message ?? 'Gagal kirim revisi WO'),
      ),
      (_) async => _refreshAndEmit(emit, 'Permintaan revisi dikirim ke KD'),
    );
  }

  Future<void> _onRespondRevision(
    RespondWoRevision event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.respondRevision(
      woId: event.woId,
      approve: event.approve,
      reviewerName: event.reviewerName,
      note: event.note,
    );
    await result.fold(
      (failure) async => emit(
        WorkOrderError(message: failure.message ?? 'Gagal proses revisi WO'),
      ),
      (_) async => _refreshAndEmit(
        emit,
        event.approve ? 'Revisi disetujui' : 'Revisi ditolak',
      ),
    );
  }

  Future<void> _onRequestExtension(
    RequestWoExtension event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.requestDeadlineExtension(
      woId: event.woId,
      newDeadline: event.newDeadline,
      reason: event.reason,
      requesterName: event.requesterName,
    );
    await result.fold(
      (failure) async => emit(
        WorkOrderError(message: failure.message ?? 'Gagal ajukan perpanjangan'),
      ),
      (_) async => _refreshAndEmit(emit, 'Pengajuan perpanjangan dikirim'),
    );
  }

  Future<void> _onRespondExtension(
    RespondWoExtension event,
    Emitter<WorkOrderState> emit,
  ) async {
    final result = await repository.respondDeadlineExtension(
      woId: event.woId,
      approve: event.approve,
      reviewerName: event.reviewerName,
      note: event.note,
    );
    await result.fold(
      (failure) async => emit(
        WorkOrderError(
          message: failure.message ?? 'Gagal proses perpanjangan deadline',
        ),
      ),
      (_) async => _refreshAndEmit(
        emit,
        event.approve
            ? 'Perpanjangan deadline disetujui'
            : 'Perpanjangan deadline ditolak',
      ),
    );
  }
}
