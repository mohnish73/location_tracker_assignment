import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/history_controller.dart';
import '../../core/formatters.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('History (${controller.totalCount.value})')),
        actions: [
          Obx(() => IconButton(
                tooltip: 'Export CSV',
                icon: const Icon(Icons.ios_share),
                onPressed: controller.isExporting.value || controller.records.isEmpty
                    ? null
                    : controller.exportCsv,
              )),
          Obx(() => IconButton(
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_outline),
                onPressed: controller.records.isEmpty ? null : controller.clearHistory,
              )),
        ],

      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: Obx(() {
          if (controller.isLoading.value && controller.records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.records.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 160),
                Icon(Icons.location_searching, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('No locations recorded yet.')),
              ],
            );
          }
          return ListView.separated(
            itemCount: controller.records.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == controller.records.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Showing the latest ${controller.records.length} of ${controller.totalCount.value} records, newest first.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final r = controller.records[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                title: Text('${formatCoordinate(r.latitude)}, ${formatCoordinate(r.longitude)}'),
                subtitle: Text('${formatTimestamp(r.timestamp)}  ·  ${formatAccuracy(r.accuracy)}'),
                trailing: Text('#${r.id}', style: Theme.of(context).textTheme.labelSmall),
              );
            },
          );
        }),
      ),
    );
  }
}
