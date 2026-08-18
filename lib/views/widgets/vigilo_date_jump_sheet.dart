import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/safe_navigator.dart';

class VigiloDateJumpSheet extends StatelessWidget {
  final bool dark;
  final Map<String, int> dateSessionCounts;

  const VigiloDateJumpSheet({
    super.key,
    required this.dark,
    required this.dateSessionCounts,
  });

  String _fd(String date) {
    try {
      final p = date.split('/');
      if (p.length == 3) {
        final d = int.parse(p[0]);
        final m = int.parse(p[1]);
        final y = int.parse(p[2]);
        final dt = DateTime(y, m, d);
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final weekday = days[dt.weekday - 1];
        final monthStr = months[m];
        return '$weekday, $d $monthStr $y';
      }
    } catch (_) {}
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final dates = dateSessionCounts.keys.toList();
    final hasDates = dates.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: hasDates ? 0.6 : 0.22,
      minChildSize: 0.22,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: VigiloUiColors.panel(dark).withValues(alpha: 0.995),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: VigiloUiColors.lineSoft(dark).withValues(alpha: 0.55),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Container(
                      width: 70,
                      height: 5,
                      decoration: BoxDecoration(
                        color: VigiloUiColors.lineSoft(dark),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 24,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jump to Date',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: VigiloUiColors.text(dark),
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Only dates with sessions are shown, so you can\'t land on an empty day.',
                                  style: TextStyle(
                                    color: VigiloUiColors.textSoft(dark),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.safePop(),
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: VigiloUiColors.panel2(dark),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: VigiloUiColors.line(dark),
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: VigiloUiColors.text(dark),
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: dates.isEmpty
                          ? SingleChildScrollView(
                              controller: scrollController,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'No dates to jump to. Current filters have no matches.',
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: VigiloUiColors.textSoft(dark),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: dates.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: VigiloUiColors.line(dark).withValues(alpha: 0.5),
                              ),
                              itemBuilder: (ctx, i) {
                                final date = dates[i];
                                final count = dateSessionCounts[date] ?? 0;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => context.safePop(date),
                                  leading: Icon(
                                    Icons.calendar_today_rounded,
                                    color: VigiloUiColors.blueSoft(dark),
                                    size: 18,
                                  ),
                                  title: Text(
                                    _fd(date),
                                    style: TextStyle(
                                      color: VigiloUiColors.text(dark),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Text(
                                    '$count session${count == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      color: VigiloUiColors.textFaint(dark),
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
