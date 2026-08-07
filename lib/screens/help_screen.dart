import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topics = [
      ('Getting Started', 'Sign in with rajesh@thavvu.com / password. Create Account submits a pending user that can be approved in Settings.'),
      ('Machines & Daily Data', 'Submit a new machine, then approve it in Settings so it appears in Daily Machines Data.'),
      ('Attendance', 'Mark regular or outside workers. New outside profiles appear in the dropdown immediately.'),
      ('Stock', 'Raise orders and returns from Stock Inventory. Approve them in Settings to update on-hand quantities.'),
      ('Transfers & Rentals', 'Transfers deduct source stock and credit destination on acknowledge. Open/close rentals update the active list.'),
      ('Tasks & Reports', 'Toggle checklist and HOD tasks; generate reports to append live summaries from store data.'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in topics)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(t.$2, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
            ),
            child: const Text(
              'Support: support@thavvu.com · +91 1800-000-000',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.info),
            ),
          ),
        ],
      ),
    );
  }
}
