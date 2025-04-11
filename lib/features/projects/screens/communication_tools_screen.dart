import 'package:flutter/material.dart';

class CommunicationToolsScreen extends StatelessWidget {
  const CommunicationToolsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication Tools'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Choose a Communication Method'),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.0, // Changed from 1.5 to 1.0 to give more height
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCommunicationCard(
                    context,
                    'Messaging',
                    Icons.message,
                    Colors.blue,
                    '/messaging',
                  ),
                  _buildCommunicationCard(
                    context,
                    'Video Calls',
                    Icons.videocam,
                    Colors.orange,
                    '/video_call', // Fixed underscore
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 24,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCommunicationCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced vertical padding
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color), // Reduced icon size from 40 to 36
              const SizedBox(height: 8), // Reduced from 12 to 8
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Reduced from 18 to 16
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}