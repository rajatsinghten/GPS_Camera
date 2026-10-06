import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/photo_provider.dart';
import 'screens/camera_screen.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GPSCameraApp());
}

class GPSCameraApp extends StatelessWidget {
  const GPSCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PhotoProvider(),
      child: MaterialApp(
        title: 'GPS Camera',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const PermissionGate(),
      ),
    );
  }
}

/// Requests all permissions at launch before showing the app
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  static const _requiredPermissions = <Permission>[
    Permission.camera,
    Permission.location,
  ];

  bool _isChecking = true;
  bool _allGranted = false;
  bool _requestFailed = false;
  Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (mounted) setState(() => _isChecking = true);

    Map<Permission, PermissionStatus> statuses;
    var requestFailed = false;

    try {
      statuses = await _requiredPermissions.request();
    } catch (e) {
      // A missing or misbehaving platform plugin must not leave the app stuck
      // on the splash screen forever with no way forward.
      debugPrint('Permission request failed: $e');
      statuses = {
        for (final permission in _requiredPermissions)
          permission: PermissionStatus.denied,
      };
      requestFailed = true;
    }

    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    if (!mounted) return;
    setState(() {
      _statuses = statuses;
      _isChecking = false;
      _allGranted = allGranted;
      _requestFailed = requestFailed;
    });
  }

  Future<void> _openSettings() async {
    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open system settings")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  color: AppTheme.accent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'GPS Map Camera',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Setting up permissions...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppTheme.accent),
            ],
          ),
        ),
      );
    }

    if (_allGranted) {
      return const HomeScreen();
    }

    // Show permission denied screen with retry
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.dangerRed,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions Required',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'GPS Map Camera needs your camera and location to stamp photos with GPS coordinates.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_requestFailed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Couldn't reach the permission system. Check permissions from system settings.",
                    style: TextStyle(
                      color: AppTheme.dangerRed,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Permission status list
              ..._statuses.entries.map((entry) {
                final name = switch (entry.key) {
                  Permission.camera => 'Camera',
                  Permission.location => 'Location',
                  _ => entry.key.toString().split('.').last,
                };
                final granted =
                    entry.value.isGranted || entry.value.isLimited;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        granted
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: granted
                            ? AppTheme.accentGreen
                            : AppTheme.dangerRed,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        name[0].toUpperCase() + name.substring(1),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        granted ? 'Granted' : 'Denied',
                        style: TextStyle(
                          color: granted
                              ? AppTheme.accentGreen
                              : AppTheme.dangerRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _openSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cardDark,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                AppTheme.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: const Text('Open Settings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppTheme.accent.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppTheme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Allow proceeding anyway with limited functionality
                  setState(() => _allGranted = true);
                },
                child: Text(
                  'Continue Anyway',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraScreen();
  }
}
