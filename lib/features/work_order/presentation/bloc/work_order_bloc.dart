import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/work_order_repository.dart';
import 'work_order_event.dart';
import 'work_order_state.dart';

class WorkOrderBloc extends Bloc<WorkOrderEvent, WorkOrderState> {
  final WorkOrderRepository repository;

  String _currentView = 'ACTIVE';

  WorkOrderBloc({required this.repository}) : super(const WorkOrderInitial()) {
    on<LoadWorkOrders>(_onLoad);
    on<RefreshWorkOrders>(_onRefresh);
    on<LoadWorkOrderDetail>(_onLoadDetail);
    on<CreateWorkOrder>(_onCreate);
    on<ApproveWo>(_onApprove);
    on<RejectWo>(_onReject);
    on<RequestDlExtension>(_onRequestDl);
    on<RespondDlExtension>(_onRespondDl);
    on<RequestHourExtension>(_onRequestHours);
    on<RespondHourExtension>(_onRespondHours);
  }

  Future<void> _onLoad(LoadWorkOrders e, Emitter<WorkOrderState> emit) async {
    _currentView = e.view;
    emit(const WorkOrderLoading());
    final result = await repository.getWorkOrders(view: e.view);
    result.fold(
      (f) => emit(WorkOrderError(message: f.message ?? 'Gagal memuat WO')),
      (wos) => emit(WorkOrderLoaded(workOrders: wos, view: e.view)),
    );
  }

  Future<void> _onRefresh(RefreshWorkOrders e, Emitter<WorkOrderState> emit) async {
    final result = await repository.getWorkOrders(view: _currentView);
    result.fold(
      (f) => emit(WorkOrderError(message: f.message ?? 'Gagal memuat WO')),
      (wos) => emit(WorkOrderLoaded(workOrders: wos, view: _currentView)),
    );
  }

  Future<void> _onLoadDetail(LoadWorkOrderDetail e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderLoading());
    final result = await repository.getWorkOrderById(e.woId);
    result.fold(
      (f) => emit(WorkOrderError(message: f.message ?? 'Gagal memuat detail WO')),
      (wo) => emit(WorkOrderDetailLoaded(wo)),
    );
  }

  Future<void> _refreshAfter(Emitter<WorkOrderState> emit, String msg) async {
    final result = await repository.getWorkOrders(view: _currentView);
    result.fold(
      (f) => emit(WorkOrderActionSuccess(workOrders: const [], message: msg, view: _currentView)),
      (wos) => emit(WorkOrderActionSuccess(workOrders: wos, message: msg, view: _currentView)),
    );
  }

  Future<void> _onCreate(CreateWorkOrder e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.createWorkOrder(
      carId:            e.carId,
      targetDivId:      e.targetDivId,
      jobDetail:        e.jobDetail,
      targetDate:       e.targetDate,
      panelName:        e.panelName,
      sectionName:      e.sectionName,
      panelCategory:    e.panelCategory,
      addPanelToMaster: e.addPanelToMaster,
      targetHours:      e.targetHours,
    );
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal membuat WO')),
      (wo) async => _refreshAfter(emit, 'WO ${wo.woNumber} berhasil dibuat'),
    );
  }

  Future<void> _onApprove(ApproveWo e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.approveWorkOrder(
      woId: e.woId,
      estimatedHours: e.estimatedHours,
      notes: e.notes,
    );
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal approve WO')),
      (data) async {
        final nextStage = data['newStage']?.toString() ?? '';
        final msg = nextStage == 'APPROVED' ? 'WO disetujui final ✓' : 'Diteruskan ke $nextStage';
        await _refreshAfter(emit, msg);
      },
    );
  }

  Future<void> _onReject(RejectWo e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.rejectWorkOrder(woId: e.woId, rejectReason: e.rejectReason);
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal reject WO')),
      (_) async => _refreshAfter(emit, 'WO berhasil ditolak'),
    );
  }

  Future<void> _onRequestDl(RequestDlExtension e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.requestDeadlineExtension(woId: e.woId, newDeadline: e.newDeadline, reason: e.reason);
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal ajukan perpanjangan DL')),
      (_) async => _refreshAfter(emit, 'Pengajuan perpanjangan deadline dikirim'),
    );
  }

  Future<void> _onRespondDl(RespondDlExtension e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.respondDeadlineExtension(woId: e.woId, approve: e.approve, note: e.note);
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal proses perpanjangan DL')),
      (_) async => _refreshAfter(emit, e.approve ? 'Perpanjangan DL disetujui' : 'Perpanjangan DL ditolak'),
    );
  }

  Future<void> _onRequestHours(RequestHourExtension e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.requestHourExtension(woId: e.woId, requestedHours: e.requestedHours, reason: e.reason);
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal ajukan tambahan jam')),
      (_) async => _refreshAfter(emit, 'Pengajuan tambahan jam dikirim'),
    );
  }

  Future<void> _onRespondHours(RespondHourExtension e, Emitter<WorkOrderState> emit) async {
    emit(const WorkOrderActionLoading());
    final result = await repository.respondHourExtension(woId: e.woId, approve: e.approve);
    await result.fold(
      (f) async => emit(WorkOrderError(message: f.message ?? 'Gagal proses tambahan jam')),
      (_) async => _refreshAfter(emit, e.approve ? 'Tambahan jam disetujui' : 'Tambahan jam ditolak'),
    );
  }
}
