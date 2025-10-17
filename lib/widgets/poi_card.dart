import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PoiCard extends StatelessWidget {
  final Map<String, dynamic> poiData;
  final VoidCallback onTap;

  const PoiCard({super.key, required this.poiData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Get the image URL, same as before.
    final images = poiData['images'] as List?;
    final imageUrl =
        (images != null && images.isNotEmpty) ? images[0] : poiData['imageUrl'];

    // Get the distance text, same as before.
    final distance = poiData['distance'] as double?;
    String distanceText = '';
    if (distance != null) {
      if (distance < 1000) {
        distanceText = '${distance.toStringAsFixed(0)} m away';
      } else {
        distanceText = '${(distance / 1000).toStringAsFixed(1)} km away';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        // Set a fixed height for the card. This is crucial.
        // It must fit within the space provided by the DiscoveryPanel.
        height: 140,
        clipBehavior:
            Clip.antiAlias, // This ensures the borderRadius is respected by children.
        decoration: BoxDecoration(
          color: Colors.grey[300], // A fallback color
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Use a Stack to layer the text on top of the image.
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- REPLACE THE IMAGE WIDGET ---
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                // Show a loading spinner while the image downloads
                placeholder:
                    (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                // Show an error icon if the download fails
                errorWidget:
                    (context, url, error) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                    ),
              )
            else
              const Icon(Icons.image_not_supported, color: Colors.white),

            // --- Layer 2: The Gradient Overlay ---
            // This makes the text readable over any image.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 0.7, 1.0], // Control where the gradient starts
                ),
              ),
            ),

            // --- Layer 3: The Text ---
            // Positioned at the bottom of the card.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poiData['name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white, // White text for readability
                        shadows: [Shadow(blurRadius: 2.0)], // A subtle shadow
                      ),
                      maxLines: 2, // Allow for two lines for longer names
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distanceText.isNotEmpty)
                      Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70, // Slightly dimmer color
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
