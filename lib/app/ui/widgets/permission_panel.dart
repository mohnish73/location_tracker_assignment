import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/permission_controller.dart';
import '../../data/models/permission_snapshot.dart';

/// Step-by-step permission checklist. Hidden once everything is granted.
class PermissionPanel extends GetView<PermissionController> {
  const PermissionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = controller.snapshot.value;
      if (s == null || s.allGood) return const SizedBox.shrink();
      final busy = controller.isRequesting.value;
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Setup', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Complete these steps so tracking keeps running in the background.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 24),
              if (!s.locationServicesEnabled)
                _PermissionRow(
                  icon: Icons.location_disabled,
                  title: 'Location services are off',
                  subtitle: 'Turn on device location to receive fixes.',
                  satisfied: false,
                  actionLabel: 'Turn on',
                  onAction: controller.openLocationSettings,
                ),
              _PermissionRow(
                icon: Icons.my_location,
                title: '1. Precise location',
                subtitle: _subtitle(s.location, 'Required to record your position.'),
                satisfied: s.location.isSatisfied,
                actionLabel: _label(s.location),
                onAction: busy
                    ? null
                    : s.location == PermissionState.permanentlyDenied
                        ? controller.openAppSettings
                        : controller.requestLocation,
              ),
              if (s.backgroundLocation != PermissionState.notRequired)
                _PermissionRow(
                  icon: Icons.share_location,
                  title: '2. Background location ("Allow all the time")',
                  subtitle: _subtitle(
                    s.backgroundLocation,
                    'Lets tracking continue after the app is closed and restart after reboot.',
                  ),
                  satisfied: s.backgroundLocation.isSatisfied,
                  actionLabel: _label(s.backgroundLocation),
                  onAction: busy || !s.location.isSatisfied
                      ? null
                      : s.backgroundLocation == PermissionState.permanentlyDenied
                          ? controller.openAppSettings
                          : () => controller.promptBackgroundLocation(force: true),
                ),
              if (s.notification != PermissionState.notRequired)
                _PermissionRow(
                  icon: Icons.notifications_active_outlined,
                  title: '3. Notifications',
                  subtitle: _subtitle(s.notification, 'Shows the live location notification.'),
                  satisfied: s.notification.isSatisfied,
                  actionLabel: _label(s.notification),
                  onAction: busy
                      ? null
                      : s.notification == PermissionState.permanentlyDenied
                          ? controller.openAppSettings
                          : () => controller.ensureNotificationPermission(force: true),
                ),
              _PermissionRow(
                icon: Icons.battery_saver_outlined,
                title: 'Battery optimisation (recommended)',
                subtitle: 'Stops Android and OEM battery savers from killing the tracker.',
                satisfied: s.ignoringBatteryOptimizations,
                actionLabel: 'Allow',
                onAction: controller.requestBatteryExemption,
              ),
            ],
          ),
        ),
      );
    });
  }

  static String _subtitle(PermissionState state, String why) => switch (state) {
        PermissionState.permanentlyDenied => 'Denied. Open Settings to grant it. $why',
        PermissionState.denied => why,
        _ => 'Granted',
      };

  static String _label(PermissionState state) =>
      state == PermissionState.permanentlyDenied ? 'Open Settings' : 'Grant';
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.satisfied,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool satisfied;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(satisfied ? Icons.check_circle : icon, color: satisfied ? Colors.green : colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (!satisfied) ...[
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
