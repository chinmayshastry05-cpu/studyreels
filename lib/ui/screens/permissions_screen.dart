import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/system_bridge.dart';

const _green = Color(0xFF39FF14);

/// First-launch onboarding: asks for everything the app needs up front
/// (notifications for download progress, video access for importing
/// lectures, battery exemption so the background download is not killed).
class PermissionsScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionsScreen({super.key, required this.onDone});

  static Future<bool> isDone() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/.onboarded').exists();
  }

  static Future<void> markDone() async {
    final docs = await getApplicationDocumentsDirectory();
    await File('${docs.path}/.onboarded').writeAsString('1');
  }

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _permsOk = false;
  bool _batteryOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final missing = await SystemBridge.missingPermissions();
    final battery = await SystemBridge.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _permsOk = missing.isEmpty;
      _batteryOk = battery;
    });
  }

  Future<void> _grantAll() async {
    setState(() => _busy = true);
    await SystemBridge.requestPermissions();
    await _refresh();
    if (!_batteryOk) {
      await SystemBridge.requestIgnoreBatteryOptimizations();
    }
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  Future<void> _continue() async {
    await PermissionsScreen.markDone();
    widget.onDone();
  }

  Widget _line(bool ok, String name, String why) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: ok ? '[ OK ] ' : '[ -- ] ',
            style: TextStyle(color: ok ? _green : Colors.amber)),
        TextSpan(text: '$name\n', style: const TextStyle(color: _green)),
        TextSpan(
            text: '       $why',
            style: const TextStyle(color: Colors.white54)),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, color: _green),
            child: ListView(
              children: [
                const Text('studyreels@device:~\$ ./setup --permissions',
                    style: TextStyle(color: _green)),
                const SizedBox(height: 16),
                const Text('Requesting everything up front, once.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                _line(_permsOk, 'notifications + video access',
                    'download progress alerts; import lecture videos'),
                _line(_batteryOk, 'battery optimization exemption',
                    'keeps the model download running in background'),
                const SizedBox(height: 12),
                const Text('Everything runs on-device. Internet is used only '
                    'for the one-time model download.',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 24),
                if (!(_permsOk && _batteryOk))
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _green, foregroundColor: Colors.black),
                    onPressed: _busy ? null : _grantAll,
                    child: const Text('GRANT ALL'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: _green),
                  onPressed: _busy ? null : _continue,
                  child: Text(_permsOk && _batteryOk ? 'CONTINUE' : 'SKIP FOR NOW'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
