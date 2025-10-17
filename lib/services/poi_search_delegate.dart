// In lib/services/poi_search_delegate.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poi_model.dart'; // Import your new model

class POISearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  // Your original highlight function - no changes needed here.
  Widget _highlightMatch(String text, String q, BuildContext context) {
    if (q.isEmpty) {
      // Use the default ListTile title style if there's no query
      return Text(text, style: Theme.of(context).textTheme.titleMedium);
    }

    final lowerText = text.toLowerCase();
    final lowerQ = q.toLowerCase();

    if (!lowerText.contains(lowerQ)) {
      return Text(text, style: Theme.of(context).textTheme.titleMedium);
    }

    final start = lowerText.indexOf(lowerQ);
    final end = start + q.length;

    // Get the default text styles from the current theme
    final defaultStyle =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    final highlightStyle = defaultStyle.copyWith(
      color:
          Theme.of(context).colorScheme.primary, // Use the app's primary color
      fontWeight: FontWeight.bold,
    );

    return RichText(
      text: TextSpan(
        style: defaultStyle, // Default style for all parts
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: highlightStyle),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }

  // Helper function to get an icon based on POI type
  Widget _getIconForType(String type) {
    IconData iconData;
    switch (type) {
      case 'Tourist Spots':
        iconData = Icons.landscape;
        break;
      case 'Business Establishments':
        iconData = Icons.store;
        break;
      case 'Accommodations':
        iconData = Icons.hotel;
        break;
      case 'Transport Routes and Terminals':
        iconData = Icons.directions_bus;
        break;
      case 'Agencies and Offices':
        iconData = Icons.corporate_fare;
        break;
      default:
        iconData = Icons.location_pin;
    }
    return Icon(iconData, color: Colors.grey[600]);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('POIs').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPois =
            snapshot.data!.docs.map((doc) => Poi.fromFirestore(doc)).toList();

        final suggestions =
            query.isEmpty
                ? allPois
                : allPois.where((poi) {
                  // Your original search logic was better, let's use it!
                  final name = poi.name.toLowerCase();
                  final type = poi.type.toLowerCase();
                  final q = query.toLowerCase();
                  return name.contains(q) || type.contains(q);
                }).toList();

        if (suggestions.isEmpty) {
          return const Center(
            child: Text(
              'No places found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final poi = suggestions[index];
            return ListTile(
              leading: _getIconForType(poi.type),
              // --- UPDATED to use your highlight function ---
              title: _highlightMatch(poi.name, query, context),
              subtitle: Text(poi.type), // Subtitle doesn't need highlighting
              onTap: () {
                close(context, poi.toMap());
              },
            );
          },
        );
      },
    );
  }
}
