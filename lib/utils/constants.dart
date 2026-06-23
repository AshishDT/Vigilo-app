import 'dart:ui';

// ----- Theme palette -----
const kBlue = Color(0xFF4285F4); // Normal
const kAmber = Color(0xFFF59E0B); // Extra
const kGreen = Color(0xFF4CAF50);
const kFinished = Color(0xFF9CA3AF);
const kDarkBg = Color(0xFF0F1720);
const kDarkCard = Color(0xFF16212C);
const kLightBg = Color(0xFFF6F7F9);
const double kFabGuardInset = 56.0;

const int vibrate10Min = 10; //minutes before end time
const int vibrate5Min = 5; //minutes before end time

class VigiloUiColors {
  static Color bg(bool dark) => dark ? const Color(0xFF071A2B) : const Color(0xFFEAF1F8);
  static Color bg2(bool dark) => dark ? const Color(0xFF0C2238) : const Color(0xFFF7FAFD);
  static Color panel(bool dark) => dark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  static Color panel3(bool dark) => dark ? const Color(0xFF0F2236) : const Color(0xFFF1F6FB);
  static Color line(bool dark) => dark ? const Color(0xFF294867) : const Color(0xFFC9D8E8);
  static Color lineSoft(bool dark) => dark ? const Color(0xFF395B7D) : const Color(0xFFAFC3D8);

  static Color text(bool dark) => dark ? const Color(0xFFF3F7FC) : const Color(0xFF10263D);
  static Color textSoft(bool dark) => dark ? const Color(0xFFB6C7D8) : const Color(0xFF50677F);
  static Color textFaint(bool dark) => dark ? const Color(0xFF7E98B2) : const Color(0xFF8297AC);

  static Color blue(bool dark) => dark ? const Color(0xFF4B86F8) : const Color(0xFF256BDB);
  static Color blueSoft(bool dark) => dark ? const Color(0xFF8FD4FF) : const Color(0xFF3F86F5);
  static Color amber(bool dark) => dark ? const Color(0xFFFFB64D) : const Color(0xFFE59422);
  static Color finished(bool dark) => dark ? const Color(0xFF8FA6BE) : const Color(0xFF7C91A8);
  static Color green(bool dark) => dark ? const Color(0xFF5ED68A) : const Color(0xFF249B62);
}

