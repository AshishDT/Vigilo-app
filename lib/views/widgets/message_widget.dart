import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../utils/constants.dart';

class MessageWidget extends StatelessWidget {
  final Message message;

  const MessageWidget({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isMe ? kBlue : kDarkCard;
    final textColor = Colors.white;

    return Column(
      crossAxisAlignment: message.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(message.message.substring(3).split(': ')[0]),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: message.isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: message.isMe
                        ? Radius.circular(12)
                        : Radius.circular(0),
                    bottomRight: message.isMe
                        ? Radius.circular(0)
                        : Radius.circular(12),
                  ),
                ),
                child: Text(
                  message.message.split(': ')[1],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _hhmm(message.time),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white54
                : Colors.black87,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}
