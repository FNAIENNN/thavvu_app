#!/bin/bash

echo "🔧 Fixing corrupted files..."

# ─── Fix machines_entry_screen.dart ───
echo "📝 Fixing machines_entry_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/machines_entry_screen.dart', 'r') as f:
    content = f.read()

# Remove extra closing brackets from Scaffold removal
content = content.replace('    );', '')
content = content.replace('  );', '')
content = content.replace('      );\n    );\n  )', '')

# Find SingleChildScrollView and fix its closing
# The file should end with the submit button and closing brackets
with open('lib/screens/machines_entry_screen.dart', 'w') as f:
    f.write(content)
print("machines_entry_screen.dart - removed extra brackets")
PYTHON

# ─── Fix daily_data_screen.dart ───
echo "📝 Fixing daily_data_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/daily_data_screen.dart', 'r') as f:
    content = f.read()

content = content.replace('    );', '')
content = content.replace('  );', '')

with open('lib/screens/daily_data_screen.dart', 'w') as f:
    f.write(content)
print("daily_data_screen.dart - removed extra brackets")
PYTHON

# ─── Fix splash_screen.dart ───
echo "📝 Fixing splash_screen.dart..."
python3 << 'PYTHON'
with open('lib/screens/splash_screen.dart', 'r') as f:
    content = f.read()

# Remove the broken code and fix the navigate method
# Find the broken _navigateAfterSplash method and fix it
old_broken = '''_navigateAfterSplash();'''

fixed_code = '''Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );'''

content = content.replace(old_broken, fixed_code)

# Remove the broken _navigateAfterSplash method
if '_navigateAfterSplash' in content:
    # Find and remove the broken method
    lines = content.split('\n')
    new_lines = []
    skip = False
    for line in lines:
        if 'Future<void> _navigateAfterSplash()' in line:
            skip = True
            continue
        if skip and line.strip() == '}' and 'dispose' not in line:
            skip = False
            continue
        if not skip:
            new_lines.append(line)
    content = '\n'.join(new_lines)

with open('lib/screens/splash_screen.dart', 'w') as f:
    f.write(content)
print("splash_screen.dart fixed")
PYTHON

# ─── Remove unused imports ───
echo "📝 Removing unused imports..."
sed -i '' "s|import 'services/auth_service.dart';|// import 'services/auth_service.dart';|" lib/main.dart
sed -i '' "s|import '../services/auth_service.dart';|// import '../services/auth_service.dart';|" lib/screens/main_shell.dart

# ─── Fix shared_preferences in pubspec.yaml ───
echo "📝 Fixing pubspec.yaml..."
python3 << 'PYTHON'
with open('pubspec.yaml', 'r') as f:
    content = f.read()

# Remove shared_preferences from dev_dependencies
lines = content.split('\n')
new_lines = []
in_dev = False
for line in lines:
    if 'dev_dependencies:' in line:
        in_dev = True
    if in_dev and 'shared_preferences' in line:
        continue
    new_lines.append(line)

content = '\n'.join(new_lines)

# Make sure shared_preferences is in regular dependencies
if 'shared_preferences' not in content:
    content = content.replace(
        'dependencies:\n  flutter:\n    sdk: flutter',
        'dependencies:\n  flutter:\n    sdk: flutter\n  shared_preferences: ^2.2.0'
    )

with open('pubspec.yaml', 'w') as f:
    f.write(content)
print("pubspec.yaml fixed")
PYTHON

echo ""
echo "✅ Fixes applied! Run: flutter pub get && flutter analyze"
