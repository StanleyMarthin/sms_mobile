/*
Tujuan: Kontrak datasource remote untuk fetch dan aksi task execution termasuk scope self-only.
Caller: TaskRepositoryImpl dan implementasi datasource task execution.
Dependensi: TaskModel, TaskExecutionLog.
Main Functions: getTodaysTasks, startJobExecution, submitTaskExecution.
Side Effects: Implementasi turunannya melakukan HTTP call ke service task.
*/
// RemoteTaskDataSource — abstract interface and exception classes
// for task data operations.
library;

import '../models/task_model.dart';
import '../../domain/entities/task_execution_log.dart';

/// Exception thrown when API returns an unexpected response format.
class DataFormatException implements Exception {
  /// Human-readable error message.
  final String? message;

  DataFormatException({this.message = 'Data Format Exception'});

  @override
  String toString() => 'DataFormatException: $message';
}

/// Exception thrown when API response indicates a server error.
class ServerException implements Exception {
  /// HTTP status code from the API response.
  final int? statusCode;

  /// Human-readable error message.
  final String? message;

  ServerException({this.statusCode, this.message = 'Server Exception'});

  @override
  String toString() => 'ServerException(statusCode: $statusCode): $message';
}

/// Exception thrown when API response indicates a client error.
class ClientException implements Exception {
  /// HTTP status code from the API response.
  final int? statusCode;

  /// Human-readable error message.
  final String? message;

  ClientException({this.statusCode, this.message = 'Client Exception'});

  @override
  String toString() => 'ClientException(statusCode: $statusCode): $message';
}

/// Abstract interface for remote task data operations.
///
/// Using an abstract class allows for:
/// - Easy mocking in tests
/// - Swapping implementations (e.g., different API versions)
/// - Clear contract definition
abstract class RemoteTaskDataSource {
  /// Fetches today's task assignments for the current mechanic.
  ///
  /// This method handles:
  /// - Building the request URL
  /// - Making the HTTP GET request using Dio
  /// - Parsing the JSON response array into TaskModel list
  /// - Throwing appropriate exceptions on network/HTTP errors
  ///
  /// This is called on app startup to populate the mechanic's dashboard.
  ///
  /// Returns:
  ///   - `List<TaskModel>` of today's assignments
  ///
  /// Throws:
  ///   - ServerException: If API returns 5xx status code
  ///   - ClientException: If API returns 4xx status code
  ///   - DioException: If network error occurs
  ///
  /// Expected API endpoint: GET /api/mechanic/tasks/today
  /// Example response:
  /// ```json
  /// [
  ///   {
  ///     "plandailyId": "550e8400-e29b-41d4-a716-446655440001",
  ///     "coreId": "650e8400-e29b-41d4-a716-446655440002",
  ///     "carId": "750e8400-e29b-41d4-a716-446655440003",
  ///     "unitName": "Nissan Datsun 1975 - Merah",
  ///     "panelName": "Ruang Mesin",
  ///     "jobName": "Turunkan Mesin & Gearbox",
  ///     "divisionName": "MECHANIC",
  ///     "status": "PROSES",
  ///     "isPanelLocked": false,
  ///     "dailyTargetHours": 8.0,
  ///     "targetHoursRevised": 16.0,
  ///     "remainingHours": 10.5,
  ///     "taskDate": "2026-02-20",
  ///     "createdAt": "2026-02-20T06:30:00Z",
  ///     "startedAt": null,
  ///     "completedAt": null
  ///   }
  /// ]
  /// ```
  Future<List<TaskModel>> getTodaysTasks({
    required DateTime date,
    required bool isOvertime,
    bool forceOwnOnly = false,
  });

  /// Fetches a single task by its plandailyId with current panel lock status.
  ///
  /// This method handles:
  /// - Building the request URL
  /// - Making the HTTP GET request using Dio
  /// - Parsing the JSON response into TaskModel
  /// - Throwing appropriate exceptions on errors
  ///
  /// CRITICAL: This must fetch the LATEST panel lock status from
  /// trx_car_panel_status.is_locked before showing the task detail.
  ///
  /// Parameters:
  ///   plandailyId: The daily assignment ID to retrieve
  ///
  /// Returns:
  ///   - TaskModel with current lock status
  ///
  /// Throws:
  ///   - ServerException: If API returns 5xx status code
  ///   - ClientException: If API returns 4xx status code (e.g., 404 not found)
  ///   - DioException: If network error occurs (caught and mapped by repository)
  ///
  /// Expected API endpoint: GET /api/mechanic/tasks/{plandailyId}
  Future<TaskModel> getTaskById(String plandailyId);

  /// Starts job execution by locking panel and initializing execution log.
  ///
  /// IMPLEMENTS THE CORE BUSINESS LOGIC FOR RULE #2:
  /// - Backend validates panel lock status
  /// - Backend ATOMICALLY locks the panel
  /// - Backend creates execution log (trx_jobdesc_actual with start_time)
  /// - Returns updated task with isPanelLocked=true, startedAt=now
  ///
  /// This method handles:
  /// - Building the request URL and payload
  /// - Making the HTTP POST request using Dio
  /// - Parsing the JSON response into TaskModel
  /// - Throwing appropriate exceptions on errors
  ///
  /// Parameters:
  ///   plandailyId: The daily task ID to start
  ///
  /// Returns:
  ///   - TaskModel: Updated with status PROSES, isPanelLocked=true, startedAt=now
  ///
  /// Throws:
  ///   - ServerException: If API returns 5xx status
  ///   - ClientException: If API returns 4xx, specifically:
  ///     - 404: Task not found
  ///     - 409: Panel locked (should be 423 per HTTP spec, but check backend)
  ///     - 422: Job not in PROSES status
  ///   - DioException: If network error occurs
  ///
  /// Expected API endpoint: POST /api/mechanic/tasks/{plandailyId}/start
  /// Request body:
  /// ```json
  /// {
  ///   "plandailyId": "550e8400-e29b-41d4-a716-446655440001",
  ///   "startTime": "2026-02-20T08:15:00Z"
  /// }
  /// ```
  /// Response (200 OK):
  /// ```json
  /// {
  ///   "plandailyId": "550e8400-e29b-41d4-a716-446655440001",
  ///   "status": "PROSES",
  ///   "isPanelLocked": true,
  ///   "startedAt": "2026-02-20T08:15:00Z",
  ///   ... other fields
  /// }
  /// ```
  /// Response (409/423 Panel Locked):
  /// ```json
  /// {
  ///   "error": "Panel locked",
  ///   "code": "PANEL_LOCKED",
  ///   "message": "Panel sudah dikerjakan oleh Rini Setiawan",
  ///   "lockedBy": {
  ///     "employeeId": "ADAM",
  ///     "fullName": "Rini Setiawan",
  ///     "divisionName": "MECHANIC"
  ///   },
  ///   "lockedSince": "2026-02-20T08:00:00Z"
  /// }
  /// ```
  Future<TaskModel> startJobExecution(
    String plandailyId, {
    String? photoBefore1Path,
    String? photoBefore2Path,
  });

  /// Finishes job execution and unlocks the panel.
  ///
  /// Backend responsibilities:
  /// - Find latest execution log without finish_time
  /// - Set finish_time = now
  /// - Calculate duration = finish - start - breakDuration
  /// - Update trx_jobdesc_core.total_actual_hours
  /// - Update trx_jobdesc_core.remaining_hours
  /// - ATOMICALLY unlock the panel
  /// - Update job status based on remaining hours
  ///
  /// Parameters:
  ///   plandailyId: The daily task ID to finish
  ///
  /// Returns:
  ///   - TaskModel: Updated with isPanelLocked=false, completedAt=now
  ///
  /// Throws:
  ///   - ServerException: If API returns 5xx status
  ///   - ClientException: If API returns 4xx
  ///   - DioException: If network error occurs
  ///
  /// Expected API endpoint: POST /api/mechanic/tasks/{plandailyId}/finish
  Future<TaskModel> finishJobExecution(
    String plandailyId, {
    int breakDurationMinutes = 60,
  });

  /// Submits a full task execution log with times, progress, and photos.
  ///
  /// This is the enhanced execution method that handles:
  /// - Starting a new job (isStarting = true)
  /// - Updating execution progress
  /// - Finishing a job (isFinishing = true, progress = 100%)
  ///
  /// Expected API endpoint: POST /api/mechanic/tasks/{plandailyId}/execute
  Future<TaskModel> submitTaskExecution(TaskExecutionLog executionLog);

  /// Records break duration while task is running.
  ///
  /// Backend endpoint: PUT /sm/tasks with action=break.
  Future<TaskModel> recordBreak(
    String plandailyId, {
    required int breakDurationMinutes,
  });

  /// Saves progress photo metadata during execution.
  ///
  /// Backend endpoint: POST /sm/tasks with action=progress.
  Future<TaskModel> uploadProgressPhoto(
    String plandailyId, {
    required String photoUrl,
    String photoType = 'PROCESS',
  });

  /// Gets pre-signed upload URL for direct object storage upload.
  ///
  /// Backend endpoint: GET /sm/tasks/upload-ticket?filename=...
  Future<String> getUploadTicket({required String filename});
}
