library;

class ProfileData {
  ProfileData({
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.division,
    required this.grade,
    required this.isActive,
    required this.permissions,
    required this.deviceId,
    this.photoUrl,
  });

  final String employeeId;
  final String fullName;
  final String email;
  final String role;
  final String division;
  final String grade;
  final bool isActive;
  final List<String> permissions;
  final String deviceId;

  /// URL foto profil dari object storage. Nullable — fallback ke avatar inisial
  /// jika null, kosong, atau gagal dimuat.
  final String? photoUrl;
}