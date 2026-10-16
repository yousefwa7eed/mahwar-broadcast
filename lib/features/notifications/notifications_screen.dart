import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/services/server_clock.dart';
import '../../l10n/app_localizations.dart';
import 'notification_actions.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationCubit>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n?.notifications ?? 'الإشعارات',
          style: TextStyle(
            fontFamily: 'Zain',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          BlocBuilder<NotificationCubit, NotificationsState>(
            builder: (context, state) {
              final hasUnread = state.unreadCount > 0;
              return IconButton(
                tooltip: l10n?.markAllRead ?? 'تعيين الكل كمقروء',
                onPressed: hasUnread
                    ? () => context.read<NotificationCubit>().markAllAsRead()
                    : null,
                icon: Icon(
                  Icons.mark_email_read_outlined,
                  color: hasUnread
                      ? AppColors.orangePrimary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  size: 26,
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.orangePrimary),
            );
          }

          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<NotificationCubit>().loadNotifications(),
                    child: Text(l10n?.retry ?? 'إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (state.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.noNotifications ?? 'لا توجد إشعارات',
                    style: TextStyle(
                      fontFamily: 'Zain',
                      fontSize: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<NotificationCubit>().loadNotifications(),
            color: AppColors.orangePrimary,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                final title = notification.localizedTitle(l10n);
                final body = notification.localizedBody(l10n);
                return GestureDetector(
                  // معالج موحّد مع تبويبي الرئيسية: deep link خارجي / home /
                  // طلب / إشعار عام (شاشة التفاصيل).
                  onTap: () => openNotificationFromList(context, notification),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: notification.isRead
                              ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                              : notification.color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (notification.imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                notification.imageUrl!,
                                height: 160,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 160,
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.orangePrimary,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: notification.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              notification.icon,
                              color: notification.color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Zain',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  notification.timeAgo(ServerClock.instance.now, l10n),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: notification.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          ),
                        ],
                      ),
                    ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
