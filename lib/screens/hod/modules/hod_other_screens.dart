import 'package:flutter/material.dart';

import '../../hod_module_review_screen.dart';

class HodOtherScreens extends StatelessWidget {
  const HodOtherScreens({super.key});

  @override
  Widget build(BuildContext context) {
    return const HodModuleReviewScreen(
      title: 'HOD Other',
      moduleFilter: 'Other',
      actorId: 'HOD-001',
    );
  }
}
