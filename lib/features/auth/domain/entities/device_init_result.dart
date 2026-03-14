import 'package:equatable/equatable.dart';

/// Result from POST /auth/device-init.
class DeviceInitResult extends Equatable {
  final String versionStatus; // "LATEST" or "FORCE_UPDATE"
  final String? tempToken;
  final String? message;
  final String? downloadUrl;

  const DeviceInitResult({
    required this.versionStatus,
    this.tempToken,
    this.message,
    this.downloadUrl,
  });

  bool get isLatest => versionStatus == 'LATEST';
  bool get isForceUpdate => versionStatus == 'FORCE_UPDATE';

  @override
  List<Object?> get props => [versionStatus, tempToken, message, downloadUrl];
}
