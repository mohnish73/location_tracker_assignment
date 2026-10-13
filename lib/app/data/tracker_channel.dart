import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'channel_result.dart';
import 'models/location_record.dart';
import 'models/permission_snapshot.dart';
import 'models/tracker_event.dart';
import 'models/tracking_status.dart';

/// Method names of the MethodChannel. Mirrors `ChannelContract.Methods` in Kotlin.
abstract final class TrackerMethods {
  static const startTracking = 'startTracking';
  static const stopTracking = 'stopTracking';
  static const getTrackingStatus = 'getTrackingStatus';
  static const setTrackingInterval = 'setTrackingInterval';
  static const getLastLocation = 'getLastLocation';
  static const getHistory = 'getHistory';
  static const getRecordCount = 'getRecordCount';
  static const clearHistory = 'clearHistory';
  static const exportCsv = 'exportCsv';
  static const getPermissionStatus = 'getPermissionStatus';
  static const requestLocationPermission = 'requestLocationPermission';
  static const requestBackgroundLocationPermission = 'requestBackgroundLocationPermission';
  static const requestNotificationPermission = 'requestNotificationPermission';
  static const requestIgnoreBatteryOptimizations = 'requestIgnoreBatteryOptimizations';
  static const openAppSettings = 'openAppSettings';
  static const openLocationSettings = 'openLocationSettings';
}

/// The only way Flutter talks to Android: one MethodChannel for commands and
/// one EventChannel for live events. Flutter never opens the database itself.
class TrackerChannel extends GetxService {
  TrackerChannel({MethodChannel? methodChannel, EventChannel? eventChannel})
      : _methodChannel = methodChannel ?? const MethodChannel(methodChannelName),
        _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  static const methodChannelName = 'com.example.assignmentproject/tracker';
  static const eventChannelName = 'com.example.assignmentproject/location_stream';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  /// Broadcast stream of live events. Kotlin starts emitting when the first listener subscribes.
  late final Stream<TrackerEvent> events = _eventChannel
      .receiveBroadcastStream()
      .map(TrackerEvent.tryParse)
      .where((event) => event != null)
      .cast<TrackerEvent>();

  // Tracking ---------------------------------------------------------------

  Future<ChannelResult<TrackingStatus>> startTracking() =>
      _invoke(TrackerMethods.startTracking, _parseStatus);

  Future<ChannelResult<TrackingStatus>> stopTracking() =>
      _invoke(TrackerMethods.stopTracking, _parseStatus);

  Future<ChannelResult<TrackingStatus>> getTrackingStatus() =>
      _invoke(TrackerMethods.getTrackingStatus, _parseStatus);

  Future<ChannelResult<TrackingStatus>> setTrackingInterval(Duration interval) => _invoke(
        TrackerMethods.setTrackingInterval,
        _parseStatus,
        {'intervalMs': interval.inMilliseconds},
      );

  // Database ---------------------------------------------------------------

  Future<ChannelResult<LocationRecord?>> getLastLocation() => _invoke(
        TrackerMethods.getLastLocation,
        (raw) => raw == null ? null : LocationRecord.fromMap(_asMap(raw)),
      );

  /// Newest first.
  Future<ChannelResult<List<LocationRecord>>> getHistory({int limit = 50}) => _invoke(
        TrackerMethods.getHistory,
        (raw) => (raw as List).map((item) => LocationRecord.fromMap(_asMap(item))).toList(),
        {'limit': limit},
      );

  Future<ChannelResult<int>> getRecordCount() =>
      _invoke(TrackerMethods.getRecordCount, (raw) => (raw as num).toInt());

  /// Returns the number of deleted rows.
  Future<ChannelResult<int>> clearHistory() =>
      _invoke(TrackerMethods.clearHistory, (raw) => (raw as num).toInt());

  /// Writes a CSV natively and opens the Android share sheet. Returns the row count.
  Future<ChannelResult<int>> exportCsv() =>
      _invoke(TrackerMethods.exportCsv, (raw) => (_asMap(raw)['rows'] as num).toInt());

  // Permissions & settings -------------------------------------------------

  Future<ChannelResult<PermissionSnapshot>> getPermissionStatus() =>
      _invoke(TrackerMethods.getPermissionStatus, _parsePermissions);

  Future<ChannelResult<PermissionSnapshot>> requestLocationPermission() =>
      _invoke(TrackerMethods.requestLocationPermission, _parsePermissions);

  Future<ChannelResult<PermissionSnapshot>> requestBackgroundLocationPermission() =>
      _invoke(TrackerMethods.requestBackgroundLocationPermission, _parsePermissions);

  Future<ChannelResult<PermissionSnapshot>> requestNotificationPermission() =>
      _invoke(TrackerMethods.requestNotificationPermission, _parsePermissions);

  Future<ChannelResult<bool>> requestIgnoreBatteryOptimizations() =>
      _invoke(TrackerMethods.requestIgnoreBatteryOptimizations, (raw) => raw == true);

  Future<ChannelResult<bool>> openAppSettings() =>
      _invoke(TrackerMethods.openAppSettings, (raw) => raw == true);

  Future<ChannelResult<bool>> openLocationSettings() =>
      _invoke(TrackerMethods.openLocationSettings, (raw) => raw == true);

  // Plumbing ---------------------------------------------------------------

  /// Invokes [method] and converts every outcome into a [ChannelResult].
  Future<ChannelResult<T>> _invoke<T>(
    String method,
    T Function(Object? raw) parse, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final raw = await _methodChannel.invokeMethod<Object?>(method, arguments);
      return ChannelSuccess(parse(raw));
    } on PlatformException catch (e) {
      return ChannelFailure(NativeError(
        code: e.code,
        message: e.message ?? 'Unknown native error',
        details: e.details,
      ));
    } on MissingPluginException {
      return ChannelFailure(NativeError(
        code: NativeErrorCode.notImplemented,
        message: 'Native method "$method" is not available on this platform.',
      ));
    } on TypeError catch (e) {
      return ChannelFailure(NativeError(
        code: NativeErrorCode.invalidResponse,
        message: 'Unexpected response from "$method".',
        details: e.toString(),
      ));
    }
  }

  static Map<String, Object?> _asMap(Object? raw) => Map<String, Object?>.from(raw as Map);

  static TrackingStatus _parseStatus(Object? raw) => TrackingStatus.fromMap(_asMap(raw));

  static PermissionSnapshot _parsePermissions(Object? raw) => PermissionSnapshot.fromMap(_asMap(raw));
}
