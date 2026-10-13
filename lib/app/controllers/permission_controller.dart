import 'package:get/get.dart';

import '../core/app_feedback.dart';
import '../data/channel_result.dart';
import '../data/models/permission_snapshot.dart';
import '../data/tracker_channel.dart';

/// Drives the runtime-permission flow:
/// 1. ACCESS_FINE_LOCATION, 2. ACCESS_BACKGROUND_LOCATION (separate step, Android 10+),
/// 3. POST_NOTIFICATIONS (Android 13+). Denied states always offer a way to Settings.
class PermissionController extends GetxController {
  PermissionController(this._channel);

  final TrackerChannel _channel;

  final snapshot = Rxn<PermissionSnapshot>();
  final isRequesting = false.obs;

  /// Show the "Allow all the time" explanation automatically only once per app session.
  bool _backgroundPromptShown = false;
  bool _notificationPromptShown = false;

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<PermissionSnapshot?> refreshStatus() async {
    final result = await _channel.getPermissionStatus();
    switch (result) {
      case ChannelSuccess(:final data):
        snapshot.value = data;
        return data;
      case ChannelFailure(:final error):
        AppFeedback.nativeError(error);
        return null;
    }
  }

  /// Called from the EventChannel when the device location switch changes.
  void updateLocationServices(bool enabled) {
    final current = snapshot.value;
    if (current != null) snapshot.value = current.copyWith(locationServicesEnabled: enabled);
  }

  // Step 1: foreground location --------------------------------------------

  /// Makes sure precise location is granted, asking if possible. Returns true when granted.
  Future<bool> ensureLocationPermission() async {
    final current = snapshot.value ?? await refreshStatus();
    if (current == null) return false;
    if (current.location.isSatisfied) return true;

    if (current.location == PermissionState.permanentlyDenied) {
      _showDenied(
        'Location permission denied',
        'Location access is blocked. Open Settings > Permissions > Location and choose "Allow".',
      );
      return false;
    }

    final updated = await requestLocation();
    if (updated?.location.isSatisfied ?? false) return true;
    _showDenied(
      'Location permission needed',
      'Tracking needs precise location access. You can grant it in Settings.',
    );
    return false;
  }

  Future<PermissionSnapshot?> requestLocation() => _request(_channel.requestLocationPermission);

  // Step 2: background location --------------------------------------------

  /// Explains why "Allow all the time" is needed, then opens the system request.
  /// [force] shows the explanation again even if it was already shown this session.
  Future<void> promptBackgroundLocation({bool force = false}) async {
    final current = snapshot.value;
    if (current == null || !current.location.isSatisfied || current.backgroundLocation.isSatisfied) {
      return;
    }
    if (current.backgroundLocation == PermissionState.permanentlyDenied) {
      if (force) {
        _showDenied(
          'Background location denied',
          'Open Settings > Permissions > Location and choose "Allow all the time".',
        );
      }
      return;
    }
    if (_backgroundPromptShown && !force) return;
    _backgroundPromptShown = true;

    final proceed = await AppFeedback.confirm(
      title: 'Allow background location',
      message: 'To keep recording your location after the app is closed or the phone restarts, '
          'choose "Allow all the time" on the next screen.',
      confirmLabel: 'Continue',
      cancelLabel: 'Not now',
    );
    if (!proceed) return;

    final updated = await _request(_channel.requestBackgroundLocationPermission);
    if (updated != null && !updated.backgroundLocation.isSatisfied) {
      _showDenied(
        'Background location not allowed',
        'Tracking works while the service is running, but it cannot restart '
            'by itself after the app is killed or the phone reboots.',
      );
    }
  }

  // Step 3: notifications --------------------------------------------------

  /// Asks for POST_NOTIFICATIONS once per session; the service runs without it,
  /// but the user would not see the live notification.
  Future<void> ensureNotificationPermission({bool force = false}) async {
    final current = snapshot.value;
    if (current == null || current.notification.isSatisfied) return;
    if (current.notification == PermissionState.permanentlyDenied) {
      if (force) {
        _showDenied('Notifications blocked', 'Enable notifications in Settings to see live tracking updates.');
      }
      return;
    }
    if (_notificationPromptShown && !force) return;
    _notificationPromptShown = true;
    await _request(_channel.requestNotificationPermission);
  }

  // Settings shortcuts -----------------------------------------------------

  Future<void> requestBatteryExemption() async {
    final result = await _channel.requestIgnoreBatteryOptimizations();
    if (result case ChannelFailure(:final error)) AppFeedback.nativeError(error);
  }

  Future<void> openAppSettings() async {
    final result = await _channel.openAppSettings();
    if (result case ChannelFailure(:final error)) AppFeedback.nativeError(error);
  }

  Future<void> openLocationSettings() async {
    final result = await _channel.openLocationSettings();
    if (result case ChannelFailure(:final error)) AppFeedback.nativeError(error);
  }

  /// GPS-off prompt shown when the user tries to start tracking with location services off.
  Future<void> promptEnableLocationServices() async {
    final open = await AppFeedback.confirm(
      title: 'Turn on location',
      message: 'Location services are off. Turn them on to start tracking.',
      confirmLabel: 'Open settings',
    );
    if (open) await openLocationSettings();
  }

  // Internals --------------------------------------------------------------

  Future<PermissionSnapshot?> _request(
    Future<ChannelResult<PermissionSnapshot>> Function() call,
  ) async {
    if (isRequesting.value) return snapshot.value;
    isRequesting.value = true;
    try {
      final result = await call();
      switch (result) {
        case ChannelSuccess(:final data):
          snapshot.value = data;
          return data;
        case ChannelFailure(:final error):
          AppFeedback.nativeError(error);
          return null;
      }
    } finally {
      isRequesting.value = false;
    }
  }

  void _showDenied(String title, String message) =>
      AppFeedback.error(title, message, actionLabel: 'Open Settings', onAction: openAppSettings);
}
