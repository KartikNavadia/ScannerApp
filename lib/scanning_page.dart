import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'utils/app_colors.dart';
import 'utils/app_text_styles.dart';
import 'captured_images_page.dart';
import 'providers/scanning_provider.dart';

class ScanningPage extends StatelessWidget {
  const ScanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScanningProvider(),
      child: const _ScanningView(),
    );
  }
}

class _ScanningView extends StatefulWidget {
  const _ScanningView();

  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView>
    with WidgetsBindingObserver {
  late final ScanningProvider _provider;
  StreamSubscription<String>? _messageSub;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ScanningProvider>();
    _messageSub = _provider.messages.listen(_showMessage);
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _provider.releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      // User may be coming back from the Settings app.
      if (_provider.permissionsGranted) {
        _provider.initCamera();
      } else {
        _requestPermissions();
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequestingPermissions || _provider.permissionsGranted) return;
    _isRequestingPermissions = true;

    try {
      while (mounted) {
        final result = await _provider.requestPermissions();
        if (!mounted || result == PermissionResult.granted) return;

        if (result == PermissionResult.permanentlyDenied) {
          // The OS will no longer show the prompt, so send the user to
          // Settings. Permissions are re-checked when the app resumes.
          await _showPermissionDialog(openSettings: true);
          return;
        }

        // Plain denial: explain and ask again.
        await _showPermissionDialog(openSettings: false);
      }
    } finally {
      _isRequestingPermissions = false;
    }
  }

  Future<void> _showPermissionDialog({required bool openSettings}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions required'),
        content: Text(
          openSettings
              ? 'Camera permission is permanently denied. '
                    'Please enable it in Settings to continue.'
              : 'Camera permission is required to scan. '
                    'Please allow it to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (openSettings) openAppSettings();
            },
            child: Text(openSettings ? 'Open Settings' : 'Allow'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopCapturing() async {
    final paths = await _provider.stopCapturing();
    if (!mounted) return;

    if (paths.isEmpty) {
      _showMessage('No images captured');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CapturedImagesPage(
          imagePaths: paths,
          scanned: _provider.foundCodes,
          plainChecked: _provider.plainChecked,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Capture', style: AppTextStyles.headlineSm),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.zero,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _CameraArea(onRequestPermissions: _requestPermissions),
                ),
              ),
              const SizedBox(height: 16),
              _Controls(onStop: _stopCapturing),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraArea extends StatelessWidget {
  const _CameraArea({required this.onRequestPermissions});

  final VoidCallback onRequestPermissions;

  @override
  Widget build(BuildContext context) {
    // Only rebuild when the camera state changes, not on every capture.
    final (permissionsGranted, controller, isReady) = context.select(
      (ScanningProvider p) =>
          (p.permissionsGranted, p.controller, p.isCameraReady),
    );

    if (!permissionsGranted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Waiting for camera permission',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRequestPermissions,
              child: const Text('Grant permission'),
            ),
          ],
        ),
      );
    }
    if (controller == null || !isReady) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fill the area while keeping the preview's aspect ratio.
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0x66000000), Colors.transparent],
              stops: [0, 0.5],
            ),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final (isCapturing, isCameraReady, isTorchOn) = context.select(
      (ScanningProvider p) => (p.isCapturing, p.isCameraReady, p.isTorchOn),
    );
    final provider = context.read<ScanningProvider>();
    final canStart = !isCapturing && isCameraReady;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            isCapturing
                ? 'Capturing... Tap Stop when you are done.'
                : 'Point the camera at a QR code or barcode and tap Start '
                      'to begin capturing.',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Idle: Start fills the row. Capturing: Start and Stop share the
            // row equally, so Stop is as wide as Start.
            const gaps = 16.0;
            final idleStartWidth =
                constraints.maxWidth -
                _StopButton.collapsedWidth -
                _TorchButton.size -
                gaps;
            final sharedWidth =
                (constraints.maxWidth - _TorchButton.size - gaps) / 2;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StartButton(
                  width: isCapturing ? sharedWidth : idleStartWidth,
                  capturing: isCapturing,
                  enabled: canStart,
                  onPressed: provider.startCapturing,
                ),
                const SizedBox(width: 8),
                _StopButton(
                  width: isCapturing ? sharedWidth : _StopButton.collapsedWidth,
                  enabled: isCapturing,
                  onPressed: onStop,
                ),
                const SizedBox(width: 8),
                _TorchButton(
                  enabled: isCameraReady,
                  on: isTorchOn,
                  onPressed: provider.toggleTorch,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.width,
    required this.capturing,
    required this.enabled,
    required this.onPressed,
  });

  final double width;
  final bool capturing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled || capturing;
    final foreground = active ? AppColors.onPrimary : AppColors.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      height: 64,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      capturing ? Icons.fiber_manual_record : Icons.play_arrow,
                      size: 24,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      capturing ? 'Capturing' : 'Start',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: foreground,
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

/// Square icon button; the stop button grows wider (with a label) while
/// capturing.
class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.width,
    required this.enabled,
    required this.onPressed,
  });

  final double width;
  final bool enabled;
  final VoidCallback onPressed;

  static const collapsedWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.primary
        : AppColors.textSecondary.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? AppColors.primaryLight
              : AppColors.primaryLight.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Tooltip(
            message: 'Stop',
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop, size: 24, color: color),
                    if (enabled) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Stop',
                        style: AppTextStyles.headlineSm.copyWith(color: color),
                      ),
                    ],
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

class _TorchButton extends StatelessWidget {
  const _TorchButton({
    required this.enabled,
    required this.on,
    required this.onPressed,
  });

  final bool enabled;
  final bool on;
  final VoidCallback onPressed;

  static const size = 64.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: 64,
      decoration: BoxDecoration(
        color: on ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: on
              ? AppColors.primary
              : AppColors.primaryLight.withValues(alpha: enabled ? 1 : 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: on
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: on ? 12 : 2,
            offset: Offset(0, on ? 4 : 1),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Tooltip(
            message: on ? 'Turn flashlight off' : 'Turn flashlight on',
            child: Icon(
              on ? Icons.flashlight_on : Icons.flashlight_off,
              size: 24,
              color: on
                  ? AppColors.onPrimary
                  : enabled
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
