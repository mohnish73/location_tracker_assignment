enum PermissionState {
  granted,
  denied,

  /// The system will no longer show the dialog; only Settings can grant it.
  permanentlyDenied,

  /// Not applicable on this Android version (e.g. notifications below 13).
  notRequired;

  static PermissionState parse(Object? raw) => switch (raw) {
        'granted' => granted,
        'permanentlyDenied' => permanentlyDenied,
        'notRequired' => notRequired,
        _ => denied,
      };

  bool get isSatisfied => this == granted || this == notRequired;
}

/// Everything the UI needs to drive the permission flow, fetched from Kotlin in one call.
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.location,
    required this.backgroundLocation,
    required this.notification,
    required this.locationServicesEnabled,
    required this.ignoringBatteryOptimizations,
    required this.sdkInt,
  });

  factory PermissionSnapshot.fromMap(Map<String, Object?> map) => PermissionSnapshot(
        location: PermissionState.parse(map['location']),
        backgroundLocation: PermissionState.parse(map['backgroundLocation']),
        notification: PermissionState.parse(map['notification']),
        locationServicesEnabled: map['locationServicesEnabled'] == true,
        ignoringBatteryOptimizations: map['ignoringBatteryOptimizations'] == true,
        sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      );

  final PermissionState location;
  final PermissionState backgroundLocation;
  final PermissionState notification;
  final bool locationServicesEnabled;
  final bool ignoringBatteryOptimizations;
  final int sdkInt;

  bool get allGood =>
      location.isSatisfied &&
      backgroundLocation.isSatisfied &&
      notification.isSatisfied &&
      locationServicesEnabled &&
      ignoringBatteryOptimizations;

  PermissionSnapshot copyWith({bool? locationServicesEnabled}) => PermissionSnapshot(
        location: location,
        backgroundLocation: backgroundLocation,
        notification: notification,
        locationServicesEnabled: locationServicesEnabled ?? this.locationServicesEnabled,
        ignoringBatteryOptimizations: ignoringBatteryOptimizations,
        sdkInt: sdkInt,
      );
}
