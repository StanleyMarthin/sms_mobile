/// Core failure classes following functional programming paradigm.
///
/// All domain and data layer functions that can fail should return
/// `Either<Failure, Success>` using these failure types for consistency
/// across the entire application.
library;

import 'package:equatable/equatable.dart';

/// Base failure class that all specific failures should extend.
/// This allows for pattern matching and centralized error handling.
abstract class Failure extends Equatable {
  final String? message;
  final int? statusCode;
  final String? errorCode;

  const Failure({this.message, this.statusCode, this.errorCode});

  @override
  List<Object?> get props => [message, statusCode, errorCode];
}

// ─── HTTP-level failures ────────────────────────────────────

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred',
    super.statusCode,
    super.errorCode,
  });
}

class ClientFailure extends Failure {
  const ClientFailure({
    super.message = 'Client error occurred',
    super.statusCode,
    super.errorCode,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure({String? message})
    : super(message: message ?? 'Network connection failed');
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({String? message})
    : super(message: message ?? 'Request timeout');
}

class DataParsingFailure extends Failure {
  const DataParsingFailure({String? message})
    : super(message: message ?? 'Failed to parse data');
}

class LockingFailure extends Failure {
  const LockingFailure({String? message})
    : super(message: message ?? 'Panel is locked and cannot be modified');
}

class UnknownFailure extends Failure {
  const UnknownFailure({String? message})
    : super(message: message ?? 'An unknown error occurred');
}

// ─── API business-logic failures (mapped from error codes) ──

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({String? message})
    : super(
        message: message ?? 'Sesi telah berakhir, silakan login kembali',
        errorCode: ApiErrorCode.unauthorized,
      );
}

class ForceUpdateFailure extends Failure {
  const ForceUpdateFailure({String? message})
    : super(
        message: message ?? 'Versi aplikasi sudah tidak didukung',
        errorCode: ApiErrorCode.forceUpdate,
      );
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure({String? message})
    : super(
        message: message ?? 'Employee ID atau password salah',
        errorCode: ApiErrorCode.invalidCredentials,
      );
}

class OverBudgetFailure extends Failure {
  const OverBudgetFailure({String? message})
    : super(
        message: message ?? 'Melebihi budget yang disetujui',
        errorCode: ApiErrorCode.overBudget,
      );
}

class TaskAlreadyStartedFailure extends Failure {
  const TaskAlreadyStartedFailure({String? message})
    : super(
        message: message ?? 'Task sudah dimulai',
        errorCode: ApiErrorCode.taskAlreadyStarted,
      );
}

class InvalidTaskFailure extends Failure {
  const InvalidTaskFailure({String? message})
    : super(
        message: message ?? 'Task tidak valid',
        errorCode: ApiErrorCode.invalidTask,
      );
}

class RejectNoteRequiredFailure extends Failure {
  const RejectNoteRequiredFailure({String? message})
    : super(
        message: message ?? 'Catatan penolakan wajib diisi',
        errorCode: ApiErrorCode.rejectNoteRequired,
      );
}

class QcAlreadyValidatedFailure extends Failure {
  const QcAlreadyValidatedFailure({String? message})
    : super(
        message: message ?? 'QC sudah divalidasi',
        errorCode: ApiErrorCode.qcAlreadyValidated,
      );
}

class DataNotFoundFailure extends Failure {
  const DataNotFoundFailure({String? message})
    : super(
        message: message ?? 'Data tidak ditemukan',
        errorCode: ApiErrorCode.dataNotFound,
      );
}

class DuplicateEntryFailure extends Failure {
  const DuplicateEntryFailure({String? message})
    : super(
        message: message ?? 'Data sudah ada',
        errorCode: ApiErrorCode.duplicateEntry,
      );
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({String? message})
    : super(
        message: message ?? 'Anda tidak memiliki akses',
        errorCode: ApiErrorCode.forbidden,
      );
}

// ─── API error code constants ───────────────────────────────

abstract class ApiErrorCode {
  static const forceUpdate = 'FORCE_UPDATE';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const overBudget = 'OVER_BUDGET';
  static const taskAlreadyStarted = 'TASK_ALREADY_STARTED';
  static const invalidTask = 'INVALID_TASK';
  static const rejectNoteRequired = 'REJECT_NOTE_REQUIRED';
  static const qcAlreadyValidated = 'QC_ALREADY_VALIDATED';
  static const unauthorized = 'UNAUTHORIZED';
  static const dataNotFound = 'DATA_NOT_FOUND';
  static const duplicateEntry = 'DUPLICATE_ENTRY';
  static const forbidden = 'FORBIDDEN';
  static const validationError = 'VALIDATION_ERROR';
  static const internalError = 'INTERNAL_ERROR';

  /// Maps an API error code string to the corresponding Failure.
  static Failure fromCode(String code, String? message) {
    return switch (code) {
      forceUpdate => ForceUpdateFailure(message: message),
      invalidCredentials => InvalidCredentialsFailure(message: message),
      overBudget => OverBudgetFailure(message: message),
      taskAlreadyStarted => TaskAlreadyStartedFailure(message: message),
      invalidTask => InvalidTaskFailure(message: message),
      rejectNoteRequired => RejectNoteRequiredFailure(message: message),
      qcAlreadyValidated => QcAlreadyValidatedFailure(message: message),
      unauthorized => UnauthorizedFailure(message: message),
      dataNotFound => DataNotFoundFailure(message: message),
      duplicateEntry => DuplicateEntryFailure(message: message),
      forbidden => ForbiddenFailure(message: message),
      _ => ClientFailure(
        message: message ?? 'Terjadi kesalahan',
        errorCode: code,
      ),
    };
  }
}
