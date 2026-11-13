import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'services/license_service.dart';
import 'services/security_service.dart';
import 'utils/app_themes.dart';
import 'utils/constants.dart';
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

  final initialLicenseRequired = await LicenseService.requiresValidLicense();

  runApp(VigiloApp(initialLicenseRequired: initialLicenseRequired));
}

class VigiloApp extends StatefulWidget {
  final bool? initialLicenseRequired;

  const VigiloApp({super.key, this.initialLicenseRequired});

  @override
  State<VigiloApp> createState() => _VigiloAppState();
}

class _VigiloAppState extends State<VigiloApp> with WidgetsBindingObserver {
  static const MethodChannel _screenEventsChannel =
      MethodChannel('com.vigilo.vigilo/screen_events');

  bool dark = true;
  bool _isNoLockState = false;
  bool _isShieldActive = true;
  bool _isAuthenticating = false;
  bool _requiresAuthentication = true;
  bool _hasInitiallyAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenEventsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenOff') {
        _handleScreenOff();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final savedDark =
            await _screenEventsChannel.invokeMethod<bool>('getTheme');
        if (savedDark != null && mounted && savedDark != dark) {
          setState(() {
            dark = savedDark;
          });
        }
      } catch (_) {}
      _syncThemeToNative(dark);
      _checkSecurityLockOnLaunch();
    });
  }

  Future<void> _syncThemeToNative(bool isDark) async {
    try {
      await _screenEventsChannel.invokeMethod('setTheme', {'dark': isDark});
    } catch (_) {}
  }

  Future<void> _dismissNativeCover() async {
    try {
      await _screenEventsChannel.invokeMethod('dismissNativeCover');
    } catch (_) {}
  }

  Future<void> _clearNativePauseTime() async {
    try {
      await _screenEventsChannel.invokeMethod('clearPauseTime');
    } catch (_) {}
  }

  Future<void> _setAuthenticating(bool authenticating) async {
    try {
      await _screenEventsChannel
          .invokeMethod('setAuthenticating', {'authenticating': authenticating});
    } catch (_) {}
  }

  void _toggleTheme() {
    setState(() {
      dark = !dark;
    });
    _syncThemeToNative(dark);
  }

  @override
  void dispose() {
    _screenEventsChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleScreenOff() {
    SecurityService().recordPause();
    // Do NOT pre-render the shield here — it causes a 1-3 frame flash of
    // "Vigilo ERC Locked" when the phone is unlocked within the idle timeout.
    // The resumed lifecycle path already raises the shield if needed.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      SecurityService().recordPause();
    } else if (state == AppLifecycleState.resumed) {
      if (SecurityService().isAuthenticating || _isNoLockState) {
        return;
      }

      // If authentication is actively required (from launch, timeout, or cancelled auth),
      // keep the shield locked.
      if (_requiresAuthentication) {
        if (mounted && !_isShieldActive) {
          setState(() {
            _isShieldActive = true;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _dismissNativeCover();
        });
        return;
      }

      // If authentication was NOT required (e.g. screen off or quick app switch):
      if (SecurityService().hasIdleTimedOut()) {
        // Idle timeout expired -> Lock the app & prompt authentication
        _requiresAuthentication = true;
        if (mounted && !_isShieldActive) {
          setState(() {
            _isShieldActive = true;
          });
        }
        _triggerSecurityAuthentication();
      } else {
        // Under timeout threshold -> Automatically dismiss the temporary sleep shield
        SecurityService().clearPause();
        _dismissNativeCover();
        _clearNativePauseTime();
        if (mounted && _isShieldActive) {
          setState(() {
            _isShieldActive = false;
          });
        }
      }
    }
  }

  Future<void> _checkSecurityLockOnLaunch() async {
    final hasLock = await SecurityService().isDeviceLockConfigured();
    if (!hasLock) {
      if (mounted) {
        setState(() {
          _isNoLockState = true;
          _isShieldActive = false;
          _requiresAuthentication = false;
          _hasInitiallyAuthenticated = true;
        });
      }
      FlutterNativeSplash.remove();
      _dismissNativeCover();
      return;
    }

    _requiresAuthentication = true;
    if (mounted) setState(() => _isShieldActive = true);
    // Ensure the SecurityPrivacyShield is fully painted to the GPU buffer
    // before dismissing the OS native splash screen.
    await WidgetsBinding.instance.endOfFrame;
    FlutterNativeSplash.remove();
    _dismissNativeCover();
    await _triggerSecurityAuthentication();
  }

  Future<void> _triggerSecurityAuthentication() async {
    final hasLock = await SecurityService().isDeviceLockConfigured();
    if (!hasLock) {
      if (mounted) {
        setState(() {
          _isNoLockState = true;
          _isShieldActive = false;
          _requiresAuthentication = false;
          _hasInitiallyAuthenticated = true;
        });
      }
      _dismissNativeCover();
      return;
    }

    _requiresAuthentication = true;
    if (mounted) {
      setState(() {
        _isShieldActive = true;
        _isAuthenticating = true;
      });
    }
    _setAuthenticating(true);

    // Await complete Flutter frame paint so SecurityPrivacyShield is drawn
    // on screen BEFORE native Knox/Biometric authentication window opens.
    await WidgetsBinding.instance.endOfFrame;
    _dismissNativeCover();

    final authenticated = await SecurityService().authenticate();
    _setAuthenticating(false);
    if (!mounted) return;

    if (authenticated) {
      SecurityService().clearPause();
      _clearNativePauseTime();
      _requiresAuthentication = false;
      setState(() {
        _isShieldActive = false;
        _isAuthenticating = false;
        _hasInitiallyAuthenticated = true;
      });
    } else {
      _requiresAuthentication = true;
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
      themeAnimationDuration: kThemeFadeDuration,
      themeAnimationCurve: kThemeFadeCurve,
      builder: (context, child) {
        final bool isLocked = _isNoLockState || _isShieldActive;
        final bool shouldMountChild = _hasInitiallyAuthenticated || !isLocked;
        return Stack(
          children: [
            if (child != null && shouldMountChild)
              Offstage(
                offstage: isLocked,
                child: TickerMode(
                  enabled: !isLocked,
                  child: child,
                ),
              ),
            if (_isNoLockState)
              NoLockScreen(
                dark: dark,
                onToggleTheme: _toggleTheme,
                onLockDetected: () {
                  setState(() => _isNoLockState = false);
                  _checkSecurityLockOnLaunch();
                },
              )
            else if (_isShieldActive)
              SecurityPrivacyShield(
                dark: dark,
                onToggleTheme: _toggleTheme,
                onUnlockPressed: _triggerSecurityAuthentication,
                isAuthenticating: _isAuthenticating,
              ),
          ],
        );
      },
      home: HomeScreen(
        dark: dark,
        initialLicenseRequired: widget.initialLicenseRequired,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
