import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

// 1. The Data Model for your Hotline
// This makes your code cleaner and safer than using raw Maps.
class Hotline {
  final String agencyName;
  final String imageUrl; // This will hold the base64 string
  final String phone;
  final String address;

  Hotline({
    required this.agencyName,
    required this.imageUrl,
    required this.phone,
    required this.address,
  });

  factory Hotline.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Hotline(
      agencyName: data['agencyName'] ?? 'Unknown Agency',
      imageUrl: data['imageUrl'] ?? '',
      phone: data['phone'] ?? 'No number',
      address: data['address'] ?? 'No address',
    );
  }
}

// 2. The Main Screen Widget
class HotlineScreen extends StatefulWidget {
  const HotlineScreen({super.key});

  @override
  State<HotlineScreen> createState() => _HotlineScreenState();
}

class _HotlineScreenState extends State<HotlineScreen> {
  //late Future<List<Hotline>> _hotlinesFuture;
  List<Hotline> _allHotlines = [];
  late Future<void> _fetchFuture; // This will now just manage loading state

  @override
  void initState() {
    super.initState();
    // The future now just triggers the fetch
    _fetchFuture = _fetchHotlines();
  }

  Future<void> _saveAllContacts() async {
    // 1. Request permission directly from the package
    if (await FlutterContacts.requestPermission()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saving contacts...')));

      int savedCount = 0;
      for (var hotline in _allHotlines) {
        try {
          final newContact =
              Contact()
                ..name.first = hotline.agencyName
                ..phones = [Phone(hotline.phone)];

          await newContact.insert();
          savedCount++;
        } catch (e) {
          print('Error saving contact ${hotline.agencyName}: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount hotline numbers saved successfully!'),
        ),
      );
    } else {
      // 2. Handle permission denial
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied. Cannot save contacts.'),
        ),
      );
    }
  }

  // Fetches data from Firestore and converts it to a list of Hotline objects
  Future<void> _fetchHotlines() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('Hotline').get();

    final hotlines =
        querySnapshot.docs.map((doc) => Hotline.fromFirestore(doc)).toList();

    hotlines.sort((a, b) => a.agencyName.compareTo(b.agencyName));

    // Save the fetched and sorted list to the state variable
    setState(() {
      _allHotlines = hotlines;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _fetchFuture,
        builder: (context, snapshot) {
          // Show a loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show an error message
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // The main layout is now a CustomScrollView
          return CustomScrollView(
            slivers: [
              // 1. The Collapsing App Bar
              SliverAppBar(
                pinned: true,
                expandedHeight: 220.0,
                backgroundColor: const Color(0xFF3A6A55),
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: const Text(
                    'Sagada Hotlines',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/hotline_background.jpg',
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

              // 2. The List of Hotline Cards (now using the state variable)
              _allHotlines.isEmpty
                  ? SliverFillRemaining(
                    child: const Center(
                      child: Text('No hotline numbers found.'),
                    ),
                  )
                  : SliverList.builder(
                    itemCount: _allHotlines.length,
                    itemBuilder: (context, index) {
                      return HotlineCard(hotline: _allHotlines[index]);
                    },
                  ),
            ],
          );
        },
      ),
      // --- ADD THIS FLOATING ACTION BUTTON ---
      floatingActionButton:
          _allHotlines.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: _saveAllContacts,
                label: const Text('Save All to Contacts'),
                icon: const Icon(Icons.contact_phone),
                backgroundColor: const Color(0xFF3A6A55),
                foregroundColor: const Color.fromARGB(255, 255, 255, 255),
              )
              : null, // Hide the button if there are no hotlines
    );
  }
}

// 3. The Widget for Each Card in the List (REVAMPED)
class HotlineCard extends StatelessWidget {
  final Hotline hotline;

  const HotlineCard({super.key, required this.hotline});

  // Function to handle making a phone call
  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(launchUri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not call $phoneNumber')));
    }
  }

  // Helper to decode the base64 image string
  Uint8List? _decodeBase64Image(String base64String) {
    try {
      final String imageOnly = base64String.split(',').last;
      return base64Decode(imageOnly);
    } catch (e) {
      print("Error decoding base64 image: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _decodeBase64Image(hotline.imageUrl);

    // Using ListTile provides excellent, consistent padding and alignment
    return Card(
      elevation: 3,
      clipBehavior:
          Clip.antiAlias, // Ensures InkWell ripple stays within the rounded corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _makePhoneCall(hotline.phone, context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Side: Logo
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey.shade200,
                child:
                    imageBytes != null
                        ? ClipOval(
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          ),
                        )
                        : const Icon(Icons.business, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // Middle: Agency Name, Phone, and Address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotline.agencyName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6), // Increased spacing
                    Text(
                      hotline.phone,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (hotline.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 5.0,
                        ), // Increased spacing
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                hotline.address,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right Side: Speed Dial Icon (acts as a visual cue)
              Icon(
                Icons.phone,
                size: 28,
                color: const Color(0xFF3A6A55), // Your theme color
              ),
            ],
          ),
        ),
      ),
    );
  }
}
