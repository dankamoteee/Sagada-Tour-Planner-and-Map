import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'itinerary_detail_screen.dart';

class ItinerariesListScreen extends StatelessWidget {
  const ItinerariesListScreen({super.key});

  Future<void> _createNewItinerary(BuildContext context, String userId) async {
    final TextEditingController nameController = TextEditingController();
    final String? newName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('New Itinerary'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: "e.g., 'Family Vacation'",
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Create'),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    Navigator.of(context).pop(nameController.text);
                  }
                },
              ),
            ],
          ),
    );

    if (newName != null && newName.isNotEmpty) {
      final newItineraryRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('itineraries')
          .add({
            'name': newName,
            'createdAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => ItineraryDetailScreen(
                  itineraryId: newItineraryRef.id,
                  itineraryName: newName,
                ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color themeColor = Theme.of(context).primaryColor;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Itineraries')),
        body: const Center(
          child: Text("Please log in to view your itineraries."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      // --- START OF LAYOUT CHANGES ---
      body: CustomScrollView(
        slivers: [
          // 1. Copied SliverAppBar from your RecentlyViewedScreen
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "My Itineraries",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/itinerary_background.jpg', // Use the same background image
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
          ),
          // 2. Body content is now inside a SliverToBoxAdapter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The Upcoming Event Card
                  _UpcomingEventCard(userId: user.uid),
                  const SizedBox(height: 24),

                  // The List of All Itineraries
                  const Text(
                    'All Plans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('itineraries')
                            .orderBy('lastModified', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const _EmptyState();
                      }

                      return ListView.builder(
                        padding:
                            EdgeInsets.zero, // Padding is handled by the parent
                        shrinkWrap: true, // Crucial for nested lists
                        physics:
                            const NeverScrollableScrollPhysics(), // Crucial for nested lists
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _ItineraryListCard(
                            itineraryData: data,
                            itineraryId: doc.id,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // --- END OF LAYOUT CHANGES ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _createNewItinerary(context, user.uid);
        },
        label: const Text('New Itinerary'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_calendar_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No Itineraries Found",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Tap the '+' button to create your first plan.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET FOR THE UPCOMING EVENT CARD ---
class _UpcomingEventCard extends StatelessWidget {
  final String userId;
  const _UpcomingEventCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: StreamBuilder<QuerySnapshot>(
        // This is a "Collection Group Query" - it searches across all 'events' subcollections for this user.
        stream:
            FirebaseFirestore.instance
                .collectionGroup('events')
                .where('userId', isEqualTo: userId)
                .where('eventTime', isGreaterThan: Timestamp.now())
                .orderBy('eventTime')
                .limit(1)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListTile(
              leading: Icon(
                Icons.wb_sunny_outlined,
                color: Colors.orange.shade700,
              ),
              title: const Text(
                'No upcoming plans!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Your schedule is free.'),
            );
          }

          final event =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final eventTime = (event['eventTime'] as Timestamp).toDate();

          return Container(
            color: Theme.of(context).primaryColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 30,
              ),
              title: Text(
                'Up Next: ${event['destinationPoiName'] ?? 'Event'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Today at ${DateFormat.jm().format(eventTime)} (${timeago.format(eventTime)})',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- WIDGET FOR EACH ITINERARY IN THE LIST ---
class _ItineraryListCard extends StatelessWidget {
  final Map<String, dynamic> itineraryData;
  final String itineraryId; // We need the ID to pass it

  const _ItineraryListCard({
    required this.itineraryData,
    required this.itineraryId,
  });

  @override
  Widget build(BuildContext context) {
    final modified = (itineraryData['lastModified'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(
          itineraryData['name'] ?? 'My Itinerary',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Last updated: ${modified != null ? timeago.format(modified) : 'N/A'}',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          // 1. Await the result from the detail screen
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => ItineraryDetailScreen(
                    itineraryId: itineraryId,
                    itineraryName: itineraryData['name'] ?? 'My Itinerary',
                  ),
            ),
          );

          // 2. Check if the result is a list (our coordinates)
          if (result is List<GeoPoint>) {
            // If it is, pop THIS screen and pass the coordinates back to the map
            if (context.mounted) {
              Navigator.pop(context, result);
            }
          }
          // Handle the string message for deletion confirmation
          else if (result is String && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }
}
