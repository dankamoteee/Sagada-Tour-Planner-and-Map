import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/profile_screen.dart';
import '../screens/recently_viewed_screen.dart';
import '../screens/hotline_screen.dart';
import '../screens/tour_guides_screen.dart';
import '../screens/itineraries_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileMenu extends StatelessWidget {
  // 1. Add a variable to hold the user data passed from the map screen
  final Map<String, dynamic>? userData;

  // 2. Update the constructor to accept this data
  const ProfileMenu({super.key, this.userData, required this.onDrawItinerary});
  final Function(List<GeoPoint>) onDrawItinerary; // Accept the function

  @override
  Widget build(BuildContext context) {
    // 3. Use the dynamic data, with fallbacks for when the user is not logged in
    final userPhotoUrl = userData?['profilePictureUrl'];
    final userName = userData?['fullName'] ?? 'Guest';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.75,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 1, height: 20),
              const SizedBox(height: 10),

              // Updated "Profile" button to navigate correctly
              _buildImageButton("Profile", "assets/images/profile_bg.png", () {
                Navigator.pop(context); // Close sheet before navigating
                if (userId != null && userData != null) {
                  // Check if userData is not null
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProfileScreen(
                            userId: userId,
                            userData: userData!, // <-- PASS THE DATA HERE
                          ),
                    ),
                  );
                }
              }),
              _buildImageButton(
                "My Itinerary",
                "assets/images/itinerary_bg.png",
                () async {
                  // Close the menu first
                  Navigator.of(context).pop();

                  // Navigate to the itinerary screen
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ItinerariesListScreen(),
                    ),
                  );

                  // Handle the returned result
                  if (result is List<GeoPoint>) {
                    onDrawItinerary(result); // Call your callback function
                  }
                },
              ),
              _buildImageButton(
                "Recently Viewed",
                "assets/images/recent_bg.png",
                () {
                  Navigator.pop(context); // Close the menu
                  // Navigate to the new screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecentlyViewedScreen(),
                    ),
                  );
                },
              ),
              _buildImageButton(
                "Tour Guides",
                "assets/images/tourguide_bg.png",
                () {
                  Navigator.pop(context); // Close the menu
                  Navigator.push(
                    // Navigate to the new screen
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TourGuidesScreen(),
                    ),
                  );
                },
              ),
              _buildImageButton(
                "Sagada Hotline Numbers",
                "assets/images/hotline_bg.png",
                () {
                  // First, close the profile menu
                  Navigator.pop(context);
                  // Then, navigate to the HotlineScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HotlineScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // AFTER
        Positioned(
          top: -50,
          left: 0,
          right: 0,
          child: Center(
            child: CircleAvatar(
              radius: 60,
              // 1. Background color is now conditional
              backgroundColor:
                  (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                      ? Colors
                          .white // White border for the image
                      : const Color(0xFF3A6A55), // Theme color for the initial
              backgroundImage:
                  (userPhotoUrl != null && userPhotoUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(
                        userPhotoUrl,
                      ) // <-- Changed to this
                      : null,
              // 2. Child logic now checks for the user's name
              child:
                  (userPhotoUrl == null || userPhotoUrl.isEmpty)
                      ? (userName.isNotEmpty && userName != 'Guest')
                          ? Text(
                            userName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          )
                      : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Helper widget for building the menu buttons with background images.
  /// This is the exact same method you had before, now part of this widget.
  Widget _buildImageButton(String text, String imagePath, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.3), // Dark overlay for text readability
            BlendMode.darken,
          ),
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
