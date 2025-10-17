import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/marker_service.dart';
import '../services/poi_search_delegate.dart';
import '../widgets/profile_menu.dart';
import '../widgets/discovery_panel.dart';
import '../widgets/custom_route_sheet.dart';
import '../widgets/compass_widget.dart';
import '../widgets/transport_browser_sheet.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_editor_screen.dart';

// Enum to manage the panel's visibility state
enum NavigationPanelState { hidden, minimized, expanded }

enum LocationButtonState {
  centered,
  offCenter,
  navigating,
  compass,
} // Add compass

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

String _currentTravelMode = "driving"; // driving by default
LatLng? _lastDestination; // remember last POI clicked

class _MapScreenState extends State<MapScreen> {
  Map<String, String>? _itinerarySummary; // 👈 ADD THIS
  Map<String, dynamic>? _currentTransportRouteData;
  bool _isAnimatingCamera = false;
  bool _tourismReminderShown = false; // 👈 ADD THIS LINE
  bool _isCustomRoutePreview = false;
  bool _isItineraryRouteVisible = false;
  LocationButtonState _locationButtonState = LocationButtonState.offCenter;
  bool _welcomeMessageShown = false;
  bool _isCompassMode = false;
  StreamSubscription<CompassEvent>? _compassSubscription;
  LatLng? _lastKnownPosition;
  double _lastKnownBearing = 0.0;
  String _liveDistance = '';
  String _liveDuration = '';
  String _liveEta = '';
  // Average speed in meters per second
  bool _isNavigating = false; // Tracks live navigation mode
  // New state variables to add to _MapScreenState
  NavigationPanelState _panelState = NavigationPanelState.hidden;
  User? _currentUser;
  Map<String, dynamic>? _userData;
  StreamSubscription? _authSubscription;
  StreamSubscription? _userDataSubscription; // 👈 ADD THIS
  Map<String, dynamic>? _navigationDetails;
  bool _isRouteLoading = false; // To show a loading indicator
  StreamSubscription<Position>? _positionStreamSubscription;
  List<Map<String, dynamic>> _allPoiData = []; // To cache Firestore data
  double _currentZoom = 14.0; // To track the current zoom level
  final double _labelZoomThreshold = 14.0; // The zoom level to show labels

  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];

  // Initial location (Sagada center approx)
  static const LatLng _initialPosition = LatLng(17.0885, 120.8996);

  // Map markers
  Set<Marker> _markers = {};

  // Filter options
  final List<String> _filters = [
    'All',
    'Tourist Spots',
    'Business Establishments',
    'Accommodations',
    'Transport Terminals',
    'Agencies and Offices',
  ];
  String _selectedFilter = 'All';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _poiSub;

  late BitmapDescriptor touristIcon;
  late BitmapDescriptor businessIcon;
  late BitmapDescriptor accommodationIcon;
  late BitmapDescriptor transportIcon;
  late BitmapDescriptor agencyIcon;

  Future<BitmapDescriptor> _createDistanceMarkerBitmap(String text) async {
    // 1. Set up the text painter
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 32, // Larger font size
          fontWeight: FontWeight.bold,
          color: Colors.white, // White text for contrast
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // 2. Define the tag's dimensions and style
    final double padding = 16.0;
    final double borderRadius = 16.0;
    final double shadowBlur = 8.0;
    final Size size = Size(
      textPainter.width + padding * 2,
      textPainter.height + padding,
    );
    final Paint backgroundPaint =
        Paint()..color = Theme.of(context).primaryColor; // Themed background
    final Paint borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final Paint shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    // 3. Set up the canvas
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      pictureRecorder,
      Rect.fromLTWH(
        0.0,
        0.0,
        size.width + shadowBlur,
        size.height + shadowBlur,
      ),
    );

    // 4. Draw the shadow
    final RRect shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(shadowBlur / 2, shadowBlur / 2, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 5. Draw the main background shape
    final RRect backgroundRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(backgroundRRect, backgroundPaint);

    // 6. Draw the border
    canvas.drawRRect(backgroundRRect, borderPaint);

    // 7. Draw the text in the center
    textPainter.paint(canvas, Offset(padding, padding / 2));

    // 8. Convert to BitmapDescriptor
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      (size.width + shadowBlur).toInt(),
      (size.height + shadowBlur).toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createNumberedCircleMarker(int number) async {
    const double size = 70; // The diameter of the circle
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint backgroundPaint = Paint()..color = Colors.orange.shade700;
    final Paint borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;

    // Draw the main colored circle
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      backgroundPaint,
    );

    // Draw the white border on top
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      borderPaint,
    );

    // Prepare and draw the number text
    final TextPainter textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = TextSpan(
      text: number.toString(),
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );

    textPainter.layout();

    // Center the text inside the circle
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // The main function to draw the itinerary
  Future<void> _drawItineraryRoute(List<GeoPoint> coordinates) async {
    if (coordinates.length < 2) return;

    _endNavigation();

    final String apiKey =
        "AIzaSyASDpIPyqjKL9Y_zg4TftfdP1vpedBCmv4"; // Ensure your key is here

    final LatLng origin = LatLng(
      coordinates.first.latitude,
      coordinates.first.longitude,
    );
    final LatLng destination = LatLng(
      coordinates.last.latitude,
      coordinates.last.longitude,
    );

    String waypoints = "";
    if (coordinates.length > 2) {
      waypoints =
          "optimize:true|" + // Ask Google to optimize the order of waypoints
          coordinates
              .sublist(1, coordinates.length - 1)
              .map((geo) => "${geo.latitude},${geo.longitude}")
              .join('|');
    }

    final String url =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&waypoints=$waypoints&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["routes"].isNotEmpty) {
        final route = data["routes"][0];
        final legs = route["legs"];

        // --- START OF NEW LOGIC ---

        final Set<Polyline> allPolylines = {};
        int totalDurationSeconds = 0;
        int totalDistanceMeters = 0;

        // 1. Add the main solid route line
        final String encodedOverviewPolyline =
            route["overview_polyline"]["points"];
        final List<LatLng> mainRoutePoints =
            PolylinePoints.decodePolyline(
              encodedOverviewPolyline,
            ).map((p) => LatLng(p.latitude, p.longitude)).toList();

        allPolylines.add(
          Polyline(
            polylineId: const PolylineId("itinerary_route_main"),
            color: Colors.orange.shade700,
            width: 6,
            points: mainRoutePoints,
          ),
        );

        // 2. Loop through each leg to add off-road segments and calculate totals
        for (int i = 0; i < legs.length; i++) {
          final leg = legs[i];
          totalDurationSeconds += leg["duration"]["value"] as int;
          totalDistanceMeters += leg["distance"]["value"] as int;

          // The end location of the leg is the ON-ROAD point
          final onRoadEndPoint = LatLng(
            leg["end_location"]["lat"],
            leg["end_location"]["lng"],
          );

          // The actual destination is the next coordinate in our list
          final actualDestination = LatLng(
            coordinates[i + 1].latitude,
            coordinates[i + 1].longitude,
          );

          // Check if there's a significant distance between the road and the POI
          if (Geolocator.distanceBetween(
                onRoadEndPoint.latitude,
                onRoadEndPoint.longitude,
                actualDestination.latitude,
                actualDestination.longitude,
              ) >
              10) {
            allPolylines.add(
              Polyline(
                polylineId: PolylineId("itinerary_offroad_$i"),
                color: Colors.orange.shade700,
                width: 5,
                points: [onRoadEndPoint, actualDestination],
                patterns: [PatternItem.dot, PatternItem.gap(10)],
              ),
            );
          }
        }

        final String totalDurationText =
            "${(totalDurationSeconds / 60).round()} min total";
        final String totalDistanceText =
            "${(totalDistanceMeters / 1000).toStringAsFixed(1)} km";

        // 3. Prepare numbered markers
        Set<Marker> numberedMarkers = {};
        for (int i = 0; i < coordinates.length; i++) {
          numberedMarkers.add(
            Marker(
              markerId: MarkerId('itinerary_stop_$i'),
              position: LatLng(
                coordinates[i].latitude,
                coordinates[i].longitude,
              ),
              icon: await _createNumberedCircleMarker(i + 1),
              zIndex: 2, // 👈 ADD THIS LINE
            ),
          );
        }

        // 4. Update the state with all polylines and markers
        setState(() {
          _polylines = allPolylines;
          _markers.addAll(numberedMarkers);
          _itinerarySummary = {
            'duration': totalDurationText,
            'distance': totalDistanceText,
          };
          _isItineraryRouteVisible = true;
        });

        // --- END OF NEW LOGIC ---

        LatLngBounds bounds = _boundsFromLatLngList(mainRoutePoints);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    }
  }

  Future<void> _showWelcomeToast(Map<String, dynamic> userData) async {
    final photoUrl = userData['profilePictureUrl'];
    final fullName = userData['fullName'] ?? 'Explorer';
    final Color themeColor = Theme.of(context).primaryColor;

    // By awaiting showDialog, we can ensure we wait until it's popped.
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        // This internal timer will pop the dialog, which completes the await.
        Future.delayed(const Duration(seconds: 4), () {
          if (context.mounted) {
            Navigator.of(context).pop(true);
          }
        });

        // The rest of the dialog UI remains the same
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: themeColor,
                  // --- REPLACE THIS LINE ---
                  backgroundImage:
                      (photoUrl != null && photoUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(
                            photoUrl,
                          ) // Use the caching provider
                          : null,
                  // --- END OF REPLACEMENT ---
                  child:
                      (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Welcome, $fullName!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _rebuildMarkers() async {
    // 👈 ADD THIS LINE: If an itinerary route is visible, do not rebuild the markers.
    if (_isItineraryRouteVisible) return;

    final bool showLabels = _currentZoom > _labelZoomThreshold;

    final markers = await Future.wait(
      _allPoiData.map((data) async {
        final markerService = MarkerService();
        return await markerService.createMarker(
          data: data,
          showLabel: showLabels, // Pass the flag here
          onTap: (data) {
            _showPoiSheet(
              name: data['name'] ?? 'Unnamed',
              description: data['description'] ?? 'No description available.',
              data: data,
            );
          },
        );
      }),
    );

    if (mounted) {
      setState(() {
        _markers = Set.from(markers);
      });
    }
  }

  Future<BitmapDescriptor> _createCircleMarkerBitmap(
    Color color, {
    double size = 48,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint borderPaint = Paint()..color = Colors.white;
    final Paint fillPaint = Paint()..color = color;

    final double borderWidth = size * 0.1; // 10% of the size for the border

    // Draw the white border circle
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);
    // Draw the inner colored circle
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - borderWidth,
      fillPaint,
    );

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  // This is the new, more powerful function
  Future<void> _drawRoute(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    // Save destination for re-use if needed later
    _lastDestination = destination;

    PolylinePoints polylinePoints = PolylinePoints(
      apiKey: "AIzaSyASDpIPyqjKL9Y_zg4TftfdP1vpedBCmv4", // Use your API key
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode:
            mode == "walking"
                ? TravelMode.walking
                : mode == "bicycling"
                ? TravelMode.bicycling
                : TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      _polylineCoordinates =
          result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

      // --- START OF CHANGES ---

      // Create a new Set to hold all our polylines (the main route + the off-road part)
      final Set<Polyline> polylines = {};

      // 1. Create the main, solid on-road route polyline
      polylines.add(
        Polyline(
          polylineId: const PolylineId("on_road_route"),
          color: Colors.blue.shade400,
          width: 5,
          points: _polylineCoordinates,
          patterns:
              mode == 'walking'
                  ? [PatternItem.dash(15), PatternItem.gap(10)]
                  : [],
        ),
      );

      // 2. Check if the destination is off-road and create the dotted line
      final LatLng lastPointOnRoad = _polylineCoordinates.last;
      final double offRoadDistance = Geolocator.distanceBetween(
        lastPointOnRoad.latitude,
        lastPointOnRoad.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Only draw the dotted line if the destination is more than 10 meters from the road
      if (offRoadDistance > 10) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId("off_road_segment"),
            color: Colors.blue.shade400, // Same color for consistency
            width: 5,
            points: [
              lastPointOnRoad,
              destination,
            ], // A simple line from the road to the destination
            patterns: [
              PatternItem.dot,
              PatternItem.gap(10),
            ], // This creates the dotted effect
          ),
        );
      }

      // 3. Create the custom circle icons for start and end
      final BitmapDescriptor startIcon = await _createCircleMarkerBitmap(
        Colors.green.shade600,
      );
      final BitmapDescriptor endIcon = await _createCircleMarkerBitmap(
        Colors.blue.shade600,
      );

      setState(() {
        _polylines =
            polylines; // Update the state with our new set of polylines

        _markers.add(
          Marker(
            markerId: const MarkerId('start_pin'),
            position: origin,
            icon: startIcon,
            anchor: const Offset(0.5, 0.5),
            zIndex: 1,
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('end_pin'),
            position: destination, // The end marker is at the TRUE destination
            icon: endIcon,
            anchor: const Offset(0.5, 0.5),
            zIndex: 1,
          ),
        );
      });

      // --- END OF CHANGES ---

      LatLngBounds bounds = _boundsFromLatLngList([
        origin,
        destination,
        ..._polylineCoordinates,
      ]);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No route available for $mode mode here.")),
      );
    }
  }

  // Your old _drawRouteToPoi function now becomes much simpler
  Future<void> _drawRouteToPoi(
    double destLat,
    double destLng,
    String mode,
  ) async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _drawRoute(
      LatLng(pos.latitude, pos.longitude),
      LatLng(destLat, destLng),
      mode,
    );

    setState(() {
      _isCustomRoutePreview = false;
    });

    await _drawRoute(
      LatLng(pos.latitude, pos.longitude),
      LatLng(destLat, destLng),
      mode,
    );

    // We can also trigger the navigation panel here if we want
    final details = await _getDirectionsDetails(
      LatLng(pos.latitude, pos.longitude),
      LatLng(destLat, destLng),
      mode,
    );
    if (details != null && mounted) {
      _startNavigation(details);
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }

  Future<Map<String, dynamic>?> _getDirectionsDetails(
    LatLng origin,
    LatLng destination,
    String mode,
  ) async {
    final String apiKey =
        "AIzaSyASDpIPyqjKL9Y_zg4TftfdP1vpedBCmv4"; // 👈 use your key
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["status"] == "ZERO_RESULTS") {
        return {
          "distance": "N/A",
          "duration": "N/A",
          "endAddress": "${destination.latitude}, ${destination.longitude}",
        };
      }
      if (data["routes"].isNotEmpty) {
        final leg = data["routes"][0]["legs"][0];
        return {
          "distance": leg["distance"]["text"],
          "duration": leg["duration"]["text"],
          "endAddress": leg["end_address"],
        };
      }
    }

    return null;
  }

  Future<void> _loadCustomIcons() async {
    touristIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/tourist.png',
    );
    print("✅ Tourist icon loaded: $touristIcon");
    businessIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/business.png',
    );
    print("✅ Business icon loaded: $businessIcon");
    accommodationIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/accommodation.png',
    );
    print("✅ Accommodation icon loaded: $accommodationIcon");
    transportIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/transport.png',
    );
    print("✅ Transport icon loaded: $transportIcon");
    agencyIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/agency.png',
    );
    print("✅ Agency icon loaded: $agencyIcon");
  }

  // ADD THESE TWO METHODS INSIDE _MapScreenState
  // In _MapScreenState
  Future<bool?> _showResponsibleTourismReminder({
    Map<String, dynamic>? poiData,
  }) async {
    final bool isGuideRequired = poiData?['guideRequired'] as bool? ?? false;
    final guideSubtitle =
        isGuideRequired
            ? 'This destination requires an accredited guide.'
            : 'For certain sites, a guide may be required. Please verify at the Tourism Office.';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.zero,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

          title: null,

          // This is the main content of the dialog
          content: SizedBox(
            // Constrain the width of the content. This is the key fix.
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Make column take up minimum space
                children: [
                  // GIF Animation at the top
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/gifs/tourist_walk.gif', // Your GIF path here
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          'Be a Responsible Tourist!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Information List
                        ListTile(
                          leading: Icon(
                            Icons.app_registration,
                            color: Colors.blue.shade700,
                          ),
                          title: const Text(
                            'Register First',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Always register at the Municipal Tourism Office before proceeding.',
                          ),
                          dense: true,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.person_search,
                            color: Colors.green.shade700,
                          ),
                          title: const Text(
                            'Secure a Guide',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(guideSubtitle),
                          dense: true,
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.eco,
                            color: Colors.orange.shade700,
                          ),
                          title: const Text(
                            'Leave No Trace',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Respect environment & local culture. Take your trash with you.',
                          ),
                          dense: true,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('I Understand'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCustomRouteSheet() async {
    // Hide the discovery panel if it's open
    // (You might need to add a method to your DiscoveryPanel to control this,
    // or manage its visibility with a state variable here)

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CustomRouteSheet(),
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      final startPoi = result['start']!;
      final endPoi = result['end']!;

      final startCoords = startPoi['coordinates'] as GeoPoint;
      final endCoords = endPoi['coordinates'] as GeoPoint;

      final LatLng startLatLng = LatLng(
        startCoords.latitude,
        startCoords.longitude,
      );
      final LatLng endLatLng = LatLng(endCoords.latitude, endCoords.longitude);

      // Clear any previous navigation state
      _endNavigation();

      // Step 1: Draw the new custom route
      await _drawRoute(startLatLng, endLatLng, _currentTravelMode);

      // --- ADD THESE LINES ---
      // Step 2: Get the details for the route we just drew
      final details = await _getDirectionsDetails(
        startLatLng,
        endLatLng,
        _currentTravelMode,
      );

      // Step 3: Show the navigation panel with the details
      if (details != null && mounted) {
        setState(() {
          _isCustomRoutePreview = true; // 👈 SET THE FLAG TO TRUE HERE
        });
        _startNavigation(details);
      }
      // --- END OF ADDED LINES ---
    }
  }

  void _startCompassMode() {
    // We remove the "if (_isCompassMode)" check that caused the timing issue.
    // We also check if a subscription already exists to avoid duplicates.
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((
      CompassEvent event,
    ) async {
      // Make the listener async

      // Set our flag to true so _onCameraMoveStarted ignores this animation.
      _isAnimatingCamera = true;

      // Animate the camera to the new bearing.
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastKnownPosition ?? _initialPosition,
            zoom: 17.5,
            tilt: 50.0,
            bearing: event.heading ?? 0,
          ),
        ),
      );

      // After the animation, set the flag back to false.
      // A small delay ensures the 'camera idle' state is reached.
      Future.delayed(const Duration(milliseconds: 200), () {
        _isAnimatingCamera = false;
      });
    });
  }

  void _showTransportRouteDetailsDialog() {
    if (_currentTransportRouteData == null) return;

    final route = _currentTransportRouteData!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(route['routeName'] ?? 'Route Details'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ), // Optional: Nicer corners
            // --- START OF FIX ---
            // Replace ListBody with a Column
            content: Column(
              mainAxisSize:
                  MainAxisSize.min, // This is important for Columns in dialogs
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.money),
                  title: const Text('Fare'),
                  subtitle: Text(route['fareDetails'] ?? 'Not available'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Schedule'),
                  subtitle: Text(route['schedule'] ?? 'Not available'),
                ),
              ],
            ),

            // --- END OF FIX ---
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  Future<void> _stopCompassMode({bool resetBearing = true}) async {
    _compassSubscription?.cancel();
    _compassSubscription = null; // Clear the subscription
    if (resetBearing) {
      // Set the flag before animating
      _isAnimatingCamera = true;
      // Optionally reset the map to point North
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _lastKnownPosition ?? _initialPosition,
            zoom: 16,
            bearing: 0,
            tilt: 0,
          ),
        ),
      );
      // Unset the flag after animating
      _isAnimatingCamera = false;
    }
  }

  // In map_screen.dart -> inside _MapScreenState

  void _onCameraMoveStarted() {
    // If the user manually moves the map, exit compass or centered mode.
    if (_isAnimatingCamera) return;
    if (_isCompassMode) {
      setState(() {
        _isCompassMode = false;
        _locationButtonState = LocationButtonState.offCenter;
      });
      // Stop listening to the compass but DON'T reset the camera view.
      _stopCompassMode(resetBearing: false);
    } else if (_locationButtonState == LocationButtonState.centered) {
      setState(() {
        _locationButtonState = LocationButtonState.offCenter;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // UPDATED SNACKBAR
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location services are disabled.'),
          action: SnackBarAction(
            label: 'Enable',
            onPressed: () {
              // Opens the device's location settings
              AppSettings.openAppSettings(type: AppSettingsType.location);
            },
          ),
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied.'),
        ),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _lastKnownPosition = LatLng(pos.latitude, pos.longitude);

    if (_locationButtonState == LocationButtonState.centered) {
      // From centered -> enter compass mode
      setState(() {
        _isCompassMode = true;
        _locationButtonState = LocationButtonState.compass;
      });
      _startCompassMode();
    } else {
      // From off-center or compass -> enter centered mode
      setState(() {
        _isCompassMode = false;
        _locationButtonState = LocationButtonState.centered;
      });
      // Await the function so the flag is handled correctly
      await _stopCompassMode();
    }
  }

  void _showTransportBrowser() async {
    // Now it expects a Map of the full route data
    final Map<String, dynamic>? routeData =
        await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const TransportBrowserSheet(),
        );

    if (routeData != null) {
      // 👈 1. Call the cleanup function FIRST to clear any old route.
      _endNavigation();

      // 👈 2. THEN, set the state with the new route's data.
      setState(() {
        _currentTransportRouteData = routeData;
      });

      // 👈 3. FINALLY, draw the new route.
      _drawTransportRoute(routeData);
    }
  }

  void _drawTransportRoute(Map<String, dynamic> routeData) {
    final String? encodedPolyline = routeData['polyline'] as String?;
    if (encodedPolyline == null || encodedPolyline.isEmpty) return;

    List<PointLatLng> polylinePoints = PolylinePoints.decodePolyline(
      encodedPolyline,
    );

    if (polylinePoints.isNotEmpty) {
      _polylineCoordinates =
          polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId(routeData['routeName'] ?? "transport_route"),
            color: Colors.purple,
            // --- CHANGES BELOW ---
            width: 8, // Make the line thicker (easier to tap)
            jointType: JointType.round, // Makes the line corners look smoother
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            // --- END OF CHANGES ---
            points: _polylineCoordinates,
            consumeTapEvents: true,
            onTap: () {
              // Add a print statement for debugging
              print("Polyline for '${routeData['routeName']}' was tapped!");
              _showTransportRouteDetailsDialog();
            },
          ),
        };
      });

      LatLngBounds bounds = _boundsFromLatLngList(_polylineCoordinates);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
    }
  }

  @override
  void initState() {
    super.initState();

    // Assign to the existing class variable, don't create a new one
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        _listenToUserData(user.uid);
      } else {
        _userDataSubscription?.cancel();
        setState(() {
          _userData = null;
        });
      }
    });

    _loadCustomIcons().then((_) {
      _listenToPOIs();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation();
    });
  }

  // New function to fetch user data
  // New function to fetch user data
  // In map_screen.dart

  void _listenToUserData(String userId) {
    _userDataSubscription?.cancel();
    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          // Make the callback async
          (DocumentSnapshot snapshot) async {
            if (snapshot.exists && mounted) {
              final data = snapshot.data() as Map<String, dynamic>;
              setState(() {
                _userData = data;
              });

              // --- ADD THIS BLOCK ---
              // Start downloading the image in the background
              final photoUrl = data['profilePictureUrl'] as String?;
              if (photoUrl != null && photoUrl.isNotEmpty) {
                precacheImage(NetworkImage(photoUrl), context);
              }
              // --- END OF BLOCK ---

              if (!_welcomeMessageShown) {
                _welcomeMessageShown = true; // Mark as shown immediately

                // --- REVISED LOGIC ---
                // Step 1: Wait for the welcome toast to show and dismiss.
                await _showWelcomeToast(data);

                // Step 2: Now that the first dialog is gone, show the reminder.
                if (mounted && !_tourismReminderShown) {
                  await _showResponsibleTourismReminder();
                  setState(() {
                    _tourismReminderShown = true;
                  });
                }
                // --- END OF REVISED LOGIC ---
              }
            }
          },
          onError: (e) {
            print("Error listening to user data: $e");
          },
        );
  }

  @override
  void dispose() {
    _authSubscription?.cancel(); // Don't forget to cancel the subscription
    _userDataSubscription?.cancel();
    _poiSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setMapStyle('tourism.json');
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter == null) return;
    if (newFilter == _selectedFilter) return;

    setState(() {
      _selectedFilter = newFilter;
    });

    // Re-subscribe with the new query
    _listenToPOIs();
  }

  void _listenToPOIs() {
    _poiSub?.cancel();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'POIs',
    );
    if (_selectedFilter != 'All') {
      query = query.where('type', isEqualTo: _selectedFilter);
    }

    _poiSub = query.snapshots().listen(
      (snapshot) async {
        // Store the fetched data in our state list
        _allPoiData =
            snapshot.docs.map((doc) {
              final data = doc.data();
              // Manually add the fields needed by createMarker
              data['id'] = doc.id;
              final coords = data['coordinates'] as GeoPoint?;
              data['lat'] = coords?.latitude;
              data['lng'] = coords?.longitude;
              return data;
            }).toList();

        // Rebuild the markers with the new data
        await _rebuildMarkers();
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load POIs: $e')));
        }
      },
    );
  }

  // Replace the entire _showPoiSheet method with this updated version

  void _showPoiSheet({
    required String name,
    required String description,
    required Map<String, dynamic> data,
  }) {
    _saveToRecentlyViewed(data);

    // --- 1. GET ALL THE DATA ---
    final images = (data['images'] as List?)?.cast<String>() ?? [];
    final singleImage = data['imageUrl'] as String?;

    // Get the POI type to decide which details to show
    final poiType = data['type'] as String?;

    // Get all possible practical details with default values
    final openingHours = data['openingHours'] as String? ?? '';
    final entranceFee = data['entranceFee'] as String? ?? '';
    final guideRequired = data['guideRequired'] as bool?; // Nullable boolean
    final contactNumber = data['contactNumber'] as String? ?? '';
    final status = data['status'] as String?; // New field for status

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Drag handle & POI Name ---
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Image carousel or single image ---
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              // --- REPLACE Image.network ---
                              child: CachedNetworkImage(
                                imageUrl: images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder:
                                    (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                errorWidget:
                                    (context, url, error) =>
                                        const Icon(Icons.error),
                              ),
                              // --- END REPLACEMENT ---
                            );
                          },
                        ),
                      )
                    else if (singleImage != null && singleImage.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // --- REPLACE Image.network ---
                        child: CachedNetworkImage(
                          imageUrl: singleImage,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          errorWidget:
                              (context, url, error) => const Icon(Icons.error),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // --- START: MODIFIED DETAILS SECTION ---
                    Wrap(
                      spacing: 8.0, // Horizontal space between chips
                      runSpacing: 8.0, // Vertical space between chip rows
                      children: [
                        // Fields for Tourist Spots ONLY
                        if (poiType == 'Tourist Spots') ...[
                          // Status Chip (Open/Closed)
                          if (status != null && status.isNotEmpty)
                            _buildStatusChip(status),

                          // Guide Required Chip
                          if (guideRequired != null)
                            _buildDetailChip(
                              icon: Icons.person_search_outlined,
                              label: 'Guide',
                              value:
                                  guideRequired ? 'Required' : 'Not Required',
                            ),
                        ],

                        // Fields for NON-Tourist Spots
                        if (poiType != 'Tourist Spots') ...[
                          // Entrance Fee Chip
                          if (entranceFee.isNotEmpty)
                            _buildDetailChip(
                              icon: Icons.local_activity_outlined,
                              label: 'Fee',
                              value: entranceFee,
                            ),

                          // Contact Number Chip
                          if (contactNumber.isNotEmpty)
                            _buildDetailChip(
                              icon: Icons.phone_outlined,
                              label: 'Contact',
                              value: contactNumber,
                            ),
                        ],

                        // Opening Hours Chip (Common to all types if available)
                        if (openingHours.isNotEmpty)
                          _buildDetailChip(
                            icon: Icons.access_time_outlined,
                            label: 'Hours',
                            value: openingHours,
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Description Card ---
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          // The background image remains the same
                          Ink.image(
                            image: const AssetImage("assets/images/poibg.png"),
                            height: 150,
                            fit: BoxFit.cover,
                            child: Container(
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ),

                          // The Padding widget's child is now a SingleChildScrollView
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              // 👈 ADD THIS WIDGET
                              child: Text(
                                description.isEmpty
                                    ? "No description available."
                                    : description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ), // 👈 & ITS CLOSING PARENTHESIS
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Get Directions Button ---
                    Row(
                      children: [
                        // Add to Plan Button
                        Expanded(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text("Add to Plan"),
                            onPressed: () async {
                              // 1. Show the itinerary selector to get the trip ID
                              final Map<String, dynamic>? selectedItinerary =
                                  await _showItinerarySelectorDialog();
                              if (selectedItinerary == null)
                                return; // User canceled

                              String itineraryId = selectedItinerary['id']!;

                              // Handle creating a new itinerary if requested
                              if (itineraryId == 'CREATE_NEW') {
                                // --- START OF NEW LOGIC ---
                                // 1a. Show a dialog to get the new itinerary name
                                final TextEditingController nameController =
                                    TextEditingController();
                                final String?
                                newName = await showDialog<String>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('New Itinerary'),
                                        content: TextField(
                                          controller: nameController,
                                          decoration: const InputDecoration(
                                            hintText:
                                                "e.g., 'My Weekend Getaway'",
                                          ),
                                          autofocus: true,
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: const Text('Create'),
                                            onPressed: () {
                                              if (nameController
                                                  .text
                                                  .isNotEmpty) {
                                                Navigator.of(
                                                  context,
                                                ).pop(nameController.text);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                );

                                // If the user canceled the naming dialog, stop everything.
                                if (newName == null || newName.isEmpty) return;

                                // 1b. Create the new itinerary document in Firestore with the user's chosen name
                                final newDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(_currentUser!.uid)
                                    .collection('itineraries')
                                    .add({
                                      'name':
                                          newName, // Use the name from the dialog
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'lastModified':
                                          FieldValue.serverTimestamp(),
                                    });
                                itineraryId =
                                    newDoc
                                        .id; // Update the ID to the newly created one
                                // --- END OF NEW LOGIC ---
                              }

                              // 2. IMPORTANT: Close the POI sheet *before* navigating to the new screen
                              if (mounted) {
                                Navigator.of(context).pop();
                              }

                              // 3. Navigate to the Event Editor Screen
                              if (mounted) {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EventEditorScreen(
                                          itineraryId: itineraryId,
                                          initialPoiData: data,
                                        ),
                                  ),
                                );

                                // 4. If we got a success message back, show it in a SnackBar
                                if (result is String && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Get Directions Button
                        // Get Directions Button with its logic restored
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            icon: const Icon(
                              Icons.directions,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Get Directions",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            // Ensure this onPressed logic is present
                            onPressed: () async {
                              Navigator.pop(context); // Close the POI sheet

                              final lat = data['lat'] as double?;
                              final lng = data['lng'] as double?;

                              if (lat != null && lng != null) {
                                await _drawRouteToPoi(
                                  lat,
                                  lng,
                                  _currentTravelMode,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Call this when the "Get Directions" button is pressed
  void _startNavigation(Map<String, dynamic> initialDetails) {
    setState(() {
      _navigationDetails = initialDetails;
      _panelState = NavigationPanelState.expanded;

      // 👇 Sync live data with the initial API data
      _liveDistance = initialDetails["distance"] ?? '';
      _liveDuration = initialDetails["duration"] ?? '';
    });

    _updateDistanceMarker(_liveDistance); // Use the live variable
  }

  // Handles changing the travel mode
  Future<void> _updateRoute(String newMode) async {
    if (_lastDestination == null || _currentTravelMode == newMode) return;

    setState(() {
      _isRouteLoading = true;
      _currentTravelMode = newMode;
    });

    final pos = await Geolocator.getCurrentPosition();
    final newDetails = await _getDirectionsDetails(
      LatLng(pos.latitude, pos.longitude),
      _lastDestination!,
      newMode,
    );

    await _drawRouteToPoi(
      _lastDestination!.latitude,
      _lastDestination!.longitude,
      newMode,
    );

    setState(() {
      if (newDetails != null) {
        _navigationDetails = newDetails;
        // 👇 Sync live data when the route is updated
        _liveDistance = newDetails["distance"] ?? '';
        _liveDuration = newDetails["duration"] ?? '';
      }
      _isRouteLoading = false;
    });
  }

  Future<void> _setMapStyle(String fileName) async {
    if (_mapController == null) return;

    // Load the JSON file from assets
    final style = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_styles/$fileName');

    // Apply it to the map
    _mapController!.setMapStyle(style);
  }

  // In map_homescreen.dart
  // Replace the whole function with this one.

  Future<void> _saveToRecentlyViewed(Map<String, dynamic> poiData) async {
    if (_currentUser == null) return; // Only save if a user is logged in

    print("✅ Saving '${poiData['name']}' to recently viewed...");

    final String poiId = poiData['id'];
    final String userId = _currentUser!.uid;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .doc(poiId);

    // --- START OF FIX ---
    // Safely get the list of images, which might be null.
    final imagesList = poiData['images'] as List?;

    // Determine the image URL safely.
    String? recentImageUrl;
    if (imagesList != null && imagesList.isNotEmpty) {
      recentImageUrl = imagesList[0] as String?;
    } else {
      // Fallback to the single imageUrl field if 'images' is missing or empty
      recentImageUrl = poiData['imageUrl'] as String?;
    }
    // --- END OF FIX ---

    // Use `set` to either create a new record or update the timestamp
    await docRef.set({
      'poiId': poiId,
      'viewedAt': FieldValue.serverTimestamp(),
      'name': poiData['name'],
      // Use the safely determined URL, ensuring it's not null
      'imageUrl': recentImageUrl ?? '',
    });

    // ... (the rest of the function for limiting history remains the same)
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('recentlyViewed')
        .orderBy('viewedAt', descending: true)
        .limit(20);

    final snapshot = await query.get();
    if (snapshot.docs.length == 20) {
      final lastVisible = snapshot.docs.last;
      final olderItemsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recentlyViewed')
          .where('viewedAt', isLessThan: lastVisible['viewedAt']);

      final olderItems = await olderItemsQuery.get();
      for (var doc in olderItems.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<Map<String, dynamic>?> _showItinerarySelectorDialog() async {
    if (_currentUser == null) return null;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('itineraries')
            .get();

    final itineraries = snapshot.docs;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to Itinerary'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child:
                itineraries.isEmpty
                    ? const Center(
                      child: Text('No itineraries found. Create one!'),
                    )
                    : ListView.builder(
                      itemCount: itineraries.length,
                      itemBuilder: (context, index) {
                        final doc = itineraries[index];
                        final data = doc.data();
                        return ListTile(
                          title: Text(data['name'] ?? 'Untitled Itinerary'),
                          onTap: () {
                            Navigator.pop(context, {
                              'id': doc.id,
                              'name': data['name'],
                            });
                          },
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton.icon(
              // A more prominent "Create New" button
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
              onPressed: () {
                Navigator.pop(context, {'id': 'CREATE_NEW', 'name': ''});
              },
            ),
          ],
        );
      },
    );
  }

  // Ends navigation and hides the panel
  void _endNavigation() {
    _positionStreamSubscription?.cancel();

    setState(() {
      _clearPolylines(); // You should already have this function
      _panelState = NavigationPanelState.hidden;
      _navigationDetails = null;
      _lastDestination = null; // Forget the last destination
      _lastKnownPosition = null;
      _currentTransportRouteData = null; // 👈 ADD THIS LINE
      _itinerarySummary = null; // 👈 ADD THIS LINE
      _isItineraryRouteVisible = false; // 👈 ADD THIS LINE

      // Remove the route-specific markers
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'start_pin' ||
            m.markerId.value == 'end_pin' ||
            m.markerId.value == 'distance_marker' ||
            m.markerId.value.startsWith('itinerary_stop_'),
      ); // Also remove distance marker
    });
  }

  /// Decides which panel to show based on the current state

  /// Enters the immersive turn-by-turn navigation mode.
  void _enterLiveNavigation() {
    // ... (the initial calculation part remains the same)
    final String initialDurationText =
        _navigationDetails?["duration"] ?? "0 min";
    final String initialDistanceText =
        _navigationDetails?["distance"] ?? "0 km";
    final initialDurationMinutes =
        int.tryParse(initialDurationText.split(" ").first) ?? 0;
    final initialDistanceKm =
        double.tryParse(initialDistanceText.split(" ").first) ?? 0;

    if (initialDurationMinutes > 0) {
    } else {}

    _liveDistance = initialDistanceText;
    _liveDuration = initialDurationText;
    _liveEta = DateFormat(
      'h:mm a',
    ).format(DateTime.now().add(Duration(minutes: initialDurationMinutes)));

    setState(() {
      _isNavigating = true;
      _panelState = NavigationPanelState.hidden;
    });

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ), // Update every 20 meters
    ).listen((Position position) async {
      // Make the callback async

      // (The camera filtering logic remains the same)
      double distanceMoved = 0;
      if (_lastKnownPosition != null) {
        distanceMoved = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      if (_lastKnownPosition == null || distanceMoved > 3.0) {
        final newBearing =
            position.speed > 1 ? position.heading : _lastKnownBearing;
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 17.5,
              tilt: 50.0,
              bearing: newBearing,
            ),
          ),
        );
        _lastKnownPosition = LatLng(position.latitude, position.longitude);
        _lastKnownBearing = newBearing;
      }

      // ----------- NEW ACCURATE RECALCULATION LOGIC -----------
      if (_lastDestination != null) {
        // Re-fetch the route from the user's new position
        final newDetails = await _getDirectionsDetails(
          LatLng(position.latitude, position.longitude),
          _lastDestination!,
          _currentTravelMode,
        );

        if (newDetails != null) {
          final int remainingMinutes =
              int.tryParse(newDetails["duration"].split(" ").first) ?? 0;
          final newEta = DateTime.now().add(
            Duration(minutes: remainingMinutes),
          );

          // Update state with the ACCURATE data from the API
          setState(() {
            _liveDistance = newDetails["distance"];
            _liveDuration = newDetails["duration"];
            _liveEta = DateFormat('h:mm a').format(newEta);
          });
        }
      }
    });
  }

  /// Exits the live navigation mode and returns to the overview.
  void _exitLiveNavigation() {
    // Stop the immersive camera tracking
    _positionStreamSubscription?.cancel();

    setState(() {
      _isNavigating = false;
      _panelState = NavigationPanelState.expanded; // Show details again
    });

    // 👇 UPDATE THIS PART
    // Instead of starting the old listener, just update the tag
    // with the last known accurate distance.
    _updateDistanceMarker(_liveDistance);

    // Reset camera to show the whole route
    if (_polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds = _boundsFromLatLngList(_polylineCoordinates);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _clearPolylines() {
    setState(() {
      _polylines.clear();
      _polylineCoordinates.clear();
    });
  }

  /// Creates or updates the distance marker on the map.
  void _updateDistanceMarker(String distanceText) async {
    if (_polylineCoordinates.isEmpty) return;

    // Find the midpoint of the polyline to place the marker
    final LatLng markerPosition =
        _polylineCoordinates[_polylineCoordinates.length ~/ 2];

    // Create the custom marker from text
    final BitmapDescriptor markerIcon = await _createDistanceMarkerBitmap(
      distanceText,
    );

    final distanceMarker = Marker(
      markerId: const MarkerId('distance_marker'),
      position: markerPosition,
      icon: markerIcon,
      anchor: const Offset(0.5, 0.5), // Center the marker
    );

    setState(() {
      // Remove the old marker and add the new one
      _markers.removeWhere((m) => m.markerId.value == 'distance_marker');
      _markers.add(distanceMarker);
    });
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final double paddingTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onCameraMoveStarted: _onCameraMoveStarted,

            // Update the current zoom level as the user moves the map
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },

            // When the user stops moving the map, rebuild the markers
            onCameraIdle: () {
              _rebuildMarkers();
            },

            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled:
                _isNavigating ? true : true, // Use custom marker in nav mode
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false, // Hide compass during immersive navigation
          ),
          _buildItinerarySummaryPanel(), // 👈 ADD THIS WIDGET
          // --- PASTE THE COMPASS WIDGET HERE AND UPDATE IT ---
          Positioned(top: paddingTop + 70, right: 12, child: CompassWidget()),

          // --- ITINERARY-SPECIFIC UI (Only visible when itinerary route is active) ---
          if (_isItineraryRouteVisible) ...[
            // The Summary Panel
            _buildItinerarySummaryPanel(),

            // The Close Button
            Positioned(
              top: paddingTop + 130, // Position it below the compass
              right: 16,
              child: _buildClearItineraryButton(),
            ),
          ],

          // --- STANDARD UI (Hidden when itinerary route is active) ---
          if (!_isItineraryRouteVisible) ...[
            // The top bar with profile, filter, and search
            if (!_isNavigating)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // User Profile Button
                          _buildProfileButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder:
                                    (context) => ProfileMenu(
                                      userData: _userData,
                                      onDrawItinerary:
                                          (coords) => _drawItineraryRoute(
                                            coords,
                                          ), // Pass the function
                                    ),
                              );
                            },
                          ),
                          // Dropdown filter
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ), // A bit more padding
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  isExpanded: true,
                                  // Use a themed dropdown arrow
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  onChanged: _onFilterChanged,

                                  // This builder customizes the look of the COLLAPSED button
                                  selectedItemBuilder: (BuildContext context) {
                                    return _filters.map<Widget>((String item) {
                                      return Row(
                                        children: [
                                          _getIconForFilter(item),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },

                                  // This builder customizes the look of the items in the EXPANDED list
                                  items:
                                      _filters.map((String item) {
                                        return DropdownMenuItem<String>(
                                          value: item,
                                          child: Row(
                                            children: [
                                              _getIconForFilter(item),
                                              const SizedBox(width: 10),
                                              Text(item),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ),
                          // Search button
                          _buildRoundButton(
                            icon: Icons.search,
                            onPressed: () async {
                              final result =
                                  await showSearch<Map<String, dynamic>?>(
                                    context: context,
                                    delegate: POISearchDelegate(),
                                  );
                              if (result != null) {
                                final lat = result['lat'] as double?;
                                final lng = result['lng'] as double?;
                                if (lat != null && lng != null) {
                                  const double latOffset = 0.0012;
                                  await _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(lat + latOffset, lng),
                                      16,
                                    ),
                                  );
                                  Future.delayed(
                                    const Duration(milliseconds: 300),
                                    () {
                                      _showPoiSheet(
                                        name: result['name'] ?? 'Unnamed',
                                        description:
                                            result['description'] ?? '',
                                        data: result,
                                      );
                                    },
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // The column of floating action buttons on the right
            if (!_isNavigating)
              Positioned(
                bottom: 120,
                right: 16,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Show buttons ONLY if the nav panel is also hidden
                    if (_panelState == NavigationPanelState.hidden) ...[
                      // Transport Options Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder:
                            (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                        child:
                            _currentTransportRouteData == null
                                ? FloatingActionButton(
                                  key: const ValueKey('transport_button'),
                                  heroTag: 'transport_button',
                                  onPressed: _showTransportBrowser,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.directions_bus,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      // Custom Route Button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder:
                            (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                        child:
                            _currentTransportRouteData == null
                                ? FloatingActionButton(
                                  key: const ValueKey('route_button'),
                                  heroTag: 'route_button',
                                  onPressed: _showCustomRouteSheet,
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: const Icon(
                                    Icons.directions,
                                    color: Colors.white,
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildLocationButton(),
                    const SizedBox(height: 12),
                    if (_panelState == NavigationPanelState.hidden)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder:
                            (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                        child:
                            _currentTransportRouteData == null
                                ? _buildMapStyleButton()
                                : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),

            // "Clear Transport Route" button on the left
            if (_currentTransportRouteData != null)
              Positioned(
                bottom: 100,
                left: 16,
                child: _buildClearRouteButton(),
              ),

            // Discover Places Panel
            if (!_isNavigating &&
                _panelState == NavigationPanelState.hidden &&
                _currentTransportRouteData == null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: DiscoveryPanel(
                  onPoiSelected:
                      (poiData) => _showPoiSheet(
                        name: poiData['name'] ?? '',
                        description: poiData['description'] ?? '',
                        data: poiData,
                      ),
                ),
              ),
          ],

          // --- NAVIGATION UI (Overlays everything else) ---
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                _isNavigating
                    ? _buildLiveNavigationUI()
                    : _buildNavigationPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Chip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF3A6A55)),
      label: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey.shade800),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isOpen = status.toLowerCase() == 'open';
    final Color statusColor =
        isOpen ? Colors.green.shade700 : Colors.red.shade700;
    final IconData statusIcon =
        isOpen ? Icons.check_circle_outline : Icons.highlight_off_outlined;

    return Chip(
      avatar: Icon(statusIcon, size: 18, color: statusColor),
      label: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey.shade800),
          children: [
            const TextSpan(
              text: 'Status: ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: status,
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
      ),
      backgroundColor: statusColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
    );
  }

  Widget _getIconForFilter(String filter) {
    IconData iconData;
    Color iconColor = Colors.grey.shade700; // Default color

    if (filter == _selectedFilter) {
      iconColor =
          Theme.of(context).primaryColor; // Use primary color for selected item
    }

    switch (filter) {
      case 'Tourist Spots':
        iconData = Icons.landscape_outlined;
        break;
      case 'Business Establishments':
        iconData = Icons.store_outlined;
        break;
      case 'Accommodations':
        iconData = Icons.hotel_outlined;
        break;
      case 'Transport Terminals':
        iconData = Icons.directions_bus_outlined;
        break;
      case 'Agencies and Offices':
        iconData = Icons.corporate_fare_outlined;
        break;
      default: // For 'All'
        iconData = Icons.map_outlined;
    }
    return Icon(iconData, color: iconColor);
  }

  Widget _buildNavigationPanel() {
    switch (_panelState) {
      case NavigationPanelState.expanded:
        return _buildExpandedPanel();
      case NavigationPanelState.minimized:
        return _buildMinimizedPanel();
      case NavigationPanelState.hidden:
        return const SizedBox.shrink(); // An empty widget
    }
  }

  /// The small, minimized panel at the bottom-left of the screen
  Widget _buildMinimizedPanel() {
    if (_navigationDetails == null) return const SizedBox.shrink();

    // Using Align for cleaner positioning
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap:
                () =>
                    setState(() => _panelState = NavigationPanelState.expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Keep the card compact
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETA: ${_navigationDetails!["duration"]}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text('Show details'),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Close button is now outside the tap area for details
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.red,
                    onPressed: _endNavigation,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The full-details panel sliding up from the bottom
  /// The full-details panel sliding up from the bottom (Detailed Layout)
  Widget _buildExpandedPanel() {
    if (_navigationDetails == null) return const SizedBox.shrink();

    // Define your custom theme color for easy reuse
    final Color themeColor = const Color(0xFF3A6A55);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Route Details",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 28,
                  ),
                  onPressed:
                      () => setState(
                        () => _panelState = NavigationPanelState.minimized,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.location_on,
                color: themeColor,
              ), // Use theme color
              title: const Text(
                "Destination",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _navigationDetails!["endAddress"] ?? "Loading address...",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRouteLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    color: themeColor,
                  ), // Use theme color
                ),
              )
            else
              Row(
                children: [
                  _buildInfoChip(Icons.map, _liveDistance),
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.timer, _liveDuration),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildModeButton(
                  "Driving",
                  Icons.directions_car,
                  "driving",
                  _updateRoute,
                ),
                _buildModeButton(
                  "Walking",
                  Icons.directions_walk,
                  "walking",
                  _updateRoute,
                ),
                _buildModeButton(
                  "Cycling",
                  Icons.directions_bike,
                  "bicycling",
                  _updateRoute,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _endNavigation,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    // Change the text based on the mode
                    child: Text(
                      _isCustomRoutePreview ? "Clear Route" : "Cancel",
                    ),
                  ),
                ),

                // Only show the "Start" button if this is NOT a custom route preview
                if (!_isCustomRoutePreview) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _enterLiveNavigation,
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text("Start"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the small mode icons

  // Helper for the Distance and Duration chips
  Widget _buildInfoChip(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Refactored travel mode button
  Widget _buildModeButton(
    String label,
    IconData icon,
    String mode,
    Function(String) onPressed,
  ) {
    final bool isSelected = _currentTravelMode == mode;
    return Column(
      children: [
        InkWell(
          onTap: () => onPressed(mode),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[200],
              shape: BoxShape.circle,
              border:
                  isSelected
                      ? Border.all(color: Colors.blueAccent, width: 2)
                      : null,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black54,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle, // Match the shape of the CircleAvatar
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        radius: 24,
        child: IconButton(
          icon: Icon(icon, color: Colors.black87),
          onPressed: onPressed,
        ),
      ),
    );
  }

  // REPLACE your _buildProfileButton with this cleaner version
  Widget _buildProfileButton({required VoidCallback onPressed}) {
    final photoUrl = _userData?['profilePictureUrl'];
    final fullName = _userData?['fullName'] ?? '';

    Widget avatarContent; // This will hold the specific avatar

    if (photoUrl != null && photoUrl.isNotEmpty) {
      // Case 1: User has a profile picture
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade300,
        // --- CHANGE THIS LINE ---
        backgroundImage: CachedNetworkImageProvider(photoUrl),
      );
    } else if (fullName.isNotEmpty) {
      // Case 2: No picture, but has a name
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          fullName[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      // Case 3: No data at all
      avatarContent = CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade400,
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    // Now, wrap the final avatarContent in the shadow container and gesture detector
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(onTap: onPressed, child: avatarContent),
    );
  }

  // REPLACE your _buildMapStyleButton with this
  Widget _buildMapStyleButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        radius: 24,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.layers, color: Colors.black87),
          onSelected: (value) {
            switch (value) {
              case 'Default':
                _setMapStyle('map_style.json');
                break;
              case 'Clean':
                _setMapStyle('clean.json');
                break;
              case 'Tourism':
                _setMapStyle('tourism.json');
                break;
            }
          },
          itemBuilder:
              (context) => const [
                PopupMenuItem(value: 'Default', child: Text('Default')),
                PopupMenuItem(value: 'Clean', child: Text('Clean')),
                PopupMenuItem(value: 'Tourism', child: Text('Tourism')),
              ],
        ),
      ),
    );
  }

  Widget _buildLiveNavigationUI() {
    return Stack(
      children: [
        // You can add a top panel for turn-by-turn instructions here in the future
        _buildNavigationInfoBar(),
      ],
    );
  }

  // Add this new helper widget to your _MapScreenState
  Widget _buildNavigationInfoBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ETA and Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _liveDuration, // Live duration
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'ETA: $_liveEta', // Live ETA
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ],
              ),

              // Distance
              Text(
                _liveDistance, // Live distance
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Exit Button
              ElevatedButton(
                onPressed: _exitLiveNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADD THIS WIDGET INSIDE YOUR _MapScreenState
  Widget _buildLocationButton() {
    IconData icon;
    Color iconColor = Colors.grey.shade700;
    Color backgroundColor = Colors.white;

    switch (_locationButtonState) {
      case LocationButtonState.centered:
        icon = Icons.my_location;
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.compass:
        icon = Icons.explore; // Compass icon
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.navigating:
        icon = Icons.navigation_rounded;
        iconColor = Colors.white;
        backgroundColor = Colors.blue;
        break;
      case LocationButtonState.offCenter:
        icon = Icons.my_location;
        break;
    }

    return FloatingActionButton(
      heroTag: 'location_button',
      onPressed: _goToMyLocation,
      backgroundColor: backgroundColor,
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildClearRouteButton() {
    return FloatingActionButton.small(
      // A smaller FAB is less intrusive
      heroTag: 'clear_route_button',
      onPressed:
          _endNavigation, // Your existing function already does everything we need!
      backgroundColor: Colors.white,
      child: Icon(Icons.close, color: Colors.grey.shade700),
    );
  }

  Widget _buildClearItineraryButton() {
    return FloatingActionButton.small(
      heroTag: 'clear_itinerary_button',
      onPressed: _endNavigation, // This button's only job is to clean up
      backgroundColor: Colors.white,
      child: Icon(Icons.close, color: Colors.grey.shade700),
    );
  }

  Widget _buildItinerarySummaryPanel() {
    if (_itinerarySummary == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.all(12.0),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                "Day's Itinerary",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _itinerarySummary!['duration']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.map_outlined, size: 20, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _itinerarySummary!['distance']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
