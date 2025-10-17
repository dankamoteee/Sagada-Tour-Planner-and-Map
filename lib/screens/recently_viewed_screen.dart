import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class RecentlyViewedScreen extends StatelessWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final Color themeColor = const Color(0xFF3A6A55);

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Recently Viewed"),
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text("Please log in to see your history.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // --- NEW SLIVER APP BAR ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Recently Viewed",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/recent_background.webp', // The background image for the button
                    fit: BoxFit.cover,
                  ),
                  // Gradient for text readability
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

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('recentlyViewed')
                      .orderBy('viewedAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const _EmptyState();
                }

                final viewedItems = snapshot.data!.docs;

                // Using GridView directly inside the body
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: viewedItems.length,
                  shrinkWrap: true, // Important for nesting scrollables
                  physics:
                      const NeverScrollableScrollPhysics(), // Important for nesting scrollables
                  itemBuilder: (context, index) {
                    final item =
                        viewedItems[index].data() as Map<String, dynamic>;
                    return _GridItemCard(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ... _GridItemCard and _EmptyState widgets remain the same

// A custom widget for each grid item to keep the build method clean
class _GridItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _GridItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final String name = item['name'] ?? 'Unknown Place';
    final String? imageUrl = item['imageUrl'];
    final Timestamp? timestamp = item['viewedAt'];
    final String viewedAgo =
        timestamp != null ? timeago.format(timestamp.toDate()) : 'a while ago';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
            )
          else
            Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.place, size: 40, color: Colors.white),
            ),

          // Gradient Overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                stops: const [0.5, 1.0],
              ),
            ),
          ),

          // Text Content
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  viewedAgo,
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
              ],
            ),
          ),

          // Ripple effect for the whole card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Handle tap to view POI details on the map
              },
            ),
          ),
        ],
      ),
    );
  }
}

// A custom widget for the "empty" message to make it look nicer
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No Recent Views",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Places you view will appear here.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
