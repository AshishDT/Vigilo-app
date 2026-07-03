import 'package:flutter/material.dart';

class ERCNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const ERCNotice({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF10263D) : const Color(0xFFEBF4FF);
    final borderColor = isDark
        ? const Color(0xFF4B86F8)
        : const Color(0xFF93C5FD);
    final iconColor = isDark
        ? const Color(0xFF8FD4FF)
        : const Color(0xFF2563EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? const Color(0xFFB6C7D8)
        : const Color(0xFF475569);

    final sanitizedTitle = _sanitizeText(title);
    final sanitizedSubtitle = subtitle != null ? _sanitizeText(subtitle!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sanitizedTitle,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (sanitizedSubtitle != null && sanitizedSubtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sanitizedSubtitle,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sanitizeText(String text) {
    if (text.isEmpty) return text;

    // 1. Sanitize "persist" terms (case-insensitive)
    String sanitized = text
        .replaceAll(RegExp(r'\bpersisted\b', caseSensitive: false), 'saved')
        .replaceAll(RegExp(r'\bpersists\b', caseSensitive: false), 'saves')
        .replaceAll(RegExp(r'\bpersisting\b', caseSensitive: false), 'saving')
        .replaceAll(RegExp(r'\bpersist\b', caseSensitive: false), 'save')
        .replaceAll(RegExp(r'\bpersistence\b', caseSensitive: false), 'storage');

    // 2. Sanitize file paths
    final pathRegex = RegExp(r'(?:[a-zA-Z]:)?(?:[\\/][a-zA-Z0-9_\.\-]+){2,}');
    sanitized = sanitized.replaceAllMapped(pathRegex, (match) {
      final path = match.group(0)!;
      final parts = path.split(RegExp(r'[/\\]'));
      final filename = parts.last;
      return filename.isNotEmpty ? filename : 'file';
    });

    // 3. Sanitize Exception / Error messages
    sanitized = sanitized.replaceAll(
      RegExp(r'\b(?:Exception|Error)\b:\s*', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b(?:SqliteException|PlatformException|DatabaseException)\b:?\s*', caseSensitive: false),
      '',
    );

    final technicalKeywords = [
      'constraint failed',
      'no such table',
      'sqlite',
      'null pointer',
      'nullpointer',
      'index out of range',
      'out of bounds',
      'bad state',
      'unhandled exception',
      'stack trace',
      'nosuchmethod',
    ];

    for (final keyword in technicalKeywords) {
      if (sanitized.toLowerCase().contains(keyword)) {
        return "An unexpected error occurred";
      }
    }

    return sanitized;
  }
}

