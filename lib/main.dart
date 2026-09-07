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
  static const MethodChannel _screenEventsChannel =
      MethodChannel('com.vigilo.vigilo/screen_events');

  bool dark = true;
  bool _isNoLockState = false;
  bool _isShieldActive = false;
  bool _isAuthenticating = false;
  bool _requiresAuthentication = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screenEventsChannel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenOff') {
        _handleScreenOff();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _checkSecurityLockOnLaunch();
    });
  }

  @override
  void dispose() {
    _screenEventsChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleScreenOff() {
    SecurityService().recordPause();
    // When the physical screen powers down / locks, pre-render the privacy shield
    // into the GPU surface buffer before the display turns off completely.
    if (!SecurityService().isAuthenticating && !_isNoLockState) {
      if (mounted && !_isShieldActive) {
        setState(() {
          _isShieldActive = true;
        });
      }
    }
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
        });
      }
      return;
    }

    _requiresAuthentication = true;
    if (mounted) setState(() => _isShieldActive = true);
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
        });
      }
      return;
    }

    _requiresAuthentication = true;
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
      _requiresAuthentication = false;
      setState(() {
        _isShieldActive = false;
        _isAuthenticating = false;
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
