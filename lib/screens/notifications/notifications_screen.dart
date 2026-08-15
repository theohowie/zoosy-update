import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';

class NotificationsScreen extends StatelessWidget {
  final List<NotificationItem> notifications;

  const NotificationsScreen({Key? key, required this.notifications}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.messages_and_notifications,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.bold,
          ),
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: notifications.isEmpty
          ? Center(
              child: Text(
                context.l10n.no_notifications,
                style: TextStyle(color: ZoosyTheme.textMutedOf(context)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              itemCount: notifications.length,
              itemBuilder: (context, idx) {
                final notif = notifications[idx];
                Color badgeColor = ZoosyTheme.primary;
                if (notif.type == 'reminder') {
                  badgeColor = const Color(0xFF62626D);
                } else if (notif.type == 'milestone') {
                  badgeColor = const Color(0xFFBA1A1A);
                }

                return Card(
                  color: ZoosyTheme.surfaceOf(context),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.25)),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(notif.icon, color: badgeColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: ZoosyTheme.textDarkOf(context),
                                    ),
                                  ),
                                  Text(
                                    notif.time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ZoosyTheme.textMutedOf(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.content,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: ZoosyTheme.textMutedOf(context),
                                  height: 1.4,
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
