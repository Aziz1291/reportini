class Municipality {
  const Municipality(
    this.id,
    this.name,
    this.centerLat,
    this.centerLng,
    this.radiusKm,
  );

  factory Municipality.fromJson(String id, Map<String, dynamic> json) =>
      Municipality(
        id,
        json['name'] as String,
        (json['centerLat'] as num).toDouble(),
        (json['centerLng'] as num).toDouble(),
        (json['radiusKm'] as num).toDouble(),
      );

  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusKm;

  Map<String, dynamic> toJson() => {
    'name': name,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'radiusKm': radiusKm,
  };
}
