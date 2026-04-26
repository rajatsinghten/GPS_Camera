import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/theme.dart';
import 'camera_screen.dart';

class SettingsScreen extends StatefulWidget {
  final WatermarkMode initialWatermarkMode;
  final FlashMode initialFlashMode;
  final int initialTimerSeconds;
  final bool initialHdrEnabled;
  final Function(WatermarkMode) onOrientationChange;
  final Function(FlashMode) onFlashChange;
  final Function(int) onTimerChange;
  final Function(bool) onHDRChange;

  const SettingsScreen({
    super.key,
    required this.initialWatermarkMode,
    required this.initialFlashMode,
    required this.initialTimerSeconds,
    required this.initialHdrEnabled,
    required this.onOrientationChange,
    required this.onFlashChange,
    required this.onTimerChange,
    required this.onHDRChange,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late WatermarkMode _currentWatermarkMode;
  late FlashMode _currentFlashMode;
  late int _currentTimerSeconds;
  late bool _currentHdrEnabled;

  @override
  void initState() {
    super.initState();
    _currentWatermarkMode = widget.initialWatermarkMode;
    _currentFlashMode = widget.initialFlashMode;
    _currentTimerSeconds = widget.initialTimerSeconds;
    _currentHdrEnabled = widget.initialHdrEnabled;
  }

  String get _flashLabel {
    switch (_currentFlashMode) {
      case FlashMode.off: return 'Off';
      case FlashMode.auto: return 'Auto';
      case FlashMode.always: return 'On';
      default: return 'Torch';
    }
  }

  String get _orientationLabel {
    switch (_currentWatermarkMode) {
      case WatermarkMode.auto: return 'Auto';
      case WatermarkMode.portrait: return 'Portrait';
      case WatermarkMode.landscape: return 'Landscape';
    }
  }

  void _toggleOrientation() {
    setState(() {
      if (_currentWatermarkMode == WatermarkMode.auto) {
        _currentWatermarkMode = WatermarkMode.portrait;
      } else if (_currentWatermarkMode == WatermarkMode.portrait) {
        _currentWatermarkMode = WatermarkMode.landscape;
      } else {
        _currentWatermarkMode = WatermarkMode.auto;
      }
    });
    widget.onOrientationChange(_currentWatermarkMode);
  }

  void _toggleFlash() {
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    setState(() => _currentFlashMode = modes[(modes.indexOf(_currentFlashMode) + 1) % modes.length]);
    widget.onFlashChange(_currentFlashMode);
  }

  void _toggleTimer() {
    final timers = [0, 3, 10];
    setState(() => _currentTimerSeconds = timers[(timers.indexOf(_currentTimerSeconds) + 1) % timers.length]);
    widget.onTimerChange(_currentTimerSeconds);
  }

  void _toggleHDR() {
    setState(() => _currentHdrEnabled = !_currentHdrEnabled);
    widget.onHDRChange(_currentHdrEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'SETTINGS',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSectionHeader('CAMERA DEFAULTS'),
          _buildSettingTile('Default Orientation', _orientationLabel, Icons.screen_rotation_rounded, _toggleOrientation),
          _buildSettingTile('Flash Mode', _flashLabel, Icons.flash_on_rounded, _toggleFlash),
          _buildSettingTile('Timer', _currentTimerSeconds == 0 ? 'Off' : '${_currentTimerSeconds}s', Icons.timer_rounded, _toggleTimer),
          _buildSettingTile('HDR', _currentHdrEnabled ? 'Enabled' : 'Disabled', Icons.hdr_on_rounded, _toggleHDR),
          const SizedBox(height: 24),
          _buildSectionHeader('ABOUT'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'Built by Rajat Singh\nNext Tech Lab\nSRM AP',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 16),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: Colors.white, size: 24),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: onTap,
    );
  }
}
