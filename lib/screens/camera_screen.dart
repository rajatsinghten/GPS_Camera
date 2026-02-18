import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/gps_photo.dart';
import '../providers/photo_provider.dart';
import '../services/location_service.dart';
import '../services/telemetry_service.dart';
import '../utils/theme.dart';
import '../widgets/gps_watermark.dart';

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

  // Composite rendering
  final GlobalKey _compositeKey = GlobalKey();
  GpsPhoto? _lastCapturedPhoto;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    if (mounted) {
      setState(() => _isInitialized = false);
    }

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

  GpsPhoto _buildCurrentPhoto(String imagePath) {
    final pos = _currentPosition!;
    final addressParts = _currentAddress.split(',');
    final locationName = addressParts.length > 2
        ? addressParts[2].trim()
        : (addressParts.isNotEmpty ? addressParts[0].trim() : 'Unknown');

    return GpsPhoto(
      imagePath: imagePath,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude != 0.0 ? pos.altitude : null,
      address: _currentAddress,
      locationName: locationName,
      timestamp: DateTime.now(),
      windSpeed: _liveWindSpeed,
      humidity: _liveHumidity,
      magneticField: _liveMagnetic,
    );
  }

  /// Build the watermark as an off-screen widget, render to image, composite with photo
  Future<void> _captureAndSave() async {
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
      // 1. Take photo
      final image = await _controller!.takePicture();
      final photo = _buildCurrentPhoto(image.path);

      // 2. Set captured photo and trigger rebuild so off-screen composite renders
      setState(() => _lastCapturedPhoto = photo);

      // 3. Wait for composite to render (map tiles + image load)
      await Future.delayed(const Duration(milliseconds: 1200));

      final boundary = _compositeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Composite boundary not found');

      final compositeImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await compositeImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to render composite');
      final bytes = byteData.buffer.asUint8List();

      // 4. Save to phone gallery
      await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'GPS_${DateTime.now().millisecondsSinceEpoch}',
      );

      // 5. Save to app documents for in-app gallery
      final directory = await getApplicationDocumentsDirectory();
      final gpsDir = Directory('${directory.path}/gps_photos');
      if (!await gpsDir.exists()) await gpsDir.create(recursive: true);
      final fileName = 'GPS_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${gpsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 6. Add to provider
      if (mounted) {
        final savedPhoto = GpsPhoto(
          imagePath: image.path,
          latitude: photo.latitude,
          longitude: photo.longitude,
          altitude: photo.altitude,
          address: photo.address,
          locationName: photo.locationName,
          timestamp: photo.timestamp,
          compositePath: file.path,
          windSpeed: photo.windSpeed,
          humidity: photo.humidity,
          magneticField: photo.magneticField,
        );
        context.read<PhotoProvider>().addPhoto(savedPhoto);

        setState(() {
          _isCapturing = false;
          _lastCapturedPhoto = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo saved to gallery ✓',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E2E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Capture/save error: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2 || _isSwitching) return;
    setState(() => _isSwitching = true);
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _setupCamera(newIndex);
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
    _controller?.dispose();
    _positionStream?.cancel();
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  /// Build a live GpsPhoto from current sensor data for the viewfinder overlay
  GpsPhoto? get _livePhoto {
    if (_currentPosition == null) return null;
    return _buildCurrentPhoto('');
  }

  @override
  Widget build(BuildContext context) {
    final livePhoto = _livePhoto;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview with pinch-to-zoom
          if (_isInitialized && _controller != null)
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: CameraPreview(_controller!),
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

          // Live GPS watermark overlay on viewfinder
          if (livePhoto != null)
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
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
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2 * _pulseAnimation.value),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
                        ),
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
                        onTap: _isCapturing ? null : _captureAndSave,
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

          // OFF-SCREEN composite renderer (used to capture photo + watermark)
          if (_lastCapturedPhoto != null)
            Positioned(
              left: -2000,
              top: -2000,
              child: RepaintBoundary(
                key: _compositeKey,
                child: SizedBox(
                  width: 1080,
                  child: Container(
                    color: Colors.black,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.file(
                          File(_lastCapturedPhoto!.imagePath),
                          width: 1080,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => const SizedBox(height: 400),
                        ),
                        GpsWatermark(photo: _lastCapturedPhoto!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
