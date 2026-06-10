import 'dart:io';

import 'package:flutter/material.dart';

import '../../enums/brief_type.dart';
import '../../models/briefing_model.dart';

class BriefingTile extends StatelessWidget {
  const BriefingTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.onOpen,
    required this.onDelete,
  });

  final BriefingItem item;
  final bool isDark;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tileBg = isDark ? const Color(0xFF1B2A45) : const Color(0xFFF7F9FD);

    return InkWell(
      onTap: onOpen,
      child: Stack(
        children: [
          item.type == BriefType.photo
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(File(item.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: tileBg,
                  ),
                ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.5),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              item.type == BriefType.pdf
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    )
                  : Container(),
              item.type == BriefType.pdf
                  ? Center(
                      child: Icon(
                        Icons.picture_as_pdf,
                        color: Colors.white70,
                        size: 40,
                      ),
                    )
                  : Container(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _pretty(item.createdAt!),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        Icons.delete,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _pretty(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }
}
