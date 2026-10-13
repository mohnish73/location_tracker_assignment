import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tracking_controller.dart';
import '../../core/formatters.dart';

/// Latest fix: loaded from SQLite on launch, then replaced live by EventChannel events.
class LastLocationCard extends GetView<TrackingController> {
  const LastLocationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final record = controller.lastLocation.value;
          final live = controller.liveFixCount.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Last location', style: text.titleMedium),
                  const Spacer(),
                  if (live > 0)
                    Text('$live live update${live == 1 ? '' : 's'}',
                        style: text.labelSmall?.copyWith(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 12),
              if (controller.isLoading.value)
                const Center(child: CircularProgressIndicator())
              else if (record == null)
                Text('No location stored yet. Start tracking to record your first fix.', style: text.bodyMedium)
              else ...[
                _Field(label: 'Latitude', value: formatCoordinate(record.latitude)),
                _Field(label: 'Longitude', value: formatCoordinate(record.longitude)),
                _Field(label: 'Accuracy', value: formatAccuracy(record.accuracy)),
                _Field(label: 'Time', value: formatTimestamp(record.timestamp)),
                _Field(label: 'Record #', value: '${record.id}'),
              ],
            ],
          );
        }),
      ),
    );
  }
}



class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: text.bodyMedium?.copyWith(color: Colors.grey))),
          Expanded(
            child: Text(value, style: text.bodyLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ],
      ),
    );
  }
}
