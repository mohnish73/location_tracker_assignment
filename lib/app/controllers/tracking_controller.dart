import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../core/app_feedback.dart';
import '../core/formatters.dart';
import '../data/channel_result.dart';
import '../data/models/location_record.dart';
import '../data/models/tracker_event.dart';
import '../data/models/tracking_status.dart';
import '../data/tracker_channel.dart';
import 'permission_controller.dart';

/// Owns tracking state for the home screen.
///
/// On start it reads the last stored fix from SQLite (via Kotlin), then listens to the
/// EventChannel so every new fix the service stores is reflected immediately. When the
/// app comes back to the foreground it re-reads SQLite to catch up on fixes recorded
/// while no Flutter engine was listening.
class TrackingController extends GetxController with WidgetsBindingObserver {
  TrackingController(this._channel, this._permissions);

  final TrackerChannel _channel;
  final PermissionController _permissions;

  static const intervalOptions = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  final lastLocation = Rxn<LocationRecord>();
  final isRunning = false.obs;
  final interval = intervalOptions.first.obs;
  final isLoading = true.obs;
  final isBusy = false.obs;

  /// Fixes received live over the EventChannel since this screen opened.
  final liveFixCount = 0.obs;

  StreamSubscription<TrackerEvent>? _eventsSubscription;
  bool _resumeAttempted = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _eventsSubscription = _channel.events.listen(
      _onEvent,
      onError: (Object error) => AppFeedback.error('Live updates interrupted', error.toString()),
    );
    loadInitialState();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventsSubscription?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshLastLocation();
      refreshStatus();
      _permissions.refreshStatus();
    }
  }

  Future<void> loadInitialState() async {
    isLoading.value = true;
    await Future.wait([refreshLastLocation(), refreshStatus()]);
    isLoading.value = false;
  }

  Future<void> refreshLastLocation() async {
    final result = await _channel.getLastLocation();
    switch (result) {
      case ChannelSuccess(:final data):
        lastLocation.value = data;
      case ChannelFailure(:final error):
        AppFeedback.nativeError(error);
    }
  }

  Future<void> refreshStatus() async {
    final result = await _channel.getTrackingStatus();
    switch (result) {
      case ChannelSuccess(:final data):
        _applyStatus(data);
        // Tracking was ON but the service is gone (killed by an aggressive OEM battery
        // manager): restart it now that the app is in the foreground again.
        if (data.trackingEnabled && !data.isRunning && !_resumeAttempted) {
          _resumeAttempted = true;
          await _resumeTracking();
        }
      case ChannelFailure(:final error):
        AppFeedback.nativeError(error);
    }
  }

  Future<void> startTracking() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      if (!await _permissions.ensureLocationPermission()) return;
      await _permissions.ensureNotificationPermission();
      await _permissions.promptBackgroundLocation();

      final result = await _channel.startTracking();
      switch (result) {
        case ChannelSuccess(:final data):
          _applyStatus(data);
          AppFeedback.success('Tracking started', 'Recording every ${formatInterval(interval.value)}.');
        case ChannelFailure(:final error) when error.code == NativeErrorCode.locationDisabled:
          _permissions.updateLocationServices(false);
          await _permissions.promptEnableLocationServices();
        case ChannelFailure(:final error) when error.code == NativeErrorCode.permissionDenied:
          AppFeedback.error('Permission required', error.message,
              actionLabel: 'Open Settings', onAction: _permissions.openAppSettings);
        case ChannelFailure(:final error):
          AppFeedback.nativeError(error);
      }
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> stopTracking() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final result = await _channel.stopTracking();
      switch (result) {
        case ChannelSuccess(:final data):
          _applyStatus(data);
          AppFeedback.success('Tracking stopped', 'No new locations will be recorded.');
        case ChannelFailure(:final error):
          AppFeedback.nativeError(error);
      }
    } finally {
      isBusy.value = false;
    }
  }

  /// Saved natively and applied to the running service immediately.
  Future<void> changeInterval(Duration value) async {
    if (value == interval.value) return;
    final previous = interval.value;
    interval.value = value; // optimistic, reverted on failure
    final result = await _channel.setTrackingInterval(value);
    switch (result) {
      case ChannelSuccess(:final data):
        _applyStatus(data);
      case ChannelFailure(:final error):
        interval.value = previous;
        AppFeedback.nativeError(error);
    }
  }

  Future<void> _resumeTracking() async {
    if (!(_permissions.snapshot.value?.location.isSatisfied ?? false)) return;
    final result = await _channel.startTracking();
    if (result case ChannelSuccess(:final data)) {
      _applyStatus(data);
      AppFeedback.success('Tracking resumed', 'The tracking service had been stopped by the system.');
    }
  }

  void _onEvent(TrackerEvent event) {
    switch (event) {
      case LocationFixEvent(:final record):
        lastLocation.value = record;
        liveFixCount.value++;
      case ServiceStatusEvent(isRunning: final running):
        isRunning.value = running;
      case LocationServicesEvent(:final enabled):
        _permissions.updateLocationServices(enabled);
    }
  }

  void _applyStatus(TrackingStatus status) {
    isRunning.value = status.isRunning;
    interval.value = status.interval;
  }
}
