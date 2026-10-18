import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/system_bridge.dart';
import '../widgets/fx.dart';

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

  Widget _row(bool ok, IconData icon, String name, String why) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GoldIconBadge(icon, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(why,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: ok ? AppColors.gold : cs.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allOk = _permsOk && _batteryOk;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                const GoldIconBadge(Icons.school_outlined, size: 72),
                const SizedBox(height: 20),
                Text('Welcome to StudyReels',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: cs.onSurface)),
                const SizedBox(height: 8),
                Text('A couple of one-time permissions,\nthen everything runs on-device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 28),
                _row(_permsOk, Icons.video_library_outlined,
                    'Notifications & video access',
                    'Download progress alerts; import lecture videos'),
                _row(_batteryOk, Icons.battery_saver_outlined,
                    'Battery optimization exemption',
                    'Keeps the model download alive in the background'),
                const Spacer(),
                if (!allOk)
                  GoldButton(
                    label: _busy ? 'Asking…' : 'Grant all',
                    icon: Icons.check_circle_outline,
                    onPressed: _busy ? null : _grantAll,
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _continue,
                  child: Text(allOk ? 'Continue' : 'Skip for now',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
