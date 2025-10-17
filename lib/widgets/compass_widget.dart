// In lib/widgets/compass_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassWidget extends StatelessWidget {
  const CompassWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        // Show a loading indicator until the first compass event comes in
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error reading heading: ${snapshot.error}');
        }

        // If the device has no sensor, the heading will be null
        if (snapshot.data?.heading == null) {
          return const Center(
            child: Icon(Icons.explore_off, color: Colors.grey),
          );
        }

        // Get the heading from the compass event
        double? direction = snapshot.data!.heading;

        // The compass heading tells us where North is relative to the top of the phone.
        // We need to rotate our "up" arrow by the negative of this value
        // to make it point towards North.
        final angleInRadians = (direction! * (math.pi / 180) * -1);

        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: angleInRadians,
            child: Icon(
              Icons.navigation_rounded, // This icon points 'up'
              color: Colors.redAccent,
              size: 32,
            ),
          ),
        );
      },
    );
  }
}
