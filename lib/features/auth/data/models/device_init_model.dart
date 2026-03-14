import '../../domain/entities/device_init_result.dart';

class DeviceInitModel {
  final String versionStatus;
  final String? tempToken;
  final String? message;
  final String? downloadUrl;

  const DeviceInitModel({
    required this.versionStatus,
    this.tempToken,
    this.message,
    this.downloadUrl,
  });

  factory DeviceInitModel.fromJson(Map<String, dynamic> json) {
    return DeviceInitModel(
      versionStatus: json['versionStatus'] as String? ?? 'LATEST',
      tempToken: json['tempToken'] as String?,
      message: json['message'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
    );
  }

  DeviceInitResult toEntity() => DeviceInitResult(
        versionStatus: versionStatus,
        tempToken: tempToken,
        message: message,
        downloadUrl: downloadUrl,
      );
}
