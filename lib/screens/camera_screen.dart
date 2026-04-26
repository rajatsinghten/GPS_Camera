import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/gps_photo.dart';

import '../services/location_service.dart';
import '../services/telemetry_service.dart';
import '../utils/theme.dart';
import '../widgets/gps_watermark.dart';
import 'review_screen.dart';
import 'gallery_screen.dart';
import '../providers/photo_provider.dart';
import 'settings_screen.dart';

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
  final GlobalKey _compositeKey = GlobalKey();
  GpsPhoto? _photoToProcess;
  bool _isSavingComposite = false;
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

  // Status Strip State
  FocusMode _focusMode = FocusMode.auto;
  bool _hdrEnabled = false;
  int _timerSeconds = 0;

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
      ResolutionPreset.ultraHigh,
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

    // Timer countdown delay
    if (_timerSeconds > 0) {
      await Future.delayed(Duration(seconds: _timerSeconds));
    }

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
        setState(() {
          _photoToProcess = photo;
          _isCapturing = false;
          _isSavingComposite = true;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processAndSavePhoto(photo);
        });
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _processAndSavePhoto(GpsPhoto photo) async {
    try {
      // Ensure the high-res capture is fully decoded into memory before capturing the RepaintBoundary.
      await precacheImage(FileImage(File(photo.imagePath)), context);
      
      // Delay to guarantee the RepaintBoundary has finished painting the newly decoded image across all pipeline stages
      await Future.delayed(const Duration(milliseconds: 350));
      
      final boundary = _compositeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Lower pixelRatio to 3.5 (approx 1400x1900 resolution). This provides an incredibly sharp 
      // visual quality while reducing the CPU-bound PNG encoding time from ~4 seconds down to ~0.5s!
      final image = await boundary.toImage(pixelRatio: 3.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      
      if (bytes != null) {
        // Save to Android/iOS Gallery directly
        await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: 'GPS_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Save to App Documents for the in-app gallery view
        final directory = await getApplicationDocumentsDirectory();
        final gpsDir = Directory('${directory.path}/gps_photos');
        if (!await gpsDir.exists()) await gpsDir.create(recursive: true);
        final file = File('${gpsDir.path}/GPS_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);

        final savedPhoto = GpsPhoto(
          imagePath: photo.imagePath,
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
          watermarkRotation: photo.watermarkRotation,
        );
        
        if (mounted) {
          context.read<PhotoProvider>().addPhoto(savedPhoto);
        }
      }
    } catch (e) {
      debugPrint('Background save error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingComposite = false;
          _photoToProcess = null;
        });
      }
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
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final nextIndex = (modes.indexOf(_flashMode) + 1) % modes.length;
    final next = modes[nextIndex];
    _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  void _toggleWatermarkMode() {
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
  }

  void _toggleHDR() {
    setState(() => _hdrEnabled = !_hdrEnabled);
  }

  void _toggleTimer() {
    final timers = [0, 3, 10];
    final nextIndex = (timers.indexOf(_timerSeconds) + 1) % timers.length;
    setState(() => _timerSeconds = timers[nextIndex]);
  }

  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          initialWatermarkMode: _watermarkMode,
          initialFlashMode: _flashMode,
          initialTimerSeconds: _timerSeconds,
          initialHdrEnabled: _hdrEnabled,
          onOrientationChange: (mode) {
            setState(() {
              _watermarkMode = mode;
              if (mode == WatermarkMode.portrait) _currentQuarterTurns = 0;
              if (mode == WatermarkMode.landscape) _currentQuarterTurns = 1;
            });
          },
          onFlashChange: (mode) {
            _controller?.setFlashMode(mode);
            setState(() => _flashMode = mode);
          },
          onTimerChange: (seconds) {
            setState(() => _timerSeconds = seconds);
          },
          onHDRChange: (enabled) {
            setState(() => _hdrEnabled = enabled);
          },
        ),
      ),
    );
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
        children: [
          // High-resolution renderer for capturing (hidden completely behind the main opaque UI)
          if (_photoToProcess != null)
            IgnorePointer(
              child: RepaintBoundary(
                key: _compositeKey,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width * (4 / 3), // Perfect 3:4 aspect ratio
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Source Image from Camera
                      Image.file(
                        File(_photoToProcess!.imagePath),
                        fit: BoxFit.cover, // Automatically crops the high-res natively captured image to 3:4!
                      ),
                      
                      // Watermark Overlay
                      Positioned(
                        bottom: (_photoToProcess!.watermarkRotation == 0 || _photoToProcess!.watermarkRotation == 1 || _photoToProcess!.watermarkRotation == 3) ? 0.0 : null,
                        top: (_photoToProcess!.watermarkRotation == 2 || _photoToProcess!.watermarkRotation == 1 || _photoToProcess!.watermarkRotation == 3) ? 0.0 : null,
                        left: (_photoToProcess!.watermarkRotation == 0 || _photoToProcess!.watermarkRotation == 2 || _photoToProcess!.watermarkRotation == 1) ? 0.0 : null,
                        right: (_photoToProcess!.watermarkRotation == 0 || _photoToProcess!.watermarkRotation == 2 || _photoToProcess!.watermarkRotation == 3) ? 0.0 : null,
                        child: GpsWatermark(photo: _photoToProcess!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Column(
            children: [
              // --- TOP BAR (Solid Black) ---
          Container(
            height: MediaQuery.of(context).padding.top + 88,
            color: Colors.black,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _toggleFlash,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    _flashMode == FlashMode.off ? Icons.flash_off_rounded : (_flashMode == FlashMode.auto ? Icons.flash_auto_rounded : Icons.flash_on_rounded),
                    color: _flashMode == FlashMode.off ? Colors.white : Colors.amber,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: _toggleWatermarkMode,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    _watermarkMode == WatermarkMode.auto ? Icons.screen_rotation_rounded : (_watermarkMode == WatermarkMode.portrait ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded),
                    color: _watermarkMode == WatermarkMode.auto ? Colors.amber : Colors.white,
                    size: 20,
                  ),
                ),
                GestureDetector(
                  onTap: _toggleHDR,
                  child: Text(
                    'HDR',
                    style: TextStyle(
                      color: _hdrEnabled ? Colors.amber : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleTimer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    _timerSeconds == 0 ? Icons.timer_off_rounded : (_timerSeconds == 3 ? Icons.timer_3_rounded : Icons.timer_10_rounded),
                    color: _timerSeconds > 0 ? Colors.amber : Colors.white,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: _showSettings,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          // --- CAMERA VIEWFINDER (4:3 Ratio) ---
          if (_isInitialized && _controller != null)
            Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                      children: [
                        // Camera Feed
                        GestureDetector(
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: _controller!.value.previewSize?.height ?? 1080,
                                height: _controller!.value.previewSize?.width ?? 1440,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),
                        ),
                        
                        // Flash Overlay
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

                        // GPS Watermark
                        if (livePhoto != null)
                          Positioned(
                            bottom: (_currentQuarterTurns == 0 || _currentQuarterTurns == 1 || _currentQuarterTurns == 3) ? (_currentQuarterTurns == 0 ? 12.0 : 12.0) : null,
                            top: (_currentQuarterTurns == 2 || _currentQuarterTurns == 1 || _currentQuarterTurns == 3) ? (_currentQuarterTurns == 2 ? 12.0 : 12.0) : null,
                            left: (_currentQuarterTurns == 0 || _currentQuarterTurns == 2 || _currentQuarterTurns == 1) ? 0.0 : null,
                            right: (_currentQuarterTurns == 0 || _currentQuarterTurns == 2 || _currentQuarterTurns == 3) ? 0.0 : null,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.85,
                                child: GpsWatermark(photo: livePhoto),
                              ),
                            ),
                          ),


                      ],
                    ),
                ),
            )
          else
            Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
            ),

          // --- BOTTOM CONTROL BAR ---
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              padding: EdgeInsets.only(
                top: 16.0, // Padding from the edge of the viewfinder
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Zoom bubbles
                      if (_maxZoom > 1.0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28.0), // Increased from 16.0
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildZoomBubble(1.0, '1x'),
                              const SizedBox(width: 8),
                              if (_maxZoom >= 2.0)
                                _buildZoomBubble(2.0, '2x'),
                            ],
                          ),
                        ),
                        
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery button
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const GalleryScreen()),
                              );
                            },
                            child: Consumer<PhotoProvider>(
                              builder: (context, provider, child) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Badge(
                                    isLabelVisible: provider.photoCount > 0,
                                    label: Text('${provider.photoCount}', style: const TextStyle(fontSize: 8)),
                                    backgroundColor: AppTheme.accent,
                                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Shutter button
                          GestureDetector(
                            onTap: _isCapturing ? null : _capturePhoto,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 84, // Increased by ~10%
                              height: 84, // Increased by ~10%
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3.5),
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
                          
                          // Flip camera button
                          GestureDetector(
                            onTap: _switchCamera,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Text CAMERA at the bottom
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'CAMERA',
                      style: TextStyle(
                        color: Colors.white, // Highlighted yellow like iOS camera modes
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildZoomBubble(double zoom, String label) {
    final isSelected = _currentZoom == zoom;
    return GestureDetector(
      onTap: () {
        setState(() => _currentZoom = zoom);
        _controller?.setZoomLevel(zoom);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 0,
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
