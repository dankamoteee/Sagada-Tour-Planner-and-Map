import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'recently_viewed_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData; // <-- ADD THIS
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userData, // <-- ADD THIS
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // Define your custom theme color
  final Color themeColor = const Color(0xFF3A6A55);

  // --- ADD THIS ---
  late Map<String, dynamic> _userData;

  @override
  void initState() {
    super.initState();
    // Initialize the state variable from the widget property
    _userData = widget.userData;
  }
  // --- END ADD ---

  Future<void> _changeProfilePicture() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    // Set loading state
    if (mounted) setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(widget.userId)
          .child('profile.jpg');

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      // --- ADD THIS ---
      // Clear the old image from the cache
      await DefaultCacheManager().removeFile(url);
      // --- END ADD ---

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'profilePictureUrl': url}, SetOptions(merge: true));

      // --- ADD THIS TO UPDATE THE UI ---
      if (mounted) {
        setState(() {
          _userData['profilePictureUrl'] = url; // Update the local data
          _isUploading = false; // Stop loading
        });
      }
      // --- END ADD ---
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
        // Ensure loading stops on error
        setState(() => _isUploading = false);
      }
    }
    // We no longer need the 'finally' block as setState is handled in 'try' and 'catch'
  }

  @override
  Widget build(BuildContext context) {
    // The data now comes directly from the widget, not a stream
    final userData = _userData;

    // All your variable declarations are the same
    final String fullName = userData['fullName'] ?? 'No Name';
    final String username = userData['username'] ?? 'no_username';
    final String email = userData['email'] ?? 'No email';
    final String phone = userData['phone'] ?? 'No phone number';
    final String? photoUrl = userData['profilePictureUrl'];
    final Timestamp createdAt = userData['createdAt'] ?? Timestamp.now();
    final String memberSince = DateFormat(
      'MMMM d, yyyy',
    ).format(createdAt.toDate());

    // The Scaffold and CustomScrollView are the same, just without the StreamBuilder
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: themeColor, // Use custom color
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/profile_background.avif',
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
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor:
                                Colors
                                    .grey
                                    .shade300, // This is your placeholder color
                            child: ClipOval(
                              // Clip the image to a circle
                              child:
                                  (photoUrl != null && photoUrl.isNotEmpty)
                                      ? CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        fit: BoxFit.cover,
                                        width: 92, // 46 * 2
                                        height: 92, // 46 * 2
                                        // Show this while loading
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey.shade300,
                                            ),
                                        // This is your old 'child' logic
                                        errorWidget:
                                            (context, url, error) => const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                      )
                                      // This is if photoUrl is null or empty
                                      : const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _changeProfilePicture,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child:
                                    _isUploading
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Icon(
                                          Icons.edit,
                                          color: themeColor,
                                          size: 20,
                                        ), // Use custom color
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildInfoCard(
                context,
                title: "User Details",
                children: [
                  _buildDetailRow(Icons.person_outline, "Username", username),
                  _buildDetailRow(Icons.email_outlined, "Email", email),
                  _buildDetailRow(Icons.phone_outlined, "Phone", phone),
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    "Member Since",
                    memberSince,
                  ),
                ],
              ),
              _buildInfoCard(
                context,
                title: "My Activities",
                children: [
                  _buildActionRow("My Itinerary", Icons.list_alt_outlined, () {
                    // TODO: Navigate to Itinerary Screen
                  }),
                  _buildActionRow(
                    "Recently Viewed",
                    Icons.history_outlined,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecentlyViewedScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  onPressed: () async {
                    final bool? shouldLogout = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Confirm Sign Out'),
                            content: const Text(
                              'Are you sure you want to sign out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                    );
                    if (shouldLogout == true) {
                      await FirebaseAuth.instance.signOut();
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      }
                    }
                  },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ), // Use custom color
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: themeColor), // Use custom color
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
