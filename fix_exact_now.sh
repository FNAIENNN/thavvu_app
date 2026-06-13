#!/bin/bash

echo "🔧 Fixing exact issues now..."

# ─── Fix 1: Add SubmitButton class definition ───
echo "📝 Adding SubmitButton class to other_screens.dart..."
python3 << 'PYTHON'
with open('lib/screens/other_screens.dart', 'r') as f:
    content = f.read()

# The SubmitButton class is MISSING! We need to add it at the end of the file.
new_class = '''

// ─── SUBMIT BUTTON ──────────────────────────────────────────────────────────
class SubmitButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const SubmitButton({
    super.key, 
    required this.label, 
    required this.color, 
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
'''

content += new_class

with open('lib/screens/other_screens.dart', 'w') as f:
    f.write(content)
print("✅ SubmitButton class added!")
PYTHON

# ─── Fix 2: Fix transfers_screen.dart DropdownMenuItem ───
echo "📝 Fixing transfers_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/transfers_screen.dart', 'r') as f:
    content = f.read()

# Fix the specific DropdownMenuItem on line 478 area
# Change DropdownMenuItem to DropdownMenuItem<String>
content = content.replace(
    'return DropdownMenuItem(',
    'return DropdownMenuItem<String>('
)

with open('lib/screens/transfers_screen.dart', 'w') as f:
    f.write(content)
print("✅ transfers_screen.dart fixed!")
PYTHON

echo "✅ Done!"
