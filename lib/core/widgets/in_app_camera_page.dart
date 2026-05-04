import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';

/// In-App Camera page — gaya IG/WA, anti-OOM, output stabil.
///
/// Features:
/// - Flash: Auto / On / Off
/// - Exposure slider (-2.0 → +2.0, default +0.5 agar terang)
/// - Retake atau konfirmasi
/// - Output: JPEG resize ke 800×1024, quality 75 → ~150KB apapun HP-nya
///
/// Usage:
/// ```dart
/// final path = await Navigator.push<String>(
///   context,
///   MaterialPageRoute(builder: (_) => InAppCameraPage(slot: 'before')),
/// );
/// ```
/// Returns: [String] absolute path to the captured image, or null if cancelled.
class InAppCameraPage extends StatefulWidget {
  /// Slot name for SharedPreferences recovery (e.g. 'before', 'process', 'after', 'evidence')
  final String slot;

  /// Label ditampilkan di header kamera
  final String label;

  const InAppCameraPage({
    super.key,
    required this.slot,
    this.label = 'Ambil Foto',
  });

  @override
  State<InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<InAppCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  String? _capturedPath;

  FlashMode _flashMode = FlashMode.off;
  double _currentExposure = 0.5; // slightly brighter default
  double _minExposure = -2.0;
  double _maxExposure = 2.0;

  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<CameraController> _createCameraController(CameraDescription camera) async {
    final presets = [
      ResolutionPreset.high,
      ResolutionPreset.medium,
    ];

    Object? lastError;

    for (final preset in presets) {
      try {
        final ctrl = CameraController(
          camera,
          preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await ctrl.initialize();
        debugPrint('Camera initialized with preset: $preset');
        return ctrl;
      } catch (e) {
        lastError = e;
        debugPrint('Failed camera preset $preset: $e');
      }
    }

    throw Exception('Failed to initialize camera: $lastError');
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isInitialized = false);
        return;
      }

      // Prefer back camera
      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final ctrl = await _createCameraController(back);

      if (!mounted) return;

      // Set exposure range
      _minExposure = await ctrl.getMinExposureOffset();
      _maxExposure = await ctrl.getMaxExposureOffset();
      // Clamp default to brightness +0.5 or maxExposure whichever smaller
      _currentExposure = _currentExposure.clamp(_minExposure, _maxExposure);
      await ctrl.setExposureOffset(_currentExposure);
      await ctrl.setFlashMode(_flashMode);

      _controller = ctrl;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('InAppCamera init error: $e');
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  Future<void> _onTapFocus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(
      x.clamp(0.0, 1.0),
      y.clamp(0.0, 1.0),
    );

    try {
      await ctrl.setFocusMode(FocusMode.auto);
      await ctrl.setExposureMode(ExposureMode.auto);

      await ctrl.setFocusPoint(point);
      await ctrl.setExposurePoint(point);
    } catch (e) {
      debugPrint('Tap focus not supported: $e');
    }

    if (!mounted) return;
    setState(() => _focusPoint = details.localPosition);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Future<void> _takePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);
    HapticFeedback.mediumImpact();

    try {
      await ctrl.setFocusMode(FocusMode.auto);
      await ctrl.setExposureMode(ExposureMode.auto);

      await Future.delayed(const Duration(milliseconds: 250));

      final xfile = await ctrl.takePicture();

      // Resize to stable 1280×1600 using flutter_image_compress
      final resized = await _resizeImage(xfile.path);

      if (!mounted) return;
      setState(() {
        _capturedPath = resized;
        _isTakingPhoto = false;
      });
    } catch (e) {
      debugPrint('Take photo error: $e');
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  /// Resize image to max 1280×1600, quality 82 using flutter_image_compress.
  Future<String> _resizeImage(String sourcePath) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/cam_${widget.slot}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        tempPath,
        minWidth: 1280,
        minHeight: 1600,
        quality: 82,
        format: CompressFormat.jpeg,
      );

      return compressedFile?.path ?? sourcePath;
    } catch (e) {
      debugPrint('Compress error: $e');
      return sourcePath;
    }
  }

  void _retake() {
    setState(() => _capturedPath = null);
  }

  void _confirmPhoto() async {
    final path = _capturedPath;
    if (path == null) return;

    // Save slot for crash recovery
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_camera_slot', widget.slot);
    } catch (_) {}

    if (mounted) Navigator.of(context).pop(path);
  }

  void _cycleFlash() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    await ctrl.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flashlight_on_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  Color get _flashColor {
    switch (_flashMode) {
      case FlashMode.off:
        return AppColors.textMuted;
      case FlashMode.auto:
        return AppColors.gold;
      case FlashMode.always:
        return Colors.yellowAccent;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedPath != null
            ? _buildPreview()
            : _buildViewfinder(),
      ),
    );
  }

  // ─── VIEWFINDER ────────────────────────────────────────────────────────────
  Widget _buildViewfinder() {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 16),
            Text('Memuat kamera…',
                style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        _buildHeader(),

        // Camera Preview with Tap-to-Focus
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) => _onTapFocus(details, constraints),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera Feed
                    ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize?.height ?? 1,
                            height: _controller!.value.previewSize?.width ?? 1,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ),
                    ),

                    // Grid overlay (subtle rule-of-thirds)
                    _GridOverlay(),

                    // Focus Rect Indicator
                    if (_focusPoint != null)
                      Positioned(
                        left: _focusPoint!.dx - 35,
                        top: _focusPoint!.dy - 35,
                        child: _FocusSquare(),
                      ),

                    // Exposure slider on right side
                    Positioned(
                      right: 16,
                      top: 80,
                      bottom: 100,
                      child: _ExposureSlider(
                        min: _minExposure,
                  max: _maxExposure,
                  value: _currentExposure,
                  onChanged: (val) async {
                    setState(() => _currentExposure = val);
                    await _controller?.setExposureOffset(val);
                  },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Controls
        _buildControls(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Flash toggle
          GestureDetector(
            onTap: _cycleFlash,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(_flashIcon, color: _flashColor, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shutter button
          GestureDetector(
            onTap: _isTakingPhoto ? null : _takePhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                color: _isTakingPhoto
                    ? AppColors.gold.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isTakingPhoto ? 40 : 56,
                  height: _isTakingPhoto ? 40 : 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isTakingPhoto ? AppColors.gold : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PREVIEW / RETAKE ──────────────────────────────────────────────────────
  Widget _buildPreview() {
    return Column(
      children: [
        // Preview header
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.gold, size: 22),
              SizedBox(width: 10),
              Text(
                'Periksa foto sebelum disimpan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // Image preview
        Expanded(
          child: Image.file(
            File(_capturedPath!),
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),

        // Action buttons
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Retake
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retake,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Ulangi'),
                ),
              ),
              const SizedBox(width: 16),
              // Confirm
              Expanded(
                child: FilledButton.icon(
                  onPressed: _confirmPhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Gunakan Foto',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Exposure Slider (Vertical) ───────────────────────────────────────────────
class _ExposureSlider extends StatelessWidget {
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;

  const _ExposureSlider({
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wb_sunny_rounded, color: Colors.white70, size: 18),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: AppColors.gold,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
        const Icon(Icons.brightness_3_rounded,
            color: Colors.white30, size: 16),
      ],
    );
  }
}

// ─── Grid Overlay (Rule of Thirds) ────────────────────────────────────────────
class _GridOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    // Vertical lines at 1/3 and 2/3
    canvas.drawLine(
        Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);
    // Horizontal lines at 1/3 and 2/3
    canvas.drawLine(
        Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Focus Rect Indicator ──────────────────────────────────────────────────────
class _FocusSquare extends StatefulWidget {
  @override
  State<_FocusSquare> createState() => _FocusSquareState();
}

class _FocusSquareState extends State<_FocusSquare>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _ctrl.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _ctrl.forward();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1).animate(_ctrl),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
      ),
    );
  }
}
