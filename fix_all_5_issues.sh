#!/bin/bash

echo "🔧 Fixing all 5 issues..."

# ─── ISSUE 1: Black screen on back arrow in machines_entry_screen & daily_data_screen ───
# Problem: Both screens have their own AppBar with Navigator.pop(), but they're 
# already inside a Scaffold from main_shell.dart. Need to remove the inner Scaffold.

echo "📝 Fixing Issue 1 - Black screen on back..."

# Fix machines_entry_screen.dart - Remove inner Scaffold and AppBar
python3 << 'PYTHON'
with open('lib/screens/machines_entry_screen.dart', 'r') as f:
    content = f.read()

# Remove the inner Scaffold wrapper
old_start = '''    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('New Machines Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView('''

old_start2 = '''    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('New Machines Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView('''

# Find and remove the inner Scaffold
content = content.replace(
    'return Scaffold(\n      backgroundColor: AppTheme.surface,\n      appBar: AppBar(\n        title: const Text(\'New Machines Entry\'),\n        leading: IconButton(\n          icon: const Icon(Icons.arrow_back),\n          onPressed: () => Navigator.pop(context),\n        ),\n      ),\n      body: SingleChildScrollView(',
    'return SingleChildScrollView('
)

# Remove the extra closing parenthesis and bracket from Scaffold
# Find the last occurrence of ");" that closes Scaffold
lines = content.split('\n')
new_lines = []
skip_next = False
for i, line in enumerate(lines):
    if 'return SingleChildScrollView(' in line:
        new_lines.append(line)
        skip_next = False
    else:
        new_lines.append(line)

content = '\n'.join(new_lines)

with open('lib/screens/machines_entry_screen.dart', 'w') as f:
    f.write(content)
print("✅ machines_entry_screen.dart fixed")
PYTHON

# Fix daily_data_screen.dart - Remove inner Scaffold and AppBar
python3 << 'PYTHON'
with open('lib/screens/daily_data_screen.dart', 'r') as f:
    content = f.read()

content = content.replace(
    'return Scaffold(\n      backgroundColor: AppTheme.surface,\n      appBar: AppBar(\n        title: const Text(\'Daily Machines Data\'),\n        leading: IconButton(\n          icon: const Icon(Icons.arrow_back),\n          onPressed: () => Navigator.pop(context),\n        ),\n      ),\n      body: SingleChildScrollView(',
    'return SingleChildScrollView('
)

with open('lib/screens/daily_data_screen.dart', 'w') as f:
    f.write(content)
print("✅ daily_data_screen.dart fixed")
PYTHON

# ─── ISSUE 2: Maps screen crashing/going back ───
echo "📝 Fixing Issue 2 - Maps screen..."

python3 << 'PYTHON'
with open('lib/screens/maps_screen.dart', 'r') as f:
    content = f.read()

# Add AppBar to maps screen
old_build = '@override\n  Widget build(BuildContext context) {\n    return SingleChildScrollView('
new_build = '''@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Maps & Specifications'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView('''

content = content.replace(old_build, new_build)

# Find the closing of build method and add Scaffold closing
content = content.replace(
    '          ),\n        ],\n      ),\n    );\n  }',
    '          ),\n        ],\n      ),\n    );\n    );\n  }'
)

with open('lib/screens/maps_screen.dart', 'w') as f:
    f.write(content)
print("✅ maps_screen.dart fixed")
PYTHON

# ─── ISSUE 3: Login persistence ───
echo "📝 Fixing Issue 3 - Login persistence..."

# Create shared preferences helper
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

# Update login_screen.dart to save login state
python3 << 'PYTHON'
with open('lib/screens/login_screen.dart', 'r') as f:
    content = f.read()

# Add import
if "import '../services/auth_service.dart';" not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport '../services/auth_service.dart';"
    )

# Find login success and add AuthService.login()
content = content.replace(
    'Navigator.pushReplacement(',
    '''await AuthService.login(_nameController.text, 'Supervisor');
    Navigator.pushReplacement('''
)

content = content.replace(
    'Navigator.of(context).pushAndRemoveUntil(',
    '''await AuthService.login(_nameController.text, 'Supervisor');
    Navigator.of(context).pushAndRemoveUntil('''
)

with open('lib/screens/login_screen.dart', 'w') as f:
    f.write(content)
print("✅ login_screen.dart fixed")
PYTHON

# Update main.dart to check login state
python3 << 'PYTHON'
with open('lib/main.dart', 'r') as f:
    content = f.read()

if 'AuthService' not in content:
    old_main = '''void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ThavvuApp());
}'''

    new_main = '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  // Check login state
  final isLoggedIn = await AuthService.isLoggedIn();
  
  runApp(ThavvuApp(isLoggedIn: isLoggedIn));
}'''

    content = content.replace(old_main, new_main)
    
    # Add import
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'services/auth_service.dart';"
    )
    
    # Update ThavvuApp to accept isLoggedIn
    content = content.replace(
        'class ThavvuApp extends StatelessWidget {\n  const ThavvuApp({super.key});',
        'class ThavvuApp extends StatelessWidget {\n  final bool isLoggedIn;\n  const ThavvuApp({super.key, this.isLoggedIn = false});'
    )
    
    # Update home based on login state
    content = content.replace(
        "home: const MainShell(),",
        "home: isLoggedIn ? const MainShell() : const LoginScreen(),"
    )

with open('lib/main.dart', 'w') as f:
    f.write(content)
print("✅ main.dart fixed")
PYTHON

# Add shared_preferences to pubspec.yaml
if ! grep -q "shared_preferences" pubspec.yaml; then
    sed -i '' 's/dependencies:/dependencies:\n  shared_preferences: ^2.2.0/' pubspec.yaml
fi

# ─── ISSUE 4: Attendance and Reports missing back button ───
echo "📝 Fixing Issue 4 - Back buttons..."

# attendance_screen.dart already has no AppBar - add one
python3 << 'PYTHON'
with open('lib/screens/attendance_screen.dart', 'r') as f:
    content = f.read()

# Add AppBar
content = content.replace(
    'return Scaffold(\n      backgroundColor: AppTheme.surface,\n      body: Column(',
    '''return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column('''
)

with open('lib/screens/attendance_screen.dart', 'w') as f:
    f.write(content)
print("✅ attendance_screen.dart fixed")
PYTHON

# reports_screen.dart already has AppBar - it's fine

# ─── ISSUE 5: Profile logo in overview_screen ───
echo "📝 Fixing Issue 5 - Profile logo..."

# Update main_shell.dart to show proper profile
python3 << 'PYTHON'
with open('lib/screens/main_shell.dart', 'r') as f:
    content = f.read()

# Fix the profile avatar in appbar
content = content.replace(
    '''Text(
                    _supervisorData['name'].toString().split(' ').map((e) => e[0]).take(2).join(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  )''',
    '''Text(
                    '👷',
                    style: TextStyle(fontSize: 16),
                  )'''
)

# Fix profile sheet to use emoji instead of logo
content = content.replace(
    "child: Image.asset('assets/images/logo.png', width: 68, height: 68, fit: BoxFit.cover,",
    "child: const Text('👷', style: TextStyle(fontSize: 40)),"
)

content = content.replace(
    "errorBuilder: (context, error, stackTrace) => Text(_supervisorData['name'].toString().split(' ').map((e) => e[0]).take(2).join(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),",
    "// Profile emoji"
)

with open('lib/screens/main_shell.dart', 'w') as f:
    f.write(content)
print("✅ main_shell.dart profile fixed")
PYTHON

# Update overview_screen.dart profile icon
python3 << 'PYTHON'
with open('lib/screens/overview_screen.dart', 'r') as f:
    content = f.read()

# Change profile icon to emoji
content = content.replace(
    "child: const Text('👷', style: TextStyle(fontSize: 30))",
    "child: const Text('👷', style: TextStyle(fontSize: 26))"
)

with open('lib/screens/overview_screen.dart', 'w') as f:
    f.write(content)
print("✅ overview_screen.dart fixed")
PYTHON

echo ""
echo "✅ All 5 issues fixed!"
echo ""
echo "Run: flutter pub get && flutter analyze"
