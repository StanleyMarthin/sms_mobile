import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../session/session_manager.dart';
import '../services/upload_service.dart';

// ── Auth ──
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/datasources/remote_auth_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/device_init_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// ── Task Execution ──
import '../../features/task_execution/data/datasources/api_task_datasource.dart';
import '../../features/task_execution/data/datasources/api_view_task_datasource.dart';
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
import '../../features/qc/data/datasources/remote_qc_datasource.dart';
import '../../features/qc/data/repositories/qc_repository_impl.dart';
import '../../features/qc/domain/repositories/qc_repository.dart';

// ── Warehouse ──
import '../../features/warehouse_request/data/datasources/warehouse_request_datasource.dart';
import '../../features/warehouse_request/data/datasources/remote_warehouse_datasource.dart';
import '../../features/warehouse_request/data/repositories/warehouse_repository_impl.dart';
import '../../features/warehouse_request/domain/repositories/warehouse_repository.dart';

// ── Countdown ──
import '../../features/countdown/data/datasources/remote_countdown_datasource.dart';
import '../../features/countdown/data/repositories/countdown_repository_impl.dart';
import '../../features/countdown/domain/repositories/countdown_repository.dart';

// ── Monitoring ──
import '../../features/monitoring/data/datasources/remote_monitoring_datasource.dart';
import '../../features/monitoring/data/repositories/monitoring_repository_impl.dart';
import '../../features/monitoring/domain/repositories/monitoring_repository.dart';

// ── Notifications ──
import '../../features/notifications/data/datasources/remote_notifications_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../services/notification_inbox_service.dart';

// ── Profile ──
import '../../features/profile/data/datasources/remote_profile_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

// ── Job Plan ──
import '../../features/job_plan/data/datasources/job_plan_datasource.dart';
import '../../features/job_plan/data/datasources/remote_job_plan_datasource.dart';
import '../../features/job_plan/data/repositories/job_plan_repository_impl.dart';
import '../../features/job_plan/domain/repositories/job_plan_repository.dart';

// ── Work Order ──
import '../../features/work_order/data/datasources/work_order_datasource.dart';
import '../../features/work_order/domain/repositories/work_order_repository.dart';
import '../../features/work_order/data/repositories/work_order_repository_impl.dart';
import '../../features/work_order/presentation/bloc/work_order_bloc.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Initializes all dependencies in the service locator.
///
/// Registration order:
/// 1. Core services (SessionManager, ApiClient)
/// 2. Auth
/// 3. Data sources (all remote — wired to real backend)
/// 4. Repositories
/// 5. Use cases
/// 6. BLoCs
void initDependencies() {
  // ─── Core ────────────────────────────────────────────────
  sl.registerLazySingleton<SessionManager>(() => SessionManager());

  /// Shared HTTP client — used by all remote datasources.
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(sessionManager: sl<SessionManager>()),
  );

  /// Service for Cloudflare R2 binary photo uploads
  sl.registerLazySingleton<UploadService>(
    () => UploadService(apiClient: sl<ApiClient>()),
  );

  // ─── Auth (remote / BE) ─────────────────────────────────
  sl.registerLazySingleton<AuthDataSource>(
    () => RemoteAuthDataSource(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: sl<AuthDataSource>()),
  );
  sl.registerLazySingleton<DeviceInitUseCase>(
    () => DeviceInitUseCase(repository: sl<AuthRepository>()),
  );
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(repository: sl<AuthRepository>()),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      deviceInitUseCase: sl<DeviceInitUseCase>(),
      loginUseCase: sl<LoginUseCase>(),
    ),
  );

  // ─── Task Draft Storage ──────────────────────────────────
  sl.registerLazySingleton<TaskDraftStorage>(
    () => TaskDraftStorage(),
  );

  // ─── Task Execution Data Sources (remote / BE) ───────────
  sl.registerLazySingleton<RemoteTaskDataSource>(
    () => ApiTaskDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<ViewTaskDataSource>(
    () => ApiViewTaskDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // ─── Task Repositories ───────────────────────────────────
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(remoteDataSource: sl<RemoteTaskDataSource>()),
  );
  sl.registerLazySingleton<ViewTaskRepository>(
    () => ViewTaskRepositoryImpl(dataSource: sl<ViewTaskDataSource>()),
  );

  // ─── Job Plan (remote / BE) ──────────────────────────────
  sl.registerLazySingleton<JobPlanDataSource>(
    () => RemoteJobPlanDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<JobPlanRepository>(
    () => JobPlanRepositoryImpl(dataSource: sl<JobPlanDataSource>()),
  );

  // ─── Work Order (remote / BE) ────────────────────────────
  sl.registerLazySingleton<WorkOrderRemoteDataSource>(
    () => WorkOrderRemoteDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
      jobPlanRepository: sl<JobPlanRepository>(),
    ),
  );
  sl.registerLazySingleton<WorkOrderRepository>(
    () => WorkOrderRepositoryImpl(
      dataSource: sl<WorkOrderRemoteDataSource>(),
      sessionManager: sl<SessionManager>(),
    ),
  );

  // ─── QC (remote / BE) ───────────────────────────────────────────────────────
  sl.registerLazySingleton<RemoteQcDataSource>(
    () => RemoteQcDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<QcDataSource>(
    () => sl<RemoteQcDataSource>(),
  );
  sl.registerLazySingleton<QcRepository>(
    () => QcRepositoryImpl(dataSource: sl<QcDataSource>()),
  );

  // ─── Warehouse (remote / BE) ─────────────────────────────
  sl.registerLazySingleton<WarehouseDataSource>(
    () => RemoteWarehouseDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<WarehouseRepository>(
    () => WarehouseRepositoryImpl(dataSource: sl<WarehouseDataSource>()),
  );

  // ─── Countdown (remote / BE) ─────────────────────────────
  sl.registerLazySingleton<CountdownDataSource>(
    () => RemoteCountdownDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<CountdownRepository>(
    () => CountdownRepositoryImpl(
      dataSource: sl<CountdownDataSource>(),
    ),
  );

  // ─── Monitoring (remote / BE) ────────────────────────────
  sl.registerLazySingleton<MonitoringDataSource>(
    () => RemoteMonitoringDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<MonitoringRepository>(
    () => MonitoringRepositoryImpl(dataSource: sl<MonitoringDataSource>()),
  );

  // ─── Notifications (remote / BE) ─────────────────────────
  sl.registerLazySingleton<NotificationInboxService>(
    NotificationInboxService.new,
  );
  sl.registerLazySingleton<NotificationsDataSource>(
    () => RemoteNotificationsDataSource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    ),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () =>
        NotificationsRepositoryImpl(dataSource: sl<NotificationsDataSource>()),
  );

  // ─── Profile (remote / BE) ───────────────────────────────
  sl.registerLazySingleton<ProfileDataSource>(
    () => RemoteProfileDataSource(
      apiClient: sl<ApiClient>(),
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
      uploadService: sl<UploadService>(),
    ),
  );

  sl.registerFactory<WorkOrderBloc>(
    () => WorkOrderBloc(repository: sl<WorkOrderRepository>()),
  );

  sl.registerFactory<TaskViewBloc>(
    () => TaskViewBloc(repository: sl<ViewTaskRepository>()),
  );
}
