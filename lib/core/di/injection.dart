import 'package:get_it/get_it.dart';

import '../data/local_mock_api_store.dart';
import '../session/session_manager.dart';

// ── Auth ──
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/datasources/local_auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/device_init_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// ── Task Execution (stays in task_execution feature) ──
import '../../features/task_execution/data/datasources/local_task_datasource.dart';
import '../../features/task_execution/data/datasources/local_view_task_datasource.dart';
import '../../features/task_execution/data/datasources/remote_task_datasource.dart';
import '../../features/task_execution/data/datasources/task_draft_storage.dart';
import '../../features/task_execution/data/datasources/view_task_datasource.dart';
import '../../features/task_execution/data/repositories/task_repository_impl.dart';
import '../../features/task_execution/data/repositories/view_task_repository_impl.dart';
import '../../features/task_execution/domain/repositories/task_repository.dart';
import '../../features/task_execution/domain/repositories/view_task_repository.dart';
import '../../features/task_execution/domain/usecases/start_job_usecase.dart';
import '../../features/task_execution/presentation/bloc/task_bloc.dart';
import '../../features/task_execution/presentation/bloc/task_view/task_view_bloc.dart';

// ── QC ──
import '../../features/qc/data/datasources/local_qc_datasource.dart';
import '../../features/qc/data/repositories/qc_repository_impl.dart';
import '../../features/qc/domain/repositories/qc_repository.dart';

// ── Warehouse ──
import '../../features/warehouse_request/data/datasources/local_warehouse_datasource.dart';
import '../../features/warehouse_request/data/repositories/warehouse_repository_impl.dart';
import '../../features/warehouse_request/domain/repositories/warehouse_repository.dart';

// ── Countdown ──
import '../../features/countdown/data/datasources/local_countdown_datasource.dart';
import '../../features/countdown/data/repositories/countdown_repository_impl.dart';
import '../../features/countdown/domain/repositories/countdown_repository.dart';

// ── Monitoring ──
import '../../features/monitoring/data/datasources/local_monitoring_datasource.dart';
import '../../features/monitoring/data/repositories/monitoring_repository_impl.dart';
import '../../features/monitoring/domain/repositories/monitoring_repository.dart';

// ── Notifications ──
import '../../features/notifications/data/datasources/local_notifications_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';

// ── Profile ──
import '../../features/profile/data/datasources/local_profile_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

// ── Job Plan ──
import '../../features/job_plan/data/datasources/job_plan_datasource.dart';
import '../../features/job_plan/data/datasources/local_job_plan_datasource.dart';
import '../../features/job_plan/data/repositories/job_plan_repository_impl.dart';
import '../../features/job_plan/domain/repositories/job_plan_repository.dart';

// ── Work Order ──
import '../../features/work_order/data/datasources/local_work_order_datasource.dart';
import '../../features/work_order/data/datasources/work_order_datasource.dart';
import '../../features/work_order/domain/repositories/work_order_repository.dart';
import '../../features/work_order/data/repositories/work_order_repository_impl.dart';
import '../../features/work_order/presentation/bloc/work_order_bloc.dart';



/// Global service locator instance.
final sl = GetIt.instance;

/// Initializes all dependencies in the service locator.
///
/// Registration order:
/// 1. Core services (SessionManager)
/// 2. Data sources
/// 3. Repositories (per feature module)
/// 4. Use cases
/// 5. BLoCs (factory — new instance per screen)
void initDependencies() {
  // ─── Core ────────────────────────────────────────────────
  sl.registerLazySingleton<SessionManager>(() => SessionManager());
  sl.registerLazySingleton<LocalMockApiStore>(() => LocalMockApiStore());

  // ─── Auth Data Sources (local/dummy) ─────────────────────
  sl.registerLazySingleton<AuthDataSource>(
    () => const LocalAuthDataSource(),
  );

  // ─── Auth Repositories ───────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: sl<AuthDataSource>()),
  );

  // ─── Auth Use Cases ──────────────────────────────────────
  sl.registerLazySingleton<DeviceInitUseCase>(
    () => DeviceInitUseCase(repository: sl<AuthRepository>()),
  );
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(repository: sl<AuthRepository>()),
  );

  // ─── Auth BLoC ───────────────────────────────────────────
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      deviceInitUseCase: sl<DeviceInitUseCase>(),
      loginUseCase: sl<LoginUseCase>(),
    ),
  );

  // ─── Task Data Sources (local/dummy) ──────────────────────
  sl.registerLazySingleton<RemoteTaskDataSource>(
    () => LocalTaskDataSource(
      store: sl<LocalMockApiStore>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<TaskDraftStorage>(
    () => TaskDraftStorage(),
  );
  sl.registerLazySingleton<ViewTaskDataSource>(
    () => LocalViewTaskDataSource(store: sl<LocalMockApiStore>()),
  );

  // ─── Repositories ───────────────────────────────────────
  // Task Execution
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(remoteDataSource: sl<RemoteTaskDataSource>()),
  );

  // View Tasks (unified view for all roles)
  sl.registerLazySingleton<ViewTaskRepository>(
    () => ViewTaskRepositoryImpl(dataSource: sl<ViewTaskDataSource>()),
  );

  // Job Plan
  sl.registerLazySingleton<JobPlanDataSource>(
    () => LocalJobPlanDataSource(store: sl<LocalMockApiStore>()),
  );
  sl.registerLazySingleton<JobPlanRepository>(
    () => JobPlanRepositoryImpl(dataSource: sl<JobPlanDataSource>()),
  );

  // Work Order
  sl.registerLazySingleton<WorkOrderDataSource>(
    () => LocalWorkOrderDataSource(),
  );
  sl.registerLazySingleton<WorkOrderRepository>(
    () => WorkOrderRepositoryImpl(
      dataSource: sl<WorkOrderDataSource>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // QC
  sl.registerLazySingleton<QcDataSource>(
    () => LocalQcDataSource(store: sl<LocalMockApiStore>()),
  );
  sl.registerLazySingleton<QcRepository>(
    () => QcRepositoryImpl(dataSource: sl<QcDataSource>()),
  );

  // Warehouse
  sl.registerLazySingleton<WarehouseDataSource>(
    () => LocalWarehouseDataSource(),
  );
  sl.registerLazySingleton<WarehouseRepository>(
    () => WarehouseRepositoryImpl(dataSource: sl<WarehouseDataSource>()),
  );

  // Countdown
  sl.registerLazySingleton<CountdownDataSource>(
    () => LocalCountdownDataSource(store: sl<LocalMockApiStore>()),
  );
  sl.registerLazySingleton<CountdownRepository>(
    () => CountdownRepositoryImpl(
      dataSource: sl<CountdownDataSource>(),
      qcDataSource: sl<QcDataSource>(),
    ),
  );

  // Monitoring
  sl.registerLazySingleton<MonitoringDataSource>(
    () => LocalMonitoringDataSource(),
  );
  sl.registerLazySingleton<MonitoringRepository>(
    () => MonitoringRepositoryImpl(dataSource: sl<MonitoringDataSource>()),
  );

  // Notifications
  sl.registerLazySingleton<NotificationsDataSource>(
    () => LocalNotificationsDataSource(),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(dataSource: sl<NotificationsDataSource>()),
  );

  // Profile
  sl.registerLazySingleton<ProfileDataSource>(
    () => LocalProfileDataSource(
      sessionManager: sl<SessionManager>(),
      taskDraftStorage: sl<TaskDraftStorage>(),
    ),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(dataSource: sl<ProfileDataSource>()),
  );



  // ─── Use Cases ──────────────────────────────────────────
  sl.registerLazySingleton<StartJobUseCase>(
    () => StartJobUseCase(repository: sl<TaskRepository>()),
  );

  // ─── BLoCs ──────────────────────────────────────────────
  sl.registerFactory<TaskBloc>(
    () => TaskBloc(
      taskRepository: sl<TaskRepository>(),
      startJobUseCase: sl<StartJobUseCase>(),
      taskDraftStorage: sl<TaskDraftStorage>(),
    ),
  );

  sl.registerFactory<WorkOrderBloc>(
    () => WorkOrderBloc(repository: sl<WorkOrderRepository>()),
  );

  sl.registerFactory<TaskViewBloc>(
    () => TaskViewBloc(repository: sl<ViewTaskRepository>()),
  );
}
