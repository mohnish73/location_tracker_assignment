/// Service state as reported by Kotlin.
class TrackingStatus {
  const TrackingStatus({
    required this.isRunning,
    required this.trackingEnabled,
    required this.interval,
  });

  factory TrackingStatus.fromMap(Map<String, Object?> map) => TrackingStatus(
        isRunning: map['isRunning'] == true,
        trackingEnabled: map['trackingEnabled'] == true,
        interval: Duration(milliseconds: (map['intervalMs'] as num).toInt()),
      );

  /// The foreground service is alive right now.
  final bool isRunning;

  /// The user's persisted choice. True while [isRunning] is false means the
  /// service was killed (e.g. by an OEM battery manager) and should be resumed.
  final bool trackingEnabled;

  final Duration interval;
}
