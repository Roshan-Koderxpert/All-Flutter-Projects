import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../modules/settings/utils/biometric_helper.dart';

class BiometricAppGuard extends StatefulWidget {
  const BiometricAppGuard({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricAppGuard> createState() => _BiometricAppGuardState();
}

class _BiometricAppGuardState extends State<BiometricAppGuard>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = false;
  bool _appWasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _appWasBackgrounded = true;
      return;
    }

    if (state != AppLifecycleState.resumed) return;
    if (!_appWasBackgrounded) return;

    _appWasBackgrounded = false;
    if (BiometricHelper.shouldSuppressResumeLock()) return;

    _lockAndPrompt();
  }

  Future<void> _lockAndPrompt() async {
    if (_checking || _locked) return;

    final enabled = await BiometricHelper.isBiometricEnabled();
    if (!enabled || !mounted) return;

    if (BiometricHelper.shouldSuppressResumeLock()) return;

    setState(() {
      _locked = true;
      _checking = true;
    });

    final result = await BiometricHelper.authenticate(
      reason: 'Authenticate to access ${AppConstants.appName}',
    );

    if (!mounted) return;

    setState(() {
      _checking = false;
      if (result == true) _locked = false;
    });
  }

  Future<void> _retry() => _lockAndPrompt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.92),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 72, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      'App Locked',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Authenticate to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _checking ? null : _retry,
                      child: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
