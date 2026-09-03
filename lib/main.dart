// REF: VIGILO-MVP-R41Y-2025-08-17
// Changes vs R41X ONLY:
// 1) Home screen empty state: shows icon + "No exams yet" when there are no cards.
// 2) Officer Tools → Messages: "Edit presets" added for Quick Messages (persisted in localStorage).

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'services/security_service.dart';
import 'utils/app_themes.dart';
import 'views/home_screen.dart';
import 'views/no_lock_screen.dart';
import 'views/widgets/security_privacy_shield.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const VigiloApp());
}

class VigiloApp extends StatefulWidget {
  const VigiloApp({super.key});

  @override
  State<VigiloApp> createState() => _VigiloAppState();
}

class _VigiloAppState extends State<VigiloApp> with WidgetsBindingObserver {
  bool dark = true;
  bool _isNoLockState = false;
  bool _isShieldActive = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _checkSecurityLockOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      SecurityService().recordPause();
    } else if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAppResumeSecurity();
      });
    }
  }

  Future<void> _checkSecurityLockOnLaunch() async {
    final hasLock = await SecurityService().isDeviceLockConfigured();
    if (!hasLock) {
      if (mounted) {
        setState(() {
          _isNoLockState = true;
          _isShieldActive = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isShieldActive = true);
    await _triggerSecurityAuthentication();
  }

  Future<void> _handleAppResumeSecurity() async {
    final hasLock = await SecurityService().isDeviceLockConfigured();
    if (!hasLock) {
      if (mounted) {
        setState(() {
          _isNoLockState = true;
          _isShieldActive = false;
        });
      }
      return;
    }

    if (_isNoLockState) {
      if (mounted) {
        setState(() {
          _isNoLockState = false;
          _isShieldActive = true;
        });
      }
      await _triggerSecurityAuthentication();
      return;
    }

    if (_isShieldActive) {
      return;
    }

    if (SecurityService().hasIdleTimedOut()) {
      if (mounted) setState(() => _isShieldActive = true);
      await _triggerSecurityAuthentication();
    } else {
      SecurityService().clearPause();
    }
  }

  Future<void> _triggerSecurityAuthentication() async {
    final hasLock = await SecurityService().isDeviceLockConfigured();
    if (!hasLock) {
      if (mounted) {
        setState(() {
          _isNoLockState = true;
          _isShieldActive = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isShieldActive = true;
        _isAuthenticating = true;
      });
    }

    // Await complete Flutter frame paint so SecurityPrivacyShield is drawn
    // on screen BEFORE native Knox/Biometric authentication window opens.
    await WidgetsBinding.instance.endOfFrame;

    final authenticated = await SecurityService().authenticate();
    if (!mounted) return;

    if (authenticated) {
      SecurityService().clearPause();
      setState(() {
        _isShieldActive = false;
        _isAuthenticating = false;
      });
    } else {
      setState(() {
        _isShieldActive = true;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigilo ERC',
      debugShowCheckedModeBanner: false,
      theme: dark ? darkTheme() : lightTheme(),
      builder: (context, child) {
        final bool isLocked = _isNoLockState || _isShieldActive;
        return Stack(
          children: [
            if (child != null)
              Offstage(
                offstage: isLocked,
                child: child,
              ),
            if (_isNoLockState)
              NoLockScreen(
                dark: dark,
                onToggleTheme: () {
                  setState(() => dark = !dark);
                },
                onLockDetected: () {
                  setState(() => _isNoLockState = false);
                  _checkSecurityLockOnLaunch();
                },
              )
            else if (_isShieldActive)
              SecurityPrivacyShield(
                dark: dark,
                onToggleTheme: () {
                  setState(() => dark = !dark);
                },
                onUnlockPressed: _triggerSecurityAuthentication,
                isAuthenticating: _isAuthenticating,
              ),
          ],
        );
      },
      home: HomeScreen(
        dark: dark,
        onToggleTheme: () {
          setState(() => dark = !dark);
        },
      ),
    );
  }
}
