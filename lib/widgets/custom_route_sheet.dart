// In widgets/custom_route_sheet.dart

import 'package:flutter/material.dart';
import '../services/poi_search_delegate.dart'; // Make sure this path is correct

class CustomRouteSheet extends StatefulWidget {
  const CustomRouteSheet({super.key});

  @override
  State<CustomRouteSheet> createState() => _CustomRouteSheetState();
}

class _CustomRouteSheetState extends State<CustomRouteSheet> {
  Map<String, dynamic>? _startPoint;
  Map<String, dynamic>? _endPoint;

  // Helper method to open the search delegate and get a POI
  Future<Map<String, dynamic>?> _selectPoi() async {
    return await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: POISearchDelegate(),
    );
  }

  // Helper widget for the location input fields
  Widget _buildLocationSelector({
    required IconData icon,
    required String label,
    required String hint,
    required Map<String, dynamic>? selectedPoint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                selectedPoint?['name'] ?? hint,
                style: TextStyle(
                  fontSize: 16,
                  color:
                      selectedPoint != null ? Colors.black : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.search, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          const Text(
            'Plan a Route',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Start Point Selector
          _buildLocationSelector(
            icon: Icons.my_location,
            label: 'Start',
            hint: 'Choose starting point',
            selectedPoint: _startPoint,
            onTap: () async {
              final result = await _selectPoi();
              if (result != null) {
                setState(() {
                  _startPoint = result;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // End Point Selector
          _buildLocationSelector(
            icon: Icons.location_on,
            label: 'End',
            hint: 'Choose destination',
            selectedPoint: _endPoint,
            onTap: () async {
              final result = await _selectPoi();
              if (result != null) {
                setState(() {
                  _endPoint = result;
                });
              }
            },
          ),
          const SizedBox(height: 24),

          // Find Route Button
          ElevatedButton.icon(
            icon: const Icon(Icons.directions),
            label: const Text('Find Route'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Button is disabled until both points are selected
            onPressed:
                (_startPoint != null && _endPoint != null)
                    ? () {
                      // Pop the sheet and return the selected points
                      Navigator.pop(context, {
                        'start': _startPoint,
                        'end': _endPoint,
                      });
                    }
                    : null,
          ),
        ],
      ),
    );
  }
}
