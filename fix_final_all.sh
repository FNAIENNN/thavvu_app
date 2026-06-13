#!/bin/bash

echo "🔧 Fixing remaining issues..."

# ─── FIX ISSUE 3: Login persistence ───
echo "📝 Fixing login persistence..."

# Update splash_screen.dart to check login state
python3 << 'PYTHON'
with open('lib/screens/splash_screen.dart', 'r') as f:
    content = f.read()

# Add import for auth service and main shell
content = content.replace(
    "import 'login_screen.dart';",
    "import 'login_screen.dart';\nimport '../services/auth_service.dart';\nimport 'main_shell.dart';"
)

# Update the navigation after splash to check login
content = content.replace(
    "Navigator.of(context).pushReplacement(\n        PageRouteBuilder(\n          pageBuilder: (_, __, ___) => const LoginScreen(),",
    '''_navigateAfterSplash();'''
)

# Add the navigation method
navigate_method = '''
  Future<void> _navigateAfterSplash() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => isLoggedIn ? const MainShell() : const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }
'''

# Insert before the dispose method
content = content.replace(
    '  @override\n  void dispose() {',
    navigate_method + '\n  @override\n  void dispose() {'
)

with open('lib/screens/splash_screen.dart', 'w') as f:
    f.write(content)
print("✅ splash_screen.dart fixed")
PYTHON

# Update login_screen.dart to save login state
python3 << 'PYTHON'
with open('lib/screens/login_screen.dart', 'r') as f:
    content = f.read()

# Add AuthService.login call before navigation
content = content.replace(
    'Navigator.of(context).pushReplacement(\n        PageRouteBuilder(\n          pageBuilder: (_, __, ___) => const MainShell(),',
    '''await AuthService.login(_emailController.text, 'Supervisor');
    Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),'''
)

with open('lib/screens/login_screen.dart', 'w') as f:
    f.write(content)
print("✅ login_screen.dart fixed")
PYTHON

# Update main_shell.dart logout to clear auth
python3 << 'PYTHON'
with open('lib/screens/main_shell.dart', 'r') as f:
    content = f.read()

# Add AuthService import
if 'auth_service' not in content:
    content = content.replace(
        "import 'login_screen.dart';",
        "import 'login_screen.dart';\nimport '../services/auth_service.dart';"
    )

# Update logout to clear auth
content = content.replace(
    "Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);",
    '''AuthService.logout().then((_) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    });'''
)

with open('lib/screens/main_shell.dart', 'w') as f:
    f.write(content)
print("✅ main_shell.dart logout fixed")
PYTHON

# ─── FIX ISSUE 4: Back buttons for attendance and reports ───
echo "📝 Adding back buttons..."

# attendance_screen.dart - already has Scaffold, just need back button
python3 << 'PYTHON'
with open('lib/screens/attendance_screen.dart', 'r') as f:
    content = f.read()

# Check if AppBar already exists
if 'appBar:' not in content or 'leading:' not in content:
    # Replace the build method's return Scaffold
    content = content.replace(
        'return Scaffold(\n      backgroundColor: AppTheme.surface,\n      body: Column(',
        '''return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Attendance Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column('''
    )

with open('lib/screens/attendance_screen.dart', 'w') as f:
    f.write(content)
print("✅ attendance_screen.dart back button added")
PYTHON

# reports_screen.dart - already has AppBar with back button ✓

# ─── FIX ISSUE 5: Profile logo ───
echo "📝 Fixing profile display..."

# Keep logo in overview header, remove from profile sheet in main_shell
python3 << 'PYTHON'
with open('lib/screens/main_shell.dart', 'r') as f:
    content = f.read()

# Fix profile sheet - use emoji instead of logo
# Replace the logo image in profile sheet with emoji
old_profile = '''child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset('assets/images/logo.png', width: 68, height: 68, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _supervisorData['name'].toString().split(' ').map((e) => e[0]).take(2).join(),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      )'''

new_profile = '''child: Text(
                        '👷',
                        style: const TextStyle(fontSize: 40),
                      )'''

if old_profile in content:
    content = content.replace(old_profile, new_profile)
    print("✅ Profile sheet updated to emoji")
else:
    print("⚠️  Profile pattern not found, checking alternate...")
    # Try alternate pattern
    if "Image.asset('assets/images/logo.png'" in content:
        content = content.replace(
            "Image.asset('assets/images/logo.png', width: 68, height: 68, fit: BoxFit.cover,",
            "Text('👷', style: TextStyle(fontSize: 40),"
        )
        print("✅ Profile updated with alternate method")

with open('lib/screens/main_shell.dart', 'w') as f:
    f.write(content)
PYTHON

# Create services directory and auth_service.dart
mkdir -p lib/services
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

echo "✅ auth_service.dart created"

# Add shared_preferences to pubspec.yaml
if ! grep -q "shared_preferences" pubspec.yaml; then
    sed -i '' 's/dependencies:/dependencies:\n  shared_preferences: ^2.2.0/' pubspec.yaml
    echo "✅ shared_preferences added to pubspec.yaml"
fi

echo ""
echo "✅ All fixes applied!"
echo "Run: flutter pub get && flutter analyze"
