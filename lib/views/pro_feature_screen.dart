import 'package:flutter/material.dart';
import '../utils/constants.dart';

import '../services/license_service.dart';
import 'license_activation_screen.dart';

class ProFeatureScreen extends StatelessWidget {
  const ProFeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [VigiloUiColors.bg(true), VigiloUiColors.bg2(true)],
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
                  color: VigiloUiColors.panel(true).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: VigiloUiColors.line(true)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: VigiloUiColors.text(true),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vigilo ERC',
                            style: TextStyle(
                              color: VigiloUiColors.text(true),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Messages',
                            style: TextStyle(
                              color: VigiloUiColors.textSoft(true),
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
                          color: VigiloUiColors.panel(true).withValues(alpha: 0.98),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: VigiloUiColors.line(true)),
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
                                color: VigiloUiColors.amber(true).withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: VigiloUiColors.amber(true).withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.military_tech,
                                color: VigiloUiColors.amber(true),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Pro Feature',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VigiloUiColors.text(true),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Messaging is available with Vigilo ERC Pro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VigiloUiColors.text(true),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Upgrade to Pro to enable exam team messaging, Officer Tools quick messages, photo / PDF sharing and multi-device coordination.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VigiloUiColors.textSoft(true),
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: VigiloUiColors.panel3(true),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: VigiloUiColors.lineSoft(true)),
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
                                  backgroundColor: VigiloUiColors.blue(true),
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
                                  foregroundColor: VigiloUiColors.text(true),
                                  side: BorderSide(
                                    color: VigiloUiColors.line(true),
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
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 7, color: VigiloUiColors.blueSoft(true)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: VigiloUiColors.text(true),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


