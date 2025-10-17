// In lib/models/poi_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Poi {
  final String id;
  final String name;
  final String description;
  final String type;
  final GeoPoint coordinates;
  final List<String> images;
  final String? imageUrl;
  final String? status; // 👈 ADD THIS
  final bool? guideRequired; // 👈 ADD THIS

  Poi({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.coordinates,
    required this.images,
    this.imageUrl,
    this.status, // 👈 ADD THIS
    this.guideRequired, // 👈 ADD THIS
  });

  // Factory constructor to create a Poi instance from a Firestore document
  factory Poi.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Poi(
      id: doc.id,
      name: data['name'] ?? 'Unnamed',
      description: data['description'] ?? '',
      type: data['type'] ?? 'Unknown',
      coordinates: data['coordinates'] ?? const GeoPoint(0, 0),
      images: List<String>.from(data['images'] ?? []),
      imageUrl: data['imageUrl'],
      status:
          data['status'], // 👈 ADD THIS (will be null if field doesn't exist)
      guideRequired:
          data['guideRequired'], // 👈 ADD THIS (will be null if field doesn't exist)
    );
  }

  // A method to convert our Poi object back to a Map, which is useful
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'coordinates': coordinates,
      'images': images,
      'imageUrl': imageUrl,
      'lat': coordinates.latitude,
      'lng': coordinates.longitude,
      'status': status, // 👈 ADD THIS
      'guideRequired': guideRequired, // 👈 ADD THIS
    };
  }
}
