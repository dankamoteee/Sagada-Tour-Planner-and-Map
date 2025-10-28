import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_editor_screen.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final String itineraryId;
  final String itineraryName;

  const ItineraryDetailScreen({
    super.key,
    required this.itineraryId,
    required this.itineraryName,
  });

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  // --- FUNCTION TO DELETE AN EVENT ---
  Future<void> _deleteEvent(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.itineraryId)
        .collection('events')
        .doc(eventId)
        .delete();
  }

  // --- FUNCTION TO REORDER EVENTS ---
  Future<void> _onReorder(
    List<DocumentSnapshot> events,
    int oldIndex,
    int newIndex,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Adjust index for items moved down the list
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Move the item in the list
    final item = events.removeAt(oldIndex);
    events.insert(newIndex, item);

    // Create a batch write to update all 'order' fields in Firestore at once
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < events.length; i++) {
      final docRef = events[i].reference;
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  // --- ADD THIS NEW FUNCTION ---
  Future<void> _deleteEntireItinerary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Show a confirmation dialog with a strong warning
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Itinerary?'),
            content: Text(
              'Are you sure you want to permanently delete "${widget.itineraryName}" and all of its events? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Permanently'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    );

    if (didConfirm == true) {
      // Show a loading indicator while deleting
      showDialog(
        context: context,
        builder: (context) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      try {
        // 2. Use a WriteBatch to delete all documents at once
        final batch = FirebaseFirestore.instance.batch();

        final itineraryRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(widget.itineraryId);

        // Get all events in the subcollection to delete them
        final eventsSnapshot = await itineraryRef.collection('events').get();
        for (final doc in eventsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        // Delete the main itinerary document itself
        batch.delete(itineraryRef);

        // 3. Commit all the deletions
        await batch.commit();

        // 4. Pop both the loading dialog and the detail screen
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          Navigator.pop(
            context,
            'Successfully deleted "${widget.itineraryName}"!',
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete itinerary: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.itineraryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            // Make sure onPressed calls your new function
            onPressed: _deleteEntireItinerary,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('itineraries')
                .doc(widget.itineraryId)
                .collection('events')
                .orderBy(
                  'eventTime',
                ) // Crucial: Sort by time to group correctly
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No plans yet. Add your first event!'),
            );
          }

          // Group events by day
          // --- NEW GROUPING LOGIC ---
          final Map<DateTime, List<DocumentSnapshot>> eventsByDate = {};
          for (var doc in snapshot.data!.docs) {
            final eventTime = (doc['eventTime'] as Timestamp).toDate();
            // Normalize the date to midnight to use it as a key
            final dateKey = DateTime(
              eventTime.year,
              eventTime.month,
              eventTime.day,
            );

            if (!eventsByDate.containsKey(dateKey)) {
              eventsByDate[dateKey] = [];
            }
            eventsByDate[dateKey]!.add(doc);
          }

          final sortedDates = eventsByDate.keys.toList()..sort();

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final events = eventsByDate[date]!;
              final dayNumber = index + 1; // "Day 1", "Day 2", etc.

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- START OF CHANGES ---
                    // Day Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header Text
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            'Day $dayNumber - ${DateFormat.yMMMEd().format(date)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Show on Map Button
                        TextButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Show on Map'),
                          // --- START OF FIX ---
                          onPressed: () async {
                            // Show a loading indicator since this involves database reads
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                            );

                            final List<GeoPoint> coordinates = [];
                            // 1. Loop through each event for the day
                            for (final eventDoc in events) {
                              final event =
                                  eventDoc.data() as Map<String, dynamic>;
                              final poiId =
                                  event['destinationPoiId'] as String?;

                              if (poiId != null) {
                                // 2. Use the ID to fetch the full POI document
                                final poiDoc =
                                    await FirebaseFirestore.instance
                                        .collection('POIs')
                                        .doc(poiId)
                                        .get();
                                if (poiDoc.exists) {
                                  // 3. Extract the coordinates and add them to our list
                                  final poiData = poiDoc.data()!;
                                  final coords =
                                      poiData['coordinates'] as GeoPoint?;
                                  if (coords != null) {
                                    coordinates.add(coords);
                                  }
                                }
                              }
                            }

                            // Dismiss the loading indicator
                            if (context.mounted) Navigator.pop(context);

                            // 4. Pop the screen and return the list of coordinates
                            if (context.mounted) {
                              Navigator.pop(context, coordinates);
                            }
                          },
                          // --- END OF FIX ---
                        ),
                      ],
                    ),

                    // Reorderable list for the day's events
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder:
                          (oldIndex, newIndex) =>
                              _onReorder(events, oldIndex, newIndex),
                      children:
                          events.map((eventDoc) {
                            final event =
                                eventDoc.data() as Map<String, dynamic>;
                            final eventTime =
                                (event['eventTime'] as Timestamp).toDate();

                            return Dismissible(
                              key: ValueKey(eventDoc.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _deleteEvent(eventDoc.id),
                              background: Container(
                                color: Colors.red.shade400,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              child: ListTile(
                                leading: Text(
                                  DateFormat.jm().format(eventTime),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                onTap: () async {
                                  // 1. Await the result from the editor screen
                                  final result = await Navigator.of(
                                    context,
                                  ).push(
                                    MaterialPageRoute(
                                      builder:
                                          (context) => EventEditorScreen(
                                            itineraryId: widget.itineraryId,
                                            eventDoc:
                                                eventDoc, // Pass the event data for editing
                                          ),
                                    ),
                                  );

                                  // 2. If we get a message back, show it in a SnackBar
                                  if (result is String && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result),
                                        backgroundColor:
                                            result.contains('deleted')
                                                ? Colors.red
                                                : Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // --- UPDATE THIS ---
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => EventEditorScreen(
                    itineraryId: widget.itineraryId, // Pass the itinerary ID
                  ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
