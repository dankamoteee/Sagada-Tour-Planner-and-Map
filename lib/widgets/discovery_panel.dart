import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'poi_card.dart';

class DiscoveryPanel extends StatefulWidget {
  final Function(Map<String, dynamic> poiData) onPoiSelected;

  const DiscoveryPanel({super.key, required this.onPoiSelected});

  @override
  State<DiscoveryPanel> createState() => _DiscoveryPanelState();
}

class _DiscoveryPanelState extends State<DiscoveryPanel> {
  // --- New State Variable ---
  bool _isExpanded = false; // Manages the collapsed/expanded state

  List<Map<String, dynamic>> _popularPois = [];
  final List<Map<String, dynamic>> _nearbyPois = [];
  bool _isLoadingPopular = true;
  bool _isLoadingNearby = true;
  bool _hasFetchedData = false; // Prevents re-fetching on every expand

  // --- Changed initState ---
  // We'll now fetch data only when the panel is first expanded.
  @override
  void initState() {
    super.initState();
    // Data fetching will be triggered on first expansion
  }

  void _fetchDataIfNeeded() {
    if (!_hasFetchedData) {
      _fetchPopularPois();
      _fetchNearbyPois();
      _hasFetchedData = true;
    }
  }

  // (The _fetchPopularPois and _fetchNearbyPois methods remain the same as before)
  Future<void> _fetchPopularPois() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('POIs')
              .where('recommended', isEqualTo: true)
              .get();

      // --- MODIFY THIS PART ---
      final pois =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final coords = data['coordinates'] as GeoPoint?;
            return {
              'id': doc.id,
              ...data,
              'lat': coords?.latitude, // Add lat
              'lng': coords?.longitude, // Add lng
            };
          }).toList();
      // --- END OF MODIFICATION ---

      if (mounted) {
        setState(() {
          _popularPois = pois;
          _isLoadingPopular = false;
        });
      }
    } catch (e) {
      print("Error fetching popular POIs: $e");
      if (mounted) setState(() => _isLoadingPopular = false);
    }
  }

  Future<void> _fetchNearbyPois() async {
    // ... (no changes to this method)
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final snapshot =
          await FirebaseFirestore.instance.collection('POIs').get();
      List<Map<String, dynamic>> poisWithDistance = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final coords = data['coordinates'] as GeoPoint?;

        if (coords != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            coords.latitude,
            coords.longitude,
          );

          if (distanceInMeters <= 5000) {
            data['id'] = doc.id;
            data['distance'] = distanceInMeters;
            data['lat'] = coords.latitude; // Add lat
            data['lng'] = coords.longitude; // Add lng
            poisWithDistance.add(data);
          }
        }
      }
      // --- END OF MODIFICATION ---

      // ... (sort and set state)
    } catch (e) {
      print("Error fetching nearby POIs: $e");
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  // In discovery_panel.dart -> _buildPoiCarousel() method

  Widget _buildPoiCarousel(List<Map<String, dynamic>> pois, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pois.isEmpty) {
      return const Center(child: Text("No spots found."));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      // ADD THIS PADDING:
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      itemCount: pois.length,
      itemBuilder: (context, index) {
        final poi = pois[index];
        // We add a simple SizedBox here for spacing between cards
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PoiCard(poiData: poi, onTap: () => widget.onPoiSelected(poi)),
        );
      },
    );
  }

  // --- The build method is completely replaced ---
  // In discovery_panel.dart
  // Replace the entire build method with this final version.

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded ? 280 : 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRect(
        child: Column(
          children: [
            // The Pull Tab (no changes here)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
                if (_isExpanded) {
                  _fetchDataIfNeeded();
                }
              },
              child: Container(
                height: 65,
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Discover Places',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // The content area now uses a LayoutBuilder
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // This is the key: only build the content if the parent
                  // (the Expanded widget) has grown to a reasonable height.
                  // We check for 50px as a safe minimum.
                  if (constraints.maxHeight < 50) {
                    // While animating and space is small, render nothing.
                    return const SizedBox.shrink();
                  }

                  // Once enough space is available, fade the content in.
                  return AnimatedOpacity(
                    opacity: _isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: "Popular in Sagada"),
                              Tab(text: "Nearby"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildPoiCarousel(
                                  _popularPois,
                                  _isLoadingPopular,
                                ),
                                _buildPoiCarousel(
                                  _nearbyPois,
                                  _isLoadingNearby,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
