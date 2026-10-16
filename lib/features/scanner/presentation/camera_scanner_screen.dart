import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scanpro/core/constants/app_routes.dart';
import 'package:scanpro/core/errors/error_handler.dart';
import 'package:scanpro/core/services/image_processing_service.dart';
import 'package:scanpro/data/models/page_filter.dart';
import 'package:scanpro/features/scanner/presentation/widgets/interactive_document_crop_canvas.dart';
import 'package:scanpro/features/scanner/providers/scan_session_provider.dart';

/// Screen 4: Smart Camera Document Scanner.
///
/// Combines:
/// 1. On-device AI Document Edge & Auto-Capture Scanner (`google_mlkit_document_scanner`)
/// 2. Live CameraX scanner with automatic 4-corner edge detection, interactive
///    perspective crop confirmation, and shadow-removal Magic Scan processing.
class CameraScannerScreen extends ConsumerStatefulWidget {
  const CameraScannerScreen({
    super.key,
    this.retakePageIndex,
  });

  /// If non-null, capturing a photo replaces this page index in the session
  /// and returns immediately to the preview screen.
  final int? retakePageIndex;

  @override
  ConsumerState<CameraScannerScreen> createState() =>
      _CameraScannerScreenState();
}

class _CameraScannerScreenState extends ConsumerState<CameraScannerScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  CameraController? _controller;

  bool _isInitializing = true;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  String? _cameraError;

  FlashMode _flashMode = FlashMode.off;
  bool _isTakingPicture = false;
  bool _autoCaptureEnabled = false;
  Timer? _autoCaptureTimer;
  int _autoCaptureCountdown = 0;

  ScanFilterType _defaultScanFilter = ScanFilterType.enhancedColor;

  String _guidanceBannerText =
      'Align document inside frame • Tap AI Auto-Scan or Shutter to scan';
  bool _isWarningGuidance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndInitCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCaptureTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camController = _controller;
    if (camController == null || !camController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _autoCaptureTimer?.cancel();
      camController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_selectedCameraIndex);
    }
  }

  Future<void> _requestPermissionAndInitCamera() async {
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _isInitializing = false;
        _permissionDenied = true;
        _permissionPermanentlyDenied = status.isPermanentlyDenied;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _cameraError = 'No camera hardware detected on this device.';
        });
        return;
      }
      await _initCameraController(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError = 'Unable to access camera hardware. Please try again.';
      });
    }
  }

  Future<void> _initCameraController(int cameraIndex) async {
    if (_cameras.isEmpty) return;
    final previous = _controller;
    if (previous != null) {
      await previous.dispose();
    }

    final description = _cameras[cameraIndex % _cameras.length];
    final controller = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (!mounted) return;
      setState(() {
        _selectedCameraIndex = cameraIndex % _cameras.length;
        _isInitializing = false;
        _permissionDenied = false;
        _cameraError = null;
      });
      if (_autoCaptureEnabled) {
        _startAutoCaptureCountdown();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError = 'Camera initialization failed. Please retry.';
      });
    }
  }


  Future<void> _cycleFlashMode() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final nextMode = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.torch,
      _ => FlashMode.off,
    };

    try {
      await controller.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _flashMode = nextMode);
      }
    } catch (_) {
      // Ignore if device camera does not support flash/torch
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;
    _autoCaptureTimer?.cancel();
    setState(() => _isInitializing = true);
    await _initCameraController((_selectedCameraIndex + 1) % _cameras.length);
  }

  void _toggleAutoCapture() {
    setState(() {
      _autoCaptureEnabled = !_autoCaptureEnabled;
      if (_autoCaptureEnabled) {
        _guidanceBannerText =
            'Auto-Scan active: hold steady over document edges';
        _isWarningGuidance = false;
        _startAutoCaptureCountdown();
      } else {
        _autoCaptureTimer?.cancel();
        _autoCaptureCountdown = 0;
        _guidanceBannerText =
            'Align document inside frame • Tap shutter to scan & crop';
        _isWarningGuidance = false;
      }
    });
  }

  void _startAutoCaptureCountdown() {
    _autoCaptureTimer?.cancel();
    if (!_autoCaptureEnabled) return;

    setState(() => _autoCaptureCountdown = 3);
    _autoCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_autoCaptureEnabled || _isTakingPicture) {
        timer.cancel();
        return;
      }
      if (_autoCaptureCountdown > 1) {
        setState(() => _autoCaptureCountdown--);
      } else {
        timer.cancel();
        setState(() => _autoCaptureCountdown = 0);
        _captureAndScanDocument();
      }
    });
  }

  Future<void> _captureAndScanDocument() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
      _guidanceBannerText = 'Detecting document edges & scanning...';
    });

    try {
      final xfile = await controller.takePicture();
      final detectedCorners = await ref
          .read(imageProcessingServiceProvider)
          .detectDocumentCorners(xfile.path);

      if (!mounted) return;
      setState(() => _isTakingPicture = false);

      // Show interactive 4-corner Document Edge & Scan Filter confirmation modal
      // so the user verifies the detected document boundary and scan filter!
      final confirmedSettings = await showModalBottomSheet<PageEditSettings>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        backgroundColor: Colors.black,
        builder: (ctx) => PostCaptureEdgeCropSheet(
          rawImagePath: xfile.path,
          initialCorners: detectedCorners,
          initialFilter: _defaultScanFilter,
        ),
      );

      if (confirmedSettings == null || !mounted) {
        // User tapped Retake in the sheet
        setState(() {
          _guidanceBannerText =
              'Align document inside frame and hold steady to scan';
        });
        return;
      }

      setState(() {
        _isTakingPicture = true;
        _defaultScanFilter = confirmedSettings.filter;
        _guidanceBannerText =
            'Rectifying perspective & removing shadows (${confirmedSettings.filter.label})...';
      });

      final sessionNotifier = ref.read(scanSessionProvider.notifier);

      if (widget.retakePageIndex != null) {
        await sessionNotifier.replacePageAt(
          widget.retakePageIndex!,
          xfile.path,
          customSettings: confirmedSettings,
        );
        if (mounted) {
          context.pop();
        }
        return;
      }

      await sessionNotifier.addCapturedPage(
        xfile.path,
        customSettings: confirmedSettings,
      );

      if (!mounted) return;
      final latestPage = ref.read(scanSessionProvider).currentPage;
      final report = latestPage?.qualityReport;

      if (report != null) {
        final hasWarning =
            report.isLowLight || report.isBlurry || report.isOverExposed;
        setState(() {
          _guidanceBannerText = report.guidanceMessage;
          _isWarningGuidance = hasWarning;
        });
      }

      // Navigate directly to CapturedPreviewScreen so the user immediately sees
      // their cropped, flattened, shadow-cleaned scanned document (and can tap
      // "+ Add Scan" there if scanning multiple pages).
      context.pushReplacement(AppRoutes.capturedPreview);
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Could not scan document. Hold device steady and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTakingPicture = false);
      }
    }
  }

  Future<void> _importFromGalleryInScanner() async {
    try {
      final count = await ref
          .read(scanSessionProvider.notifier)
          .pickMultipleFromGallery();
      if (count > 0 && mounted) {
        context.pushReplacement(AppRoutes.capturedPreview);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final pageCount = session.pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Control Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close Scanner',
                    color: Colors.white,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  FilterChip(
                    selected: _autoCaptureEnabled,
                    onSelected: (_) => _toggleAutoCapture(),
                    label: Text(
                      _autoCaptureEnabled ? '3s Auto' : 'Manual',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Flash Mode',
                    color: _flashMode == FlashMode.off
                        ? Colors.white70
                        : Colors.amber,
                    onPressed: _cycleFlashMode,
                    icon: Icon(switch (_flashMode) {
                      FlashMode.auto => Icons.flash_auto_rounded,
                      FlashMode.torch => Icons.highlight_rounded,
                      _ => Icons.flash_off_rounded,
                    }),
                  ),
                  if (_cameras.length > 1)
                    IconButton(
                      tooltip: 'Switch Camera',
                      color: Colors.white,
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.cameraswitch_rounded),
                    ),
                ],
              ),
            ),

            // Live Camera Viewport & Document Frame Overlay
            Expanded(
              child: _buildViewportContent(),
            ),

            // Default Scan Filter Selector Strip (Magic Color / B&W Sharp / Grayscale / Original)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Scan Mode: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    for (final preset in ScanFilterType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(preset.label),
                          selected: _defaultScanFilter == preset,
                          onSelected: (_) {
                            setState(() => _defaultScanFilter = preset);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Lighting / Blur / Alignment Guidance Pill
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _isWarningGuidance
                    ? Colors.amber.shade900.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isWarningGuidance
                        ? Icons.warning_amber_rounded
                        : Icons.document_scanner_rounded,
                    color: _isWarningGuidance
                        ? Colors.amberAccent
                        : const Color(0xFF4DB6AC),
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _guidanceBannerText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Shutter, Gallery Import & Captured Pages Counter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Import from Gallery button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Import & Auto-Scan from Gallery',
                        onPressed: _importFromGalleryInScanner,
                        icon: const Icon(Icons.photo_library_rounded),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Import Scan',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),

                  // Center: Scan Shutter button
                  GestureDetector(
                    onTap: _isTakingPicture ? null : _captureAndScanDocument,
                    child: Container(
                      width: 78,
                      height: 78,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF26A69A),
                          width: 3.5,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isTakingPicture
                              ? Colors.grey
                              : Colors.white,
                        ),
                        child: _isTakingPicture
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFF0D47A1),
                                ),
                              )
                            : _autoCaptureCountdown > 0
                            ? Center(
                                child: Text(
                                  '$_autoCaptureCountdown',
                                  style: const TextStyle(
                                    color: Color(0xFF0D47A1),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.document_scanner_rounded,
                                color: Color(0xFF0D47A1),
                                size: 34,
                              ),
                      ),
                    ),
                  ),

                  // Right: Captured pages badge & Review button
                  if (pageCount > 0 && widget.retakePageIndex == null)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          context.pushReplacement(AppRoutes.capturedPreview),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(session.pages.last.scannedImagePath),
                                width: 32,
                                height: 40,
                                fit: BoxFit.cover,
                                cacheWidth: 120,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$pageCount ${pageCount == 1 ? "Scan" : "Scans"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                const Text(
                                  'Review →',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 68),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewportContent() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4DB6AC)),
            SizedBox(height: 16),
            Text(
              'Starting document scanner...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    size: 54,
                    color: Color(0xFF0D47A1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera Permission Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ScanPro uses your camera strictly offline to scan physical documents. No images are uploaded anywhere.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _permissionPermanentlyDenied
                        ? openAppSettings
                        : _requestPermissionAndInitCamera,
                    icon: const Icon(Icons.security_rounded),
                    label: Text(
                      _permissionPermanentlyDenied
                          ? 'Open App Settings'
                          : 'Grant Camera Access',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _importFromGalleryInScanner,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Import from Gallery Instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_cameraError != null ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.amber,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _cameraError ?? 'Camera unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _requestPermissionAndInitCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Camera'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),
            IgnorePointer(
              child: CustomPaint(
                painter: _DocumentFrameOverlayPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive post-capture 4-corner document edge verification and scan
/// filter studio shown immediately after snapping a picture.
class PostCaptureEdgeCropSheet extends StatefulWidget {
  const PostCaptureEdgeCropSheet({
    super.key,
    required this.rawImagePath,
    required this.initialCorners,
    required this.initialFilter,
    this.initialRotationTurns = 0,
    this.cancelLabel = 'Retake',
  });

  final String rawImagePath;
  final List<Offset> initialCorners;
  final ScanFilterType initialFilter;
  final int initialRotationTurns;
  final String cancelLabel;

  @override
  State<PostCaptureEdgeCropSheet> createState() =>
      _PostCaptureEdgeCropSheetState();
}

class _PostCaptureEdgeCropSheetState extends State<PostCaptureEdgeCropSheet> {
  late List<Offset> _corners;
  late ScanFilterType _selectedFilter;
  int _rotationTurns = 0;

  @override
  void initState() {
    super.initState();
    _corners = List<Offset>.from(widget.initialCorners);
    _selectedFilter = widget.initialFilter;
    _rotationTurns = widget.initialRotationTurns;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(widget.cancelLabel),
                  ),
                  const Expanded(
                    child: Text(
                      'Adjust Document Edges',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        PageEditSettings(
                          corners: _corners,
                          filter: _selectedFilter,
                          rotationQuarterTurns: _rotationTurns,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Scan Page'),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Drag any corner or edge to align with your document. Hold to see zoomed loupe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),

            // Interactive 4-Corner & 4-Edge Polygon Crop Area with Magnifier Loupe
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InteractiveDocumentCropCanvas(
                  imagePath: widget.rawImagePath,
                  corners: _corners,
                  onCornersChanged: (newCorners) {
                    setState(() => _corners = newCorners);
                  },
                  accentColor: const Color(0xFF00897B),
                ),
              ),
            ),

            // Filter Mode & Quick Crop Controls
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset in ScanFilterType.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(preset.label),
                              selected: _selectedFilter == preset,
                              onSelected: (_) {
                                setState(() => _selectedFilter = preset);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _corners = List<Offset>.from(
                              widget.initialCorners,
                            );
                          });
                        },
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: const Text('Auto Fit'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _corners = List<Offset>.from(
                              PageEditSettings.defaultCorners,
                            );
                          });
                        },
                        icon: const Icon(Icons.crop_free_rounded, size: 18),
                        label: const Text('Full Frame'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _rotationTurns = (_rotationTurns + 1) % 4;
                          });
                        },
                        icon: const Icon(Icons.rotate_right_rounded, size: 18),
                        label: const Text('Rotate 90°'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the document framing guide and teal corner target brackets over the camera feed.
class _DocumentFrameOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final frameRect = Rect.fromLTRB(
      w * 0.08,
      h * 0.07,
      w * 0.92,
      h * 0.93,
    );

    // Subtle darkened outer mask
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(
        RRect.fromRectAndRadius(frameRect, const Radius.circular(16)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.36),
    );

    // Subtle inner border
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(16)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Bold teal corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF26A69A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 32.0;
    final l = frameRect.left;
    final t = frameRect.top;
    final r = frameRect.right;
    final b = frameRect.bottom;

    final corners = Path()
      // Top-left
      ..moveTo(l, t + cornerLen)
      ..lineTo(l, t)
      ..lineTo(l + cornerLen, t)
      // Top-right
      ..moveTo(r - cornerLen, t)
      ..lineTo(r, t)
      ..lineTo(r, t + cornerLen)
      // Bottom-left
      ..moveTo(l, b - cornerLen)
      ..lineTo(l, b)
      ..lineTo(l + cornerLen, b)
      // Bottom-right
      ..moveTo(r - cornerLen, b)
      ..lineTo(r, b)
      ..lineTo(r, b - cornerLen);

    canvas.drawPath(corners, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
