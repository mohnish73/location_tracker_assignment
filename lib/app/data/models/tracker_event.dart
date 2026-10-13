import 'location_record.dart';

/// Typed view of the maps pushed by Kotlin on the EventChannel.
sealed class TrackerEvent {
  const TrackerEvent();

  /// Returns null for unknown or malformed events so one bad event never breaks the stream.
  static TrackerEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    try {
      return switch (map['type']) {
        'location' => LocationFixEvent(LocationRecord.fromMap(map)),
        'status' => ServiceStatusEvent(isRunning: map['isRunning'] == true),
        'locationServices' => LocationServicesEvent(enabled: map['enabled'] == true),
        _ => null,
      };
    } on TypeError {
      return null;
    }
  }
}

/// A new fix that the service has already written to SQLite.
final class LocationFixEvent extends TrackerEvent {
  const LocationFixEvent(this.record);
  final LocationRecord record;
}

/// The foreground service started or stopped (including "Stop" from the notification).
final class ServiceStatusEvent extends TrackerEvent {
  const ServiceStatusEvent({required this.isRunning});
  final bool isRunning;
}

/// The device location switch changed while tracking.
final class LocationServicesEvent extends TrackerEvent {
  const LocationServicesEvent({required this.enabled});
  final bool enabled;
}
