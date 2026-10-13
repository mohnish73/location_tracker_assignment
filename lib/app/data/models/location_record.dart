/// One location fix as stored by the native SQLite layer.
class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  factory LocationRecord.fromMap(Map<String, Object?> map) => LocationRecord(
        id: (map['id'] as num).toInt(),
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num).toDouble(),
        timestamp: (map['timestamp'] as num).toInt(),
      );

  final int id;
  final double latitude;
  final double longitude;

  /// Horizontal accuracy radius in metres.
  final double accuracy;

  /// Epoch milliseconds.
  final int timestamp;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  bool operator ==(Object other) =>
      other is LocationRecord &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracy == accuracy &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, accuracy, timestamp);
}
