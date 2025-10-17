import 'package:flutter/material.dart';

class ReadTermsScreen extends StatelessWidget {
  const ReadTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match Figma background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F0FF), Color(0xFFC1C0DF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: [Logo] [Title]
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5.0),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sagada Tour Planner and Map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Scrollable Terms Box
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('''Terms and Agreement
Welcome to the Sagada Tour Planner and Map mobile application. By downloading, installing, and using this application, you agree to comply with and be bound by the following Terms and Agreement. If you do not agree to these terms, please do not use this application.

1. Use of the Application
The application is designed to enhance the travel experience of tourists visiting Sagada, Mountain Province, by providing both online and offline functionalities.
Users may use the app for personal and non-commercial purposes only.
The application does not guarantee real-time updates on locations and routes and should be used as a supplementary guide.

2. User Responsibilities
Users are responsible for ensuring their mobile devices meet the necessary system requirements for running the application.
Users must not use the application for any unlawful activities or in a manner that disrupts its services.
Users are responsible for any data charges incurred while using the application.

3. Privacy Policy
The application may collect user data such as location and preferences to improve user experience.
No personally identifiable information will be shared with third parties without user consent.
The application complies with applicable data protection laws and regulations.

4. Limitation of Liability
The developers of the application shall not be liable for any loss, damage, or inconvenience arising from the use or inability to use the application.
The application is provided "as is," and no warranties are given regarding its accuracy, reliability, or availability.

5. Intellectual Property
All content within the application, including maps, graphics, and textual information, is the intellectual property of the developers.
Users may not reproduce, modify, or distribute the content without prior written permission.

6. Modifications and Updates
The developers reserve the right to update, modify, or discontinue any part of the application without prior notice.
Users are encouraged to update the application regularly to access the latest features and improvements.

7. Termination
The developers reserve the right to suspend or terminate access to the application for users who violate these terms.
Users may stop using the application at any time by uninstalling it from their device.

8. Governing Law
These Terms and Agreement shall be governed by and construed in accordance with the laws of the Philippines.
Any disputes arising from the use of this application shall be resolved in the appropriate courts of the Philippines.

By using the Sagada Tour Planner and Map application, you acknowledge that you have read, understood, and agreed to these terms and conditions. If you have any questions, please contact the application's support team.
''', style: TextStyle(fontSize: 16)),

                        const SizedBox(height: 24),

                        // "I Understand" Button
                        Center(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 58, 106, 85),
                              foregroundColor: Colors.white, // Text color
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('I Understand'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
