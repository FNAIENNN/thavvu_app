#!/bin/bash

echo "🔧 Fixing corrupted files..."

# ─── Fix attendance_screen.dart ───
echo "📝 Fixing attendance_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/attendance_screen.dart', 'r') as f:
    content = f.read()

# Fix the corrupted lines around line 11-16
# Remove any broken comment markers we added
content = content.replace('// bool _selectedTab = 0; // Unused', 'int _selectedTab = 0;')
content = content.replace('// int _selectedTab = 0; // Unused', 'int _selectedTab = 0;')

# If still broken, restore from known good state
if 'final _' in content or 'unnamed' in content.lower():
    print("Fixing corrupted field declarations...")
    lines = content.split('\n')
    fixed_lines = []
    for line in lines:
        # Skip broken lines
        if '// bool' in line or '// int' in line:
            # Restore original
            if '_selectedTab' in line:
                fixed_lines.append('  int _selectedTab = 0;')
            elif '_isSubmittingOrder' in line:
                fixed_lines.append('  bool _isSubmittingOrder = false;')
            elif '_isSubmittingReturn' in line:
                fixed_lines.append('  bool _isSubmittingReturn = false;')
            elif '_isLoading' in line:
                fixed_lines.append('  bool _isLoading = false;')
            else:
                fixed_lines.append(line)
        else:
            fixed_lines.append(line)
    content = '\n'.join(fixed_lines)

with open('lib/screens/attendance_screen.dart', 'w') as f:
    f.write(content)
print("attendance_screen.dart fixed!")
PYTHON

# ─── Fix stock_inventory_screen.dart ───
echo "📝 Fixing stock_inventory_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/stock_inventory_screen.dart', 'r') as f:
    content = f.read()

# Restore original field declarations
content = content.replace('// bool _isSubmittingOrder = false; // Unused', 'bool _isSubmittingOrder = false;')
content = content.replace('// bool _isSubmittingReturn = false; // Unused', 'bool _isSubmittingReturn = false;')

# Fix any double modifiers
content = content.replace('final final ', 'final ')
content = content.replace('static final const ', 'static const ')
content = content.replace('final const ', 'final ')

with open('lib/screens/stock_inventory_screen.dart', 'w') as f:
    f.write(content)
print("stock_inventory_screen.dart fixed!")
PYTHON

# ─── Fix tasks_screen.dart ───
echo "📝 Fixing tasks_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/tasks_screen.dart', 'r') as f:
    content = f.read()

# Fix modifier order
content = content.replace('final late ', 'late final ')
content = content.replace('// bool _isLoading = false; // Unused', 'bool _isLoading = false;')

with open('lib/screens/tasks_screen.dart', 'w') as f:
    f.write(content)
print("tasks_screen.dart fixed!")
PYTHON

# ─── Fix maps_screen.dart ───
echo "📝 Fixing maps_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/maps_screen.dart', 'r') as f:
    content = f.read()

# Remove any broken comment markers
content = content.replace('// import ', 'import ')
content = content.replace('String _selectedFilter', '// String _selectedFilter')

with open('lib/screens/maps_screen.dart', 'w') as f:
    f.write(content)
print("maps_screen.dart fixed!")
PYTHON

# ─── Fix other_screens.dart SubmitButton ───
echo "📝 Fixing other_screens.dart SubmitButton..."
python3 << 'PYTHON'
with open('lib/screens/other_screens.dart', 'r') as f:
    content = f.read()

# Find SubmitButton class and replace it completely
import re

# Find the class definition
pattern = r'class SubmitButton.*?(?=\nclass |\n\/\/ ─── |\Z)'
matches = list(re.finditer(pattern, content, re.DOTALL))

if matches:
    old_class = matches[0].group(0)
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
    content = content.replace(old_class, new_class)
    print("SubmitButton class replaced!")
else:
    print("⚠️  Could not find SubmitButton class")

with open('lib/screens/other_screens.dart', 'w') as f:
    f.write(content)
PYTHON

# ─── Fix transfers_screen.dart ───
echo "📝 Fixing transfers_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/transfers_screen.dart', 'r') as f:
    content = f.read()

# Fix the DropdownMenuItem type issue at line 478
import re

# Find the problematic items list
pattern = r"items: const <DropdownMenuItem<String>>\[(.*?)\]"
matches = re.findall(pattern, content, re.DOTALL)

if not matches:
    # Try to find items: [ without const
    pattern2 = r'items: \[(.*?)\]'
    content = re.sub(
        pattern2,
        r'items: const <DropdownMenuItem<String>>[\1]',
        content,
        flags=re.DOTALL
    )
    print("Fixed DropdownMenuItem items list!")
else:
    print("DropdownMenuItem already fixed!")

with open('lib/screens/transfers_screen.dart', 'w') as f:
    f.write(content)
PYTHON

echo "✅ All corrupted files fixed!"
