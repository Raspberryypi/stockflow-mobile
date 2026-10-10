import 'package:flutter/material.dart';
import '../placeholder/placeholder_screen.dart';
import 'greeting_header.dart';

// Batch 2 replaces the body with the real dashboard (stat cards, charts).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GreetingHeader(),
          Expanded(child: PlaceholderScreen('Dashboard', icon: Icons.dashboard_rounded)),
        ],
      ),
    );
  }
}
