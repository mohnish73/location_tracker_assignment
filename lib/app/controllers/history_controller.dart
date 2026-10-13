import 'package:get/get.dart';

import '../core/app_feedback.dart';
import '../data/channel_result.dart';
import '../data/models/location_record.dart';
import '../data/tracker_channel.dart';
import 'tracking_controller.dart';

/// Last [pageSize] stored fixes, newest first, read from Kotlin through the MethodChannel.
/// New live fixes are prepended reactively so the list stays current without a refresh.
class HistoryController extends GetxController {
  HistoryController(this._channel, this._tracking);

  static const pageSize = 50;

  final TrackerChannel _channel;
  final TrackingController _tracking;

  final records = <LocationRecord>[].obs;
  final totalCount = 0.obs;
  final isLoading = false.obs;
  final isExporting = false.obs;

  Worker? _liveWorker;

  @override
  void onInit() {
    super.onInit();
    _liveWorker = ever<LocationRecord?>(_tracking.lastLocation, _onLatest);
    load();
  }

  @override
  void onClose() {
    _liveWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    // Both calls are in flight at the same time.
    final historyFuture = _channel.getHistory(limit: pageSize);
    final countFuture = _channel.getRecordCount();
    final history = await historyFuture;
    final count = await countFuture;
    isLoading.value = false;

    switch (history) {
      case ChannelSuccess(:final data):
        records.assignAll(data);
      case ChannelFailure(:final error):
        AppFeedback.nativeError(error, title: 'Could not load history');
    }
    if (count case ChannelSuccess(:final data)) totalCount.value = data;
  }

  Future<void> clearHistory() async {
    final confirmed = await AppFeedback.confirm(
      title: 'Clear history?',
      message: 'This permanently deletes all ${totalCount.value} stored locations.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;

    final result = await _channel.clearHistory();
    switch (result) {
      case ChannelSuccess(:final data):
        records.clear();
        totalCount.value = 0;
        _tracking.lastLocation.value = null;
        AppFeedback.success('History cleared', '$data records deleted.');
      case ChannelFailure(:final error):
        AppFeedback.nativeError(error);
    }
  }

  Future<void> exportCsv() async {
    if (isExporting.value) return;
    isExporting.value = true;
    final result = await _channel.exportCsv();
    isExporting.value = false;
    if (result case ChannelFailure(:final error)) AppFeedback.nativeError(error);
  }

  void _onLatest(LocationRecord? record) {
    if (record == null) return;
    final newest = records.isEmpty ? null : records.first;
    if (newest != null && record.id <= newest.id) return; // already shown

    if (newest == null || record.id == newest.id + 1) {
      records.insert(0, record);
      if (records.length > pageSize) records.removeLast();
      totalCount.value++;
    } else {
      // Fixes were stored while the UI wasn't listening: reload to fill the gap.
      load();
    }
  }
}
