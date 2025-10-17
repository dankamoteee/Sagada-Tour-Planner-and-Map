import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// 1. Data Model for a Tour Guide
class TourGuide {
  final String name;
  final String org;
  final String phone;
  final String email;
  final String imageUrl;
  final List<String> areas;

  TourGuide({
    required this.name,
    required this.org,
    required this.phone,
    required this.email,
    required this.imageUrl,
    required this.areas,
  });

  factory TourGuide.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TourGuide(
      name: data['name'] ?? 'No Name',
      org: data['org'] ?? 'No Organization',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      imageUrl: data['image'] ?? '', // Assumes field is named 'image'
      areas: List<String>.from(
        data['area'] is List ? data['area'] : [data['area']],
      ), // Handles both string and array
    );
  }
}

// 2. The Main Screen Widget
class TourGuidesScreen extends StatefulWidget {
  const TourGuidesScreen({super.key});

  @override
  State<TourGuidesScreen> createState() => _TourGuidesScreenState();
}

class _TourGuidesScreenState extends State<TourGuidesScreen> {
  // State variables
  List<TourGuide> _allGuides = [];
  List<TourGuide> _displayedGuides = [];
  List<String> _organizations = ['All'];
  String _selectedOrg = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndPrepareGuides();
    _searchController.addListener(_updateDisplayedGuides);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPrepareGuides() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('tourGuides')
              // Optional: You can add .where('isActive', isEqualTo: true) here
              .get();

      final guides =
          querySnapshot.docs
              .map((doc) => TourGuide.fromFirestore(doc))
              .toList();

      // Shuffle the list for randomness
      guides.shuffle();

      // Get unique organization names for the filter chips
      final orgs = guides.map((guide) => guide.org).toSet().toList();
      orgs.sort();

      setState(() {
        _allGuides = guides;
        _displayedGuides = guides;
        _organizations = ['All', ...orgs];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching tour guides: $e')));
    }
  }

  void _updateDisplayedGuides() {
    List<TourGuide> filteredGuides = List.from(_allGuides);

    // 1. Filter by selected organization
    if (_selectedOrg != 'All') {
      filteredGuides =
          filteredGuides.where((guide) => guide.org == _selectedOrg).toList();
    }

    // 2. Filter by search query
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredGuides =
          filteredGuides.where((guide) {
            return guide.name.toLowerCase().contains(searchQuery);
          }).toList();
    }

    setState(() {
      _displayedGuides = filteredGuides;
    });
  }

  // Replace the entire _showGuideDetailsDialog method with this one
  void _showGuideDetailsDialog(BuildContext context, TourGuide guide) {
    // Helper function for launching URLs (call, email)
    Future<void> launchUrlHelper(Uri url) async {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch ${url.scheme}')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(0),
          // Added elevation for a stronger shadow
          elevation: 10,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Header with Image and Name ---
                // THIS IS THE REVAMPED HEADER
                Container(
                  width: double.infinity,
                  height: 180, // Set a fixed height for the image header
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image:
                          guide.imageUrl.isNotEmpty
                              ? NetworkImage(guide.imageUrl) as ImageProvider
                              : const AssetImage(
                                'assets/placeholder_person.png',
                              ), // Provide a local asset placeholder
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(
                          0.4,
                        ), // Darken the image slightly
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Container(
                    // Gradient Overlay for text readability
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    alignment:
                        Alignment.bottomLeft, // Align text to the bottom left
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Make column take minimum space
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guide.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          guide.org,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Details List ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (guide.areas.isNotEmpty &&
                          guide.areas.first.isNotEmpty)
                        ListTile(
                          leading: const Icon(
                            Icons.map_outlined,
                            color: Color(0xFF3A6A55),
                          ),
                          title: const Text(
                            'Areas of Operation',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(guide.areas.join(", ")),
                        ),
                      if (guide.phone.isNotEmpty)
                        ListTile(
                          leading: const Icon(
                            Icons.phone_outlined,
                            color: Colors.blueAccent,
                          ),
                          title: const Text(
                            'Phone',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(guide.phone),
                          onTap: () {
                            final Uri phoneUri = Uri(
                              scheme: 'tel',
                              path: guide.phone,
                            );
                            launchUrlHelper(phoneUri);
                          },
                        ),
                      if (guide.email.isNotEmpty)
                        ListTile(
                          leading: const Icon(
                            Icons.email_outlined,
                            color: Colors.orangeAccent,
                          ),
                          title: const Text(
                            'Email',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(guide.email),
                          onTap: () {
                            final Uri emailUri = Uri(
                              scheme: 'mailto',
                              path: guide.email,
                            );
                            launchUrlHelper(emailUri);
                          },
                        ),
                      const SizedBox(height: 16),
                      // --- Action Buttons ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (guide.email.isNotEmpty)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.email),
                                  label: const Text('Email'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.orange, // Brighter orange
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    final Uri emailUri = Uri(
                                      scheme: 'mailto',
                                      path: guide.email,
                                    );
                                    launchUrlHelper(emailUri);
                                  },
                                ),
                              ),
                            ),
                          if (guide.phone.isNotEmpty)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Call'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF3A6A55,
                                    ), // Theme green
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    final Uri phoneUri = Uri(
                                      scheme: 'tel',
                                      path: guide.phone,
                                    );
                                    launchUrlHelper(phoneUri);
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The main layout is now a CustomScrollView, which works with slivers
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  // 1. The Collapsing App Bar (SliverAppBar)
                  SliverAppBar(
                    pinned:
                        true, // The app bar stays visible at the top when collapsed
                    expandedHeight:
                        220.0, // How tall the header is when fully expanded
                    backgroundColor: const Color(0xFF3A6A55),
                    foregroundColor: Colors.white,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: const Text(
                        'Tour Guides',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The background image
                          Image.asset(
                            'assets/images/tourguide_background.png', // <-- CHANGE TO YOUR IMAGE PATH
                            fit: BoxFit.cover,
                          ),
                          // The gradient overlay for text readability
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

                  // 2. The Search Bar (wrapped in SliverToBoxAdapter)
                  // This widget allows you to place a regular widget inside a CustomScrollView
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for a guide...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),
                  ),

                  // 3. The Filter Chips (also in SliverToBoxAdapter)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        itemCount: _organizations.length,
                        itemBuilder: (context, index) {
                          final org = _organizations[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: ChoiceChip(
                              label: Text(org),
                              selected: _selectedOrg == org,
                              onSelected: (isSelected) {
                                if (isSelected) {
                                  setState(() {
                                    _selectedOrg = org;
                                    if (org == 'All') {
                                      _allGuides.shuffle();
                                    }
                                  });
                                  _updateDisplayedGuides();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 4. The Grid of Guides (using SliverGrid)
                  // Use SliverPadding to add space around the grid
                  _displayedGuides.isEmpty
                      ? SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No tour guides found for your search.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                      : SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return TourGuideCard(
                              guide: _displayedGuides[index],
                              onTap:
                                  () => _showGuideDetailsDialog(
                                    context,
                                    _displayedGuides[index],
                                  ),
                            );
                          }, childCount: _displayedGuides.length),
                        ),
                      ),
                ],
              ),
    );
  }
}

// 4. The Card Widget for a single Tour Guide (REVAMPED)
class TourGuideCard extends StatelessWidget {
  final TourGuide guide;
  final VoidCallback onTap;

  const TourGuideCard({super.key, required this.guide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior:
          Clip.antiAlias, // Ensures the image respects the border radius
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Background Image
            if (guide.imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  guide.imageUrl,
                  fit: BoxFit.cover,
                  // Shows a loading indicator while the image loads
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  // Shows an icon if the image fails to load
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey,
                    );
                  },
                ),
              )
            else // Placeholder if no image
              Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
              ),

            // Gradient Overlay for text readability
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
            ),

            // Text Info
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    guide.org,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
