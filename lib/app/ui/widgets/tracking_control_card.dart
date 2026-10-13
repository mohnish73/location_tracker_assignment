import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tracking_controller.dart';
import '../../core/formatters.dart';

/// Service status (Running / Stopped), interval picker and Start / Stop buttons.
class TrackingControlCard extends GetView<TrackingController> {
  const TrackingControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final running = controller.isRunning.value;
          final busy = controller.isBusy.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Service status', style: text.titleMedium),
                  const Spacer(),
                  _StatusChip(running: running),
                ],
              ),
              const SizedBox(height: 16),
              Text('Update interval', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in TrackingController.intervalOptions)
                    ChoiceChip(
                      label: Text(formatInterval(option)),
                      selected: controller.interval.value == option,
                      onSelected: (_) => controller.changeInterval(option),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: running || busy ? null : controller.startTracking,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Tracking'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !running || busy ? null : controller.stopTracking,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Tracking'),
                    ),
                  ),
                ],
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final color = running ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            running ? 'Running' : 'Stopped',
            style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
