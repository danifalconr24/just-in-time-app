/// Geographic coordinate pair.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LatLng.fromJson(Map<String, dynamic> json) => LatLng(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A trip the user wants to monitor.
class Trip {
  final String originName;
  final LatLng originLatLng;
  final String destinationName;
  final LatLng destinationLatLng;
  final DateTime targetArrivalTime;

  const Trip({
    required this.originName,
    required this.originLatLng,
    required this.destinationName,
    required this.destinationLatLng,
    required this.targetArrivalTime,
  });

  Map<String, dynamic> toJson() => {
    'originName': originName,
    'originLatLng': originLatLng.toJson(),
    'destinationName': destinationName,
    'destinationLatLng': destinationLatLng.toJson(),
    'targetArrivalTime': targetArrivalTime.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    originName: json['originName'] as String,
    originLatLng: LatLng.fromJson(json['originLatLng'] as Map<String, dynamic>),
    destinationName: json['destinationName'] as String,
    destinationLatLng: LatLng.fromJson(
      json['destinationLatLng'] as Map<String, dynamic>,
    ),
    targetArrivalTime: DateTime.parse(json['targetArrivalTime'] as String),
  );

  @override
  String toString() =>
      'Trip($originName -> $destinationName '
      'by ${targetArrivalTime.toIso8601String()})';
}
