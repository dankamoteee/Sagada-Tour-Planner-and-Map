// In lib/screens/itinerary_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  bool _isLoading = true;
  Map<int, List<Map<String, dynamic>>> _daysData = {};

  @override
  void initState() {
    super.initState();
    _fetchItinerary();
  }

  Future<void> _fetchItinerary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    const String itineraryId = 'main_trip';
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(itineraryId)
            .collection('days')
            .orderBy('dayNumber')
            .get();

    if (snapshot.docs.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final Map<int, List<Map<String, dynamic>>> tempData = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dayNumber = data['dayNumber'] as int;

      // We need to fetch the image URL for each POI
      final pois = List<Map<String, dynamic>>.from(data['pois'] ?? []);
      final enrichedPois = <Map<String, dynamic>>[];

      for (var poiMap in pois) {
        final poiDoc =
            await FirebaseFirestore.instance
                .collection('POIs')
                .doc(poiMap['poiId'])
                .get();
        if (poiDoc.exists) {
          final poiData = poiDoc.data()!;
          final images = poiData['images'] as List?;
          poiMap['imageUrl'] =
              (images != null && images.isNotEmpty)
                  ? images[0]
                  : poiData['imageUrl'];
        }
        enrichedPois.add(poiMap);
      }

      enrichedPois.sort(
        (a, b) => (a['order'] as int).compareTo(b['order'] as int),
      );
      tempData[dayNumber] = enrichedPois;
    }

    if (mounted) {
      setState(() {
        _daysData = tempData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayKeys = _daysData.keys.toList()..sort();
    final Color themeColor = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: dayKeys.isEmpty ? 1 : dayKeys.length,
      child: Scaffold(
        body:
            _isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        expandedHeight: 220.0,
                        pinned: true,
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            "My Itinerary",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/itinerary_background.jpg', // Use the same background
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        bottom:
                            dayKeys.isEmpty
                                ? null
                                : TabBar(
                                  tabs:
                                      dayKeys
                                          .map(
                                            (dayNum) =>
                                                Tab(text: 'Day $dayNum'),
                                          )
                                          .toList(),
                                ),
                      ),
                    ];
                  },
                  body:
                      dayKeys.isEmpty
                          ? const _EmptyState()
                          : TabBarView(
                            children:
                                dayKeys.map((dayNum) {
                                  final pois = _daysData[dayNum]!;
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(8.0),
                                    itemCount: pois.length,
                                    itemBuilder: (context, index) {
                                      final poi = pois[index];
                                      return _ItineraryPoiCard(
                                        poi: poi,
                                        index: index,
                                      );
                                    },
                                  );
                                }).toList(),
                          ),
                ),
      ),
    );
  }
}

// --- NEW WIDGETS FOR THIS SCREEN ---

class _ItineraryPoiCard extends StatelessWidget {
  final Map<String, dynamic> poi;
  final int index;

  const _ItineraryPoiCard({required this.poi, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background Image
          if (poi['imageUrl'] != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: poi['imageUrl'],
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.4), // Darken the image
                colorBlendMode: BlendMode.darken,
              ),
            ),

          // Content
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              poi['poiName'] ?? 'Unknown POI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                shadows: [Shadow(blurRadius: 2.0)],
              ),
            ),
            // We'll add the reorder and delete buttons here in the next step
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_calendar_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Your Itinerary is Empty",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Add places from the map to build your plan.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
