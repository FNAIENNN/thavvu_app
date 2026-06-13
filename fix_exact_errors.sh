#!/bin/bash

echo "🔧 Fixing the exact 2 errors..."

# ─── ERROR 1: transfers_screen.dart line 478 ───
echo "📝 Fixing transfers_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/transfers_screen.dart', 'r') as f:
    content = f.read()

# Replace ALL occurrences of DropdownMenuItem without type parameter
content = content.replace(
    'DropdownMenuItem(value:',
    'DropdownMenuItem<String>(value:'
)

# Also fix items lists
content = content.replace(
    'items: const <DropdownMenuItem<String>>[',
    'items: ['
)

# Now properly add const with type
content = content.replace(
    'items: [',
    'items: const <DropdownMenuItem<String>>['
)

with open('lib/screens/transfers_screen.dart', 'w') as f:
    f.write(content)
print("✅ transfers_screen.dart fixed")
PYTHON

# ─── ERROR 2: other_screens.dart SubmitButton ───
echo "📝 Fixing other_screens.dart..."
python3 << 'PYTHON'
with open('lib/screens/other_screens.dart', 'r') as f:
    lines = f.readlines()

# Find SubmitButton class boundaries
start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if 'class SubmitButton extends StatelessWidget' in line:
        start_idx = i
    if start_idx is not None and line.strip() == '}' and i > start_idx + 5:
        # Check if this is the class closing brace
        if i + 1 < len(lines) and (lines[i+1].strip() == '' or lines[i+1].startswith('//') or lines[i+1].startswith('class')):
            end_idx = i
            break

if start_idx and end_idx:
    # Replace the entire class
    new_class_lines = [
        'class SubmitButton extends StatelessWidget {\n',
        '  final String label;\n',
        '  final Color color;\n',
        '  final VoidCallback? onTap;\n',
        '\n',
        '  const SubmitButton({\n',
        '    super.key, \n',
        '    required this.label, \n',
        '    required this.color, \n',
        '    this.onTap,\n',
        '  });\n',
        '\n',
        '  @override\n',
        '  Widget build(BuildContext context) {\n',
        '    return GestureDetector(\n',
        '      onTap: onTap,\n',
        '      child: Container(\n',
        '        width: double.infinity,\n',
        '        padding: const EdgeInsets.symmetric(vertical: 16),\n',
        '        decoration: BoxDecoration(\n',
        '          color: color,\n',
        '          borderRadius: BorderRadius.circular(14),\n',
        '        ),\n',
        '        alignment: Alignment.center,\n',
        '        child: Text(\n',
        '          label,\n',
        '          style: const TextStyle(\n',
        '            fontSize: 15,\n',
        '            fontWeight: FontWeight.w700,\n',
        '            color: Colors.white,\n',
        '          ),\n',
        '        ),\n',
        '      ),\n',
        '    );\n',
        '  }\n',
        '}\n',
    ]
    
    new_lines = lines[:start_idx] + new_class_lines + lines[end_idx+1:]
    
    with open('lib/screens/other_screens.dart', 'w') as f:
        f.writelines(new_lines)
    print(f"✅ SubmitButton class replaced (lines {start_idx+1}-{end_idx+1})")
else:
    print(f"⚠️  Could not find SubmitButton. Start: {start_idx}, End: {end_idx}")
    # Print lines around 1031 for debugging
    for i in range(1025, min(len(lines), 1045)):
        print(f"Line {i+1}: {lines[i].rstrip()}")
PYTHON

echo ""
echo "✅ Done! Now run: flutter analyze"
