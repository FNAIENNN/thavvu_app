#!/bin/bash

echo "🔧 Fixing all issues in Thavvu App..."

# Fix 1: Add InfoCardGrid and InfoCardData to other_screens.dart
echo "📝 Fixing other_screens.dart..."
cat >> lib/screens/other_screens.dart << 'EOF'

// ─── INFO CARD GRID ─────────────────────────────────────────────────────────
class InfoCardGrid extends StatelessWidget {
  final List<InfoCardData> cards;
  
  const InfoCardGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E4F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                cards[index].title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A1628),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cards[index].subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InfoCardData {
  final String title;
  final String subtitle;
  
  const InfoCardData(this.title, this.subtitle);
}
EOF

# Fix 2: Fix SubmitButton onTap in other_screens.dart
echo "📝 Fixing SubmitButton..."
sed -i '' 's/SubmitButton(label:/SubmitButton(label:/g; s/color:/color:/, onTap: () {}/g' lib/screens/other_screens.dart

# Fix 3: Fix DropdownMenuItem type in transfers_screen.dart
echo "📝 Fixing transfers_screen.dart..."
sed -i '' 's/items: \[/items: const <DropdownMenuItem<String>>[/g' lib/screens/transfers_screen.dart

# Fix 4: Fix test file
echo "📝 Fixing test file..."
cat > test/widget_test.dart << 'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/main.dart';

void main() {
  testWidgets('App should start', (WidgetTester tester) async {
    await tester.pumpWidget(const ThavvuApp());
    expect(find.text('Thavvu'), findsOneWidget);
  });
}
EOF

# Fix 5: Auto-fix deprecated withOpacity
echo "📝 Fixing deprecated withOpacity..."
find lib/ -name "*.dart" -type f -exec sed -i '' 's/\.withOpacity(\(0\.[0-9]*\))/\.withValues(alpha: \1)/g' {} +

# Fix 6: Auto-add const keywords
echo "📝 Adding const keywords..."
dart fix --apply 2>/dev/null || echo "dart fix not available, continuing..."

echo "✅ Fixes applied!"
