import '../../features/countdown/domain/repositories/countdown_repository.dart';
import '../../features/job_plan/domain/repositories/job_plan_repository.dart';
import '../../features/monitoring/domain/repositories/monitoring_repository.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/qc/domain/repositories/qc_repository.dart';
import '../../features/task_execution/domain/entities/task_filter.dart';
import '../../features/task_execution/domain/repositories/view_task_repository.dart';
import '../../features/warehouse_request/domain/repositories/warehouse_repository.dart';
import '../../features/work_order/domain/repositories/work_order_repository.dart';
import '../session/session_manager.dart';

/// Warm-up API calls in background so first feature open feels faster.
class RuntimeWarmupService {
  RuntimeWarmupService({
    required this.sessionManager,
    required this.viewTaskRepository,
    required this.countdownRepository,
    required this.jobPlanRepository,
    required this.qcRepository,
    required this.monitoringRepository,
    required this.notificationsRepository,
    required this.warehouseRepository,
    required this.workOrderRepository,
  });

  final SessionManager sessionManager;
  final ViewTaskRepository viewTaskRepository;
  final CountdownRepository countdownRepository;
  final JobPlanRepository jobPlanRepository;
  final QcRepository qcRepository;
  final MonitoringRepository monitoringRepository;
  final NotificationsRepository notificationsRepository;
  final WarehouseRepository warehouseRepository;
  final WorkOrderRepository workOrderRepository;

  bool _isRunning = false;
  String? _lastUserId;
  DateTime? _lastRunAt;

  Future<void> warmUpInBackground() async {
    if (!sessionManager.isLoggedIn) return;

    final now = DateTime.now();
    final userId = sessionManager.userId;
    if (_isRunning) return;
    if (_lastUserId == userId &&
        _lastRunAt != null &&
        now.difference(_lastRunAt!) < const Duration(minutes: 2)) {
      return;
    }

    _isRunning = true;
    _lastUserId = userId;
    _lastRunAt = now;

    try {
      final role = (sessionManager.role ?? '').toLowerCase();
      final division = sessionManager.divisionName;
      final dateNow = DateTime.now();
      final canSeeAllMonitoring =
          sessionManager.canViewAssignedUnits || sessionManager.canViewAllUnits;

      final rolePriorityWarmups = <Future<void>>[
        _safe(() async {
          await viewTaskRepository.getViewTasks(
            TaskFilter(type: TaskType.daily, date: dateNow, limit: 20),
          );
        }),
      ];

      switch (role) {
        case 'op':
          rolePriorityWarmups.addAll([
            _safe(() async {
              await viewTaskRepository.getViewTasks(
                TaskFilter(type: TaskType.overtime, date: dateNow, limit: 20),
              );
            }),
            _safe(() => warehouseRepository.getLogs()),
          ]);
          break;
        case 'kd':
          rolePriorityWarmups.addAll([
            _safe(() async {
              await viewTaskRepository.getViewTasks(
                TaskFilter(type: TaskType.plan, date: dateNow, limit: 20),
              );
            }),
            _safe(() => jobPlanRepository.getPlans()),
            _safe(
              () =>
                  _warmCountdown(role: sessionManager.role, division: division),
            ),
            _safe(
              () => qcRepository.getQcItems(
                divisionId: sessionManager.divisionId?.toString() ?? '',
              ),
            ),
            _safe(() => workOrderRepository.getWorkOrders()),
          ]);
          break;
        case 'adv':
        case 'pm':
          rolePriorityWarmups.addAll([
            _safe(() async {
              await viewTaskRepository.getViewTasks(
                TaskFilter(type: TaskType.plan, date: dateNow, limit: 20),
              );
            }),
            _safe(
              () => monitoringRepository.getCars(
                canSeeAll: canSeeAllMonitoring,
                division: division,
              ),
            ),
            _safe(
              () => qcRepository.getQcItems(
                divisionId: sessionManager.divisionId?.toString() ?? '',
              ),
            ),
            _safe(() => workOrderRepository.getWorkOrders()),
          ]);
          break;
        default:
          rolePriorityWarmups.add(
            _safe(
              () =>
                  _warmCountdown(role: sessionManager.role, division: division),
            ),
          );
      }

      final secondaryWarmups = <Future<void>>[
        _safe(
          () => notificationsRepository.getNotifications(
            role: sessionManager.role,
          ),
        ),
      ];

      await Future.wait(rolePriorityWarmups, eagerError: false);
      await Future.wait(secondaryWarmups, eagerError: false);
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _warmCountdown({
    required String? role,
    required String? division,
  }) async {
    final units = await countdownRepository.getUnits(
      role: role,
      division: division,
    );
    final countdownFutures = units
        .take(8)
        .map(
          (unit) => _safe(() => countdownRepository.getDivisions(unit.carId)),
        )
        .toList();
    await Future.wait(countdownFutures, eagerError: false);
  }

  Future<void> _safe(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Ignore warm-up errors; feature screens will handle real failures.
    }
  }
}
