// In lib/services/marker_service.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerService {
  final Map<String, BitmapDescriptor> _iconCache = {};

  // This function now accepts an optional label to draw
  Future<BitmapDescriptor> _createPinMarkerBitmap(
    IconData iconData,
    Color backgroundColor, {
    String? label, // Optional label
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(200, 160); // Make canvas wider to accommodate text
    final pinSize = const Size(100, 120);
    final circleRadius = pinSize.width / 2;
    final circleCenter = Offset(size.width / 2, circleRadius);

    final fillPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;

    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    // --- Draw the pin shape (same as before, but centered) ---
    final pointerPath = Path();
    pointerPath.moveTo(size.width / 2, pinSize.height);
    pointerPath.lineTo(circleCenter.dx - (circleRadius * 0.6), circleCenter.dy);
    pointerPath.lineTo(circleCenter.dx + (circleRadius * 0.6), circleCenter.dy);
    pointerPath.close();

    canvas.drawPath(pointerPath.shift(const Offset(2, 2)), shadowPaint);
    canvas.drawCircle(circleCenter.translate(2, 2), circleRadius, shadowPaint);
    canvas.drawPath(pointerPath, fillPaint);
    canvas.drawCircle(circleCenter, circleRadius, fillPaint);

    // --- Draw the Icon (same as before) ---
    final iconPainter = TextPainter(textDirection: TextDirection.ltr);
    iconPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 55,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        (size.width - iconPainter.width) / 2,
        (circleRadius * 2 - iconPainter.height) / 2,
      ),
    );

    // --- NEW: Draw the label if it exists ---
    if (label != null) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 28, // Font size for the label
            fontWeight: FontWeight.bold,
            color: Colors.black,
            backgroundColor: Colors.white, // White background for readability
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout(maxWidth: size.width);
      labelPainter.paint(
        canvas,
        Offset(
          (size.width - labelPainter.width) / 2,
          pinSize.height + 5, // Position the label just below the pin
        ),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // createMarker now takes a 'showLabel' flag
  Future<Marker> createMarker({
    required Map<String, dynamic> data,
    required void Function(Map<String, dynamic>) onTap,
    required bool showLabel, // New flag to control label visibility
  }) async {
    final String category = data['type'] ?? '';
    final String label = data['name'] ?? 'POI';

    IconData iconData;
    Color color;

    // ... (your existing switch statement for iconData and color)
    switch (category) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        color = Colors.green;
        break;
      case 'Business Establishments':
        iconData = Icons.store;
        color = Colors.blue;
        break;
      case 'Accommodations':
        iconData = Icons.hotel;
        color = Colors.purple;
        break;
      case 'Transport Routes and Terminals':
        iconData = Icons.directions_bus;
        color = Colors.orange;
        break;
      case 'Agencies and Offices':
        iconData = Icons.corporate_fare;
        color = Colors.red;
        break;
      default:
        iconData = Icons.location_pin;
        color = Colors.grey;
    }

    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    if (lat == null || lng == null) {
      return Marker(markerId: MarkerId(data['id']));
    }

    // The cache key now includes whether the label is shown
    final String cacheKey = '${color.value}-${showLabel ? label : ""}';

    BitmapDescriptor icon;
    if (_iconCache.containsKey(cacheKey)) {
      icon = _iconCache[cacheKey]!;
    } else {
      // Conditionally pass the label to the bitmap generator
      icon = await _createPinMarkerBitmap(
        iconData,
        color,
        label: showLabel ? label : null,
      );
      _iconCache[cacheKey] = icon;
    }

    return Marker(
      markerId: MarkerId(data['id']),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 0.8), // Adjust anchor for the new shape
      onTap: () => onTap(data),
      // We no longer need the InfoWindow, as the label is part of the marker
      zIndex: 1, // 👈 ADD THIS LINE
    );
  }
}
