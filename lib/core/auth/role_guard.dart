import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../session/session_manager.dart';
import 'rbac.dart';

/// Widget that conditionally renders its child based on the user's role permissions.
///
/// If the user lacks the required permission, [fallback] is rendered instead
/// (defaults to an empty SizedBox).
class RoleGuard extends StatelessWidget {
  final Permission permission;
  final Widget child;
  final Widget fallback;

  const RoleGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final role = sl<SessionManager>().role;
    if (hasPermission(role, permission)) {
      return child;
    }
    return fallback;
  }
}

/// Widget that conditionally renders child based on ANY of the given permissions.
class RoleGuardAny extends StatelessWidget {
  final List<Permission> permissions;
  final Widget child;
  final Widget fallback;

  const RoleGuardAny({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final role = sl<SessionManager>().role;
    final hasAny = permissions.any((p) => hasPermission(role, p));
    return hasAny ? child : fallback;
  }
}

/// Widget that conditionally renders child based on [UserRole] list.
///
/// Usage:
/// ```dart
/// RoleGuardByRole(
///   allowedRoles: [UserRole.kd, UserRole.pm],
///   child: CreateJobPlanButton(),
/// )
/// ```
class RoleGuardByRole extends StatelessWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  const RoleGuardByRole({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final userRole = UserRole.fromString(session.role);
    if (userRole != null && allowedRoles.contains(userRole)) {
      return child;
    }
    return fallback;
  }
}

/// Widget that conditionally renders child based on BE permission codes (strings).
///
/// Usage:
/// ```dart
/// PermGuard(
///   permission: Perms.woCreate,
///   child: CreateWoButton(),
/// )
/// ```
class PermGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget fallback;

  const PermGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    return session.hasPerm(permission) ? child : fallback;
  }
}
