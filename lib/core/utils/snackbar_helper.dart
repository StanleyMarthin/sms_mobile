import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// In-app overlay notification that slides in from the top.
///
/// Appears just below the status bar / app header area,
/// styled to match the dark luxury theme.
///
/// Usage in BlocListener:
/// ```dart
/// if (state is TaskSubmitSuccess) {
///   AppNotification.showSuccess(context, state.message);
/// }
/// if (state is TaskSubmitFailure) {
///   AppNotification.showError(context, state.message);
/// }
/// ```
class AppNotification {
  AppNotification._();

  static OverlayEntry? _currentOverlay;

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.statusDone, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.statusLocked, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, AppColors.orange, Icons.warning_amber_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color accentColor,
    IconData icon,
  ) {
    // Dismiss existing notification
    _dismiss();

    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _OverlayNotification(
        message: message,
        accentColor: accentColor,
        icon: icon,
        topPadding: topPadding,
        onDismiss: () {
          entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);
  }

  static void _dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _OverlayNotification extends StatefulWidget {
  final String message;
  final Color accentColor;
  final IconData icon;
  final double topPadding;
  final VoidCallback onDismiss;

  const _OverlayNotification({
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_OverlayNotification> createState() => _OverlayNotificationState();
}

class _OverlayNotificationState extends State<_OverlayNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), _animateOut);
  }

  void _animateOut() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 4,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _animateOut,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _animateOut();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.accentColor.withAlpha(80),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, color: widget.accentColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _animateOut,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
