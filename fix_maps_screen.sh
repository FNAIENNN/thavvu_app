#!/bin/bash

echo "🔧 Fixing maps screen..."

python3 << 'PYTHON'
with open('lib/screens/maps_screen.dart', 'r') as f:
    content = f.read()

# Fix the missing closing brackets for Scaffold
# Find the build method return and fix it
old_build = '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Maps & Specifications'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView('''

new_build = '''  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Maps & Specifications'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView('''

content = content.replace(old_build, new_build)

# Now find the closing of the build method and ensure Scaffold is properly closed
# The current build should end with: );
# We need to close the SingleChildScrollView and the Scaffold

# Find the last few lines and fix them
lines = content.split('\n')
new_lines = []
depth = 0
for i, line in enumerate(lines):
    new_lines.append(line)

# Find the return Scaffold( line and count braces
in_scaffold = False
scaffold_start = -1
single_child_start = -1

for i, line in enumerate(new_lines):
    if 'return Scaffold(' in line:
        in_scaffold = True
        scaffold_start = i
    if in_scaffold and 'SingleChildScrollView(' in line:
        single_child_start = i

# The closing structure should be: ); // closes Column
#                                 ); // closes SingleChildScrollView  
#                               );   // closes Scaffold
#                             }     // closes build method

# Find the last few lines
for i in range(len(new_lines)-1, max(0, len(new_lines)-10), -1):
    if "'" in new_lines[i] and "map" not in new_lines[i].lower():
        continue
    if '}' in new_lines[i] and 'build' not in new_lines[i-2] if i > 2 else True:
        # This might be the build method closing
        # Insert proper closing before it
        new_lines.insert(i, '    );')
        new_lines.insert(i, '      );')
        break

content = '\n'.join(new_lines)

with open('lib/screens/maps_screen.dart', 'w') as f:
    f.write(content)
    
print("✅ maps_screen.dart fixed!")
PYTHON

# Also need to create the services directory
mkdir -p lib/services

# Create auth_service.dart
cat > lib/services/auth_service.dart << 'EOF'
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserName = 'user_name';
  static const String _keyUserRole = 'user_role';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> login(String name, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserRole, role);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName) ?? 'Supervisor',
      'role': prefs.getString(_keyUserRole) ?? 'Site Supervisor',
    };
  }
}
EOF

echo "✅ auth_service.dart created!"
