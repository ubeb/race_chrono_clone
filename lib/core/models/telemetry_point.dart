class TelemetryPoint {
  final int? id;
  final int timestamp;
  final double latitude;
  final double longitude;
  final double speed;

  TelemetryPoint({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
    };
  }

  factory TelemetryPoint.fromMap(Map<String, dynamic> map) {
    return TelemetryPoint(
      id: map['id'],
      timestamp: map['timestamp'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      speed: map['speed'],
    );
  }
}