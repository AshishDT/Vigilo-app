import 'package:flutter/material.dart';

import '../services/license_service.dart';
import 'license_activation_screen.dart';

class ProFeatureScreen extends StatelessWidget {
  const ProFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_ProPalette.bg, _ProPalette.bg2],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _ProPalette.panel.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _ProPalette.line),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _ProPalette.text,
                    ),
                    const SizedBox(width: 2),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vigilo ERC',
                            style: TextStyle(
                              color: _ProPalette.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Messages',
                            style: TextStyle(
                              color: _ProPalette.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _ProPalette.panel.withValues(alpha: 0.98),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _ProPalette.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: _ProPalette.amber.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _ProPalette.amber.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.military_tech,
                                color: _ProPalette.amber,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Pro Feature',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ProPalette.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Messaging is available with Vigilo ERC Pro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ProPalette.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Upgrade to Pro to enable exam team messaging, Officer Tools quick messages, photo / PDF sharing and multi-device coordination.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ProPalette.textSoft,
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _ProPalette.panel2,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _ProPalette.lineSoft),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: LicenseService.proFeatureAdditions
                                    .map(_ProBulletLine.new)
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ProPalette.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const LicenseActivationScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'View Pro Licence',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ProPalette.text,
                                  side: const BorderSide(
                                    color: _ProPalette.line,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                child: const Text(
                                  'Back',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _ProBulletLine extends StatelessWidget {
  const _ProBulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 7, color: _ProPalette.blueSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _ProPalette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProPalette {
  static const Color bg = Color(0xFF081A2B);
  static const Color bg2 = Color(0xFF0D2236);
  static const Color panel = Color(0xFF10263D);
  static const Color panel2 = Color(0xFF16314D);
  static const Color line = Color(0xFF284867);
  static const Color lineSoft = Color(0xFF395B7D);

  static const Color blue = Color(0xFF2EA7FF);
  static const Color blueSoft = Color(0xFF8FD4FF);
  static const Color amber = Color(0xFFFFC857);

  static const Color text = Color(0xFFF3F7FC);
  static const Color textSoft = Color(0xFFB6C7D8);
}
