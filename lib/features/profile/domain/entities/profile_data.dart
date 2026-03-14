library;

class ProfileData {
  const ProfileData({
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.division,
    required this.grade,
    required this.isActive,
    required this.permissions,
    required this.deviceId,
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
}