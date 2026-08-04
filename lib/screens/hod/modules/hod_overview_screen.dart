import 'package:flutter/material.dart';

import '../../hod_module_review_screen.dart';

class HodOverviewScreen extends StatelessWidget {
  const HodOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HodModuleReviewScreen(
      title: 'HOD Overview',
      moduleFilter: 'Overview',
      actorId: 'HOD-001',
    );
  }
}
