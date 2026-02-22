import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/gps_photo.dart';
import '../providers/photo_provider.dart';
import '../services/location_service.dart';
import '../services/telemetry_service.dart';
import '../utils/theme.dart';
import '../widgets/gps_watermark.dart';
import 'review_screen.dart';

enum WatermarkMode { auto, portrait, landscape }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isSwitching = false;
  Position? _currentPosition;
  String _currentAddress = 'Fetching location...';
  StreamSubscription<Position>? _positionStream;

  // Zoom
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0;

  // Live telemetry for viewfinder overlay
  double? _liveWindSpeed;
  double? _liveHumidity;
  double? _liveMagnetic;

  // Flash
  FlashMode _flashMode = FlashMode.off;

  // Watermark Orientation
  WatermarkMode _watermarkMode = WatermarkMode.portrait;
  int _currentQuarterTurns = 0;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accelSubscription = accelerometerEventStream().listen((event) {
      if (_watermarkMode == WatermarkMode.auto) {
        int newTurns = 0;
        if (event.x.abs() > 4.5) {
          // landscape
          newTurns = event.x > 0 ? 1 : 3;
        } else if (event.y.abs() > 4.5) {
          newTurns = event.y > 0 ? 0 : 2;
        }
        if (_currentQuarterTurns != newTurns && mounted) {
          setState(() => _currentQuarterTurns = newTurns);
        }
      }
    });
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _initializeCamera();
    _startLocationUpdates();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupCamera(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _setupCamera(int index) async {
    if (_cameras.isEmpty) return;

    if (mounted) setState(() => _isInitialized = false);

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();

      setState(() {
        _controller = controller;
        _selectedCameraIndex = index;
        _isInitialized = true;
        _isSwitching = false;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = 1.0;
        _baseZoom = 1.0;
      });
    } catch (e) {
      debugPrint('Camera setup error: $e');
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || !_isInitialized) return;
    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if (newZoom != _currentZoom) {
      setState(() => _currentZoom = newZoom);
      _controller!.setZoomLevel(newZoom);
    }
  }

  Future<void> _startLocationUpdates() async {
    final hasPermission = await LocationService.checkAndRequestPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _currentAddress = 'Location permission denied');
      return;
    }

    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _currentPosition = position);
      _updateAddress(position.latitude, position.longitude);
      _fetchTelemetry(position.latitude, position.longitude);
    }

    _positionStream = LocationService.getPositionStream().listen(
      (position) {
        if (mounted) {
          setState(() => _currentPosition = position);
          _updateAddress(position.latitude, position.longitude);
        }
      },
    );
  }

  Future<void> _updateAddress(double lat, double lng) async {
    final address = await LocationService.getAddressFromCoordinates(lat, lng);
    if (mounted) setState(() => _currentAddress = address);
  }

  Future<void> _fetchTelemetry(double lat, double lng) async {
    try {
      final results = await Future.wait([
        TelemetryService.getWeatherData(lat, lng),
        TelemetryService.getMagneticField(),
      ]);
      final weather = results[0] as WeatherData;
      final magnetic = results[1] as double?;
      if (mounted) {
        setState(() {
          _liveWindSpeed = weather.windSpeed;
          _liveHumidity = weather.humidity;
          _liveMagnetic = magnetic;
        });
      }
    } catch (e) {
      debugPrint('Telemetry fetch error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing ||
        _currentPosition == null) {
      if (_currentPosition == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Waiting for GPS location...', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    setState(() => _isCapturing = true);
    _flashController.forward().then((_) => _flashController.reverse());

    try {
      final image = await _controller!.takePicture();
      final pos = _currentPosition!;

      final addressParts = _currentAddress.split(',');
      final locationName = addressParts.length > 2
          ? addressParts[2].trim()
          : (addressParts.isNotEmpty ? addressParts[0].trim() : 'Unknown');

      final photo = GpsPhoto(
        imagePath: image.path,
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude != 0.0 ? pos.altitude : null,
        address: _currentAddress,
        locationName: locationName,
        timestamp: DateTime.now(),
        windSpeed: _liveWindSpeed,
        humidity: _liveHumidity,
        magneticField: _liveMagnetic,
        watermarkRotation: _currentQuarterTurns,
      );

      if (mounted) {
        setState(() => _isCapturing = false);
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ReviewScreen(photo: photo),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2 || _isSwitching) return;
    setState(() => _isSwitching = true);
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _setupCamera(newIndex);
  }

  void _toggleFlash() {
    if (_controller == null || !_isInitialized) return;
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];
    final nextIndex = (modes.indexOf(_flashMode) + 1) % modes.length;
    final next = modes[nextIndex];
    _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off: return Icons.flash_off_rounded;
      case FlashMode.auto: return Icons.flash_auto_rounded;
      case FlashMode.always: return Icons.flash_on_rounded;
      case FlashMode.torch: return Icons.flashlight_on_rounded;
    }
  }

  String get _flashLabel {
    switch (_flashMode) {
      case FlashMode.off: return 'OFF';
      case FlashMode.auto: return 'AUTO';
      case FlashMode.always: return 'ON';
      case FlashMode.torch: return 'TORCH';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(_selectedCameraIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSubscription?.cancel();
    _controller?.dispose();
    _positionStream?.cancel();
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  GpsPhoto? get _livePhoto {
    if (_currentPosition == null) return null;
    final pos = _currentPosition!;
    final addressParts = _currentAddress.split(',');
    final locationName = addressParts.length > 2
        ? addressParts[2].trim()
        : (addressParts.isNotEmpty ? addressParts[0].trim() : 'Unknown');
    return GpsPhoto(
      imagePath: '',
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude != 0.0 ? pos.altitude : null,
      address: _currentAddress,
      locationName: locationName,
      timestamp: DateTime.now(),
      windSpeed: _liveWindSpeed,
      humidity: _liveHumidity,
      magneticField: _liveMagnetic,
      watermarkRotation: _currentQuarterTurns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final livePhoto = _livePhoto;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (4:3 ratio)
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.previewSize?.height ?? 1080,
                          height: _controller!.value.previewSize?.width ?? 1440,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.accent),
                  const SizedBox(height: 16),
                  Text(
                    _isSwitching ? 'Switching Camera...' : 'Initializing Camera...',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Live GPS watermark on viewfinder
          if (livePhoto != null)
            Positioned(
              bottom: (_currentQuarterTurns == 0 || _currentQuarterTurns == 1 || _currentQuarterTurns == 3) ? (_currentQuarterTurns == 0 ? 180.0 : 120.0) : null,
              top: (_currentQuarterTurns == 2 || _currentQuarterTurns == 1 || _currentQuarterTurns == 3) ? (_currentQuarterTurns == 2 ? 140.0 : 120.0) : null,
              left: (_currentQuarterTurns == 0 || _currentQuarterTurns == 2 || _currentQuarterTurns == 1) ? 0.0 : null,
              right: (_currentQuarterTurns == 0 || _currentQuarterTurns == 2 || _currentQuarterTurns == 3) ? 0.0 : null,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.85,
                  child: GpsWatermark(photo: livePhoto),
                ),
              ),
            ),

          // Flash overlay
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _flashAnimation.value * 0.7),
                ),
              );
            },
          ),

          // Zoom indicator
          if (_isInitialized && _currentZoom > 1.0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

          // Top bar - GPS status
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final hasGps = _currentPosition != null;
                      final color = hasGps ? AppTheme.accentGreen : AppTheme.dangerRed;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(hasGps ? Icons.gps_fixed : Icons.gps_not_fixed, color: color, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              hasGps ? 'GPS LOCKED' : 'SEARCHING',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  // Rotation toggle
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_watermarkMode == WatermarkMode.auto) {
                          _watermarkMode = WatermarkMode.portrait;
                          _currentQuarterTurns = 0;
                        } else if (_watermarkMode == WatermarkMode.portrait) {
                          _watermarkMode = WatermarkMode.landscape;
                          _currentQuarterTurns = 1;
                        } else {
                          _watermarkMode = WatermarkMode.auto;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _watermarkMode != WatermarkMode.portrait
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _watermarkMode != WatermarkMode.portrait
                              ? Colors.blue.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _watermarkMode == WatermarkMode.auto
                                ? Icons.screen_rotation_rounded
                                : (_watermarkMode == WatermarkMode.landscape ? Icons.landscape_rounded : Icons.portrait_rounded),
                            color: _watermarkMode != WatermarkMode.portrait ? Colors.blue : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _watermarkMode.name.toUpperCase(),
                            style: TextStyle(
                              color: _watermarkMode != WatermarkMode.portrait ? Colors.blue : Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Flash toggle
                  GestureDetector(
                    onTap: _toggleFlash,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _flashMode != FlashMode.off
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _flashMode != FlashMode.off
                              ? Colors.amber.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _flashIcon,
                            color: _flashMode != FlashMode.off ? Colors.amber : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _flashLabel,
                            style: TextStyle(
                              color: _flashMode != FlashMode.off ? Colors.amber : Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_cameras.length > 1)
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: AnimatedRotation(
                          turns: _isSwitching ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom slider
                  if (_isInitialized && _maxZoom > 1.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Text('1x', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppTheme.accent,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                trackHeight: 2,
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              ),
                              child: Slider(
                                value: _currentZoom,
                                min: _minZoom,
                                max: _maxZoom,
                                onChanged: (value) {
                                  setState(() => _currentZoom = value);
                                  _controller?.setZoomLevel(value);
                                },
                              ),
                            ),
                          ),
                          Text('${_maxZoom.toStringAsFixed(0)}x', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  // Capture button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Gallery shortcut
                      Consumer<PhotoProvider>(
                        builder: (context, provider, _) {
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: provider.photos.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(provider.photos.first.compositePath ?? provider.photos.first.imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.photo_library_rounded, color: Colors.white54, size: 22),
                          );
                        },
                      ),
                      const SizedBox(width: 40),
                      // Shutter button
                      GestureDetector(
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing ? AppTheme.dangerRed : Colors.white,
                            ),
                            child: _isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                      const SizedBox(width: 48, height: 48),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
