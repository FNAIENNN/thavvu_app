#!/bin/bash

echo "🔧 Fixing remaining issues..."

# ─── Fix 1: SubmitButton onTap error ───
echo "📝 Fixing SubmitButton in other_screens.dart..."
python3 << 'PYTHON'
import re

with open('lib/screens/other_screens.dart', 'r') as f:
    content = f.read()

# Find and replace the SubmitButton class completely
old_pattern = r'class SubmitButton extends StatelessWidget \{[^}]*\}\n\}'
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
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
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

content = re.sub(old_pattern, new_class, content, flags=re.DOTALL)

# Fix all SubmitButton usage to include onTap
content = content.replace(
    'const SubmitButton(label:',
    'SubmitButton(label:'
)

with open('lib/screens/other_screens.dart', 'w') as f:
    f.write(content)
    
print("SubmitButton fixed!")
PYTHON

# ─── Fix 2: transfers_screen.dart DropdownMenuItem type ───
echo "📝 Fixing transfers_screen.dart DropdownMenuItem..."
python3 << 'PYTHON'
with open('lib/screens/transfers_screen.dart', 'r') as f:
    content = f.read()

# Find the problematic line around line 478
lines = content.split('\n')
for i, line in enumerate(lines):
    if 'DropdownMenuItem' in line and 'items:' in lines[max(0,i-3):i+1]:
        # Fix the items list
        for j in range(max(0,i-3), min(len(lines), i+10)):
            if 'items:' in lines[j] and 'const' not in lines[j] and '<DropdownMenuItem<String>>' not in lines[j]:
                lines[j] = lines[j].replace('items: [', 'items: const <DropdownMenuItem<String>>[')

content = '\n'.join(lines)
with open('lib/screens/transfers_screen.dart', 'w') as f:
    f.write(content)
    
print("transfers_screen.dart fixed!")
PYTHON

# ─── Fix 3: Clean up warnings ───
echo "📝 Cleaning up warnings..."

# Fix unused import in maps_screen.dart
sed -i '' "s|import '../theme/app_theme.dart';|// import '../theme/app_theme.dart';|" lib/screens/maps_screen.dart

# Fix unused _selectedFilter in maps_screen.dart
python3 << 'PYTHON'
with open('lib/screens/maps_screen.dart', 'r') as f:
    content = f.read()

# Remove the unused _selectedFilter field
content = content.replace("  String _selectedFilter = 'All';\n\n", "")
with open('lib/screens/maps_screen.dart', 'w') as f:
    f.write(content)
PYTHON

# Fix unused fields by adding underscore or removing
python3 << 'PYTHON'
files = {
    'lib/screens/attendance_screen.dart': '_selectedTab',
    'lib/screens/stock_inventory_screen.dart': ['_isSubmittingOrder', '_isSubmittingReturn'],
    'lib/screens/tasks_screen.dart': '_isLoading',
}

for filepath, fields in files.items():
    with open(filepath, 'r') as f:
        content = f.read()
    
    if isinstance(fields, str):
        fields = [fields]
    
    for field in fields:
        # Comment out unused field declarations
        content = content.replace(
            f'bool {field} = false;',
            f'// bool {field} = false; // Unused'
        )
        content = content.replace(
            f'int {field} = 0;',
            f'// int {field} = 0; // Unused'
        )
    
    with open(filepath, 'w') as f:
        f.write(content)
PYTHON

echo "✅ Remaining fixes applied!"
