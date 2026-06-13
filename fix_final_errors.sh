#!/bin/bash

echo "🔧 Fixing final 2 errors..."

# ─── ERROR 1: Fix transfers_screen.dart line 478 ───
echo "📝 Fixing transfers_screen.dart DropdownMenuItem type..."
python3 << 'PYTHON'
with open('lib/screens/transfers_screen.dart', 'r') as f:
    lines = f.readlines()

# Find all dropdown items lists and fix them
fixed_lines = []
for i, line in enumerate(lines):
    if 'items: [' in line and 'DropdownMenuItem' in lines[i+1] if i+1 < len(lines) else '':
        # Fix this line to include type parameter
        line = line.replace('items: [', 'items: const <DropdownMenuItem<String>>[')
    fixed_lines.append(line)

with open('lib/screens/transfers_screen.dart', 'w') as f:
    f.writelines(fixed_lines)

print("✅ transfers_screen.dart fixed!")
PYTHON

# ─── ERROR 2: Fix other_screens.dart SubmitButton line 1031 ───
echo "📝 Fixing other_screens.dart SubmitButton..."
python3 << 'PYTHON'
with open('lib/screens/other_screens.dart', 'r') as f:
    content = f.read()

# Find the exact SubmitButton class and replace it
old_class_start = content.find('class SubmitButton extends StatelessWidget')
old_class_end = content.find('\n}\n', old_class_start + 50)

if old_class_start != -1 and old_class_end != -1:
    old_class = content[old_class_start:old_class_end + 3]
    
    new_class = '''class SubmitButton extends StatelessWidget {
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
}'''
    
    content = content.replace(old_class, new_class)
    
    with open('lib/screens/other_screens.dart', 'w') as f:
        f.write(content)
    print("✅ SubmitButton fixed!")
else:
    print("⚠️  Could not find SubmitButton class at expected location")
    print("Searching manually...")
    
    # Print lines around 1031
    lines = content.split('\n')
    start = max(0, 1025)
    end = min(len(lines), 1050)
    for i in range(start, end):
        print(f"Line {i+1}: {lines[i]}")
PYTHON

# ─── Clean up warnings (optional, won't prevent build) ───
echo "📝 Cleaning warnings..."

# Fix unused import in maps_screen.dart
sed -i '' "s|import '../theme/app_theme.dart';|// Removed unused import|" lib/screens/maps_screen.dart

# Fix unused _selectedTab warning
python3 << 'PYTHON'
with open('lib/screens/attendance_screen.dart', 'r') as f:
    content = f.read()
# Add suppress warning or use the variable
content = content.replace(
    'int _selectedTab = 0;',
    '// ignore: unused_field\n  int _selectedTab = 0;'
)
with open('lib/screens/attendance_screen.dart', 'w') as f:
    f.write(content)
PYTHON

echo "✅ All fixes applied!"
