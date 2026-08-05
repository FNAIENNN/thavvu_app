import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/supervisor_registration_repository.dart';
import 'hod_approval_screen.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.registrationRepository});

  /// Injectable for tests; defaults to the Supabase-backed implementation.
  final SupervisorRegistrationRepository? registrationRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Create-account fields (kept as state so they survive rebuilds and are
  // reachable from _handleCreateAccount).
  final _nameCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _createPassCtrl = TextEditingController();
  // HOD self-registration fields (view 3).
  final _hodNameCtrl = TextEditingController();
  final _hodEmailCtrl = TextEditingController();
  final _hodPhoneCtrl = TextEditingController();
  final _hodPassCtrl = TextEditingController();
  final _hodConfirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String _selectedRole = 'Supervisor';

  SupervisorRegistrationRepository get _regRepo =>
      widget.registrationRepository ?? SupervisorRegistrationRepository();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // 0 = login, 1 = forgot password, 2 = create account
  int _currentView = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameCtrl.dispose();
    _empIdCtrl.dispose();
    _phoneCtrl.dispose();
    _siteCtrl.dispose();
    _createPassCtrl.dispose();
    _hodNameCtrl.dispose();
    _hodEmailCtrl.dispose();
    _hodPhoneCtrl.dispose();
    _hodPassCtrl.dispose();
    _hodConfirmCtrl.dispose();
    super.dispose();
  }

  void _switchView(int view) {
    _animController.reset();
    setState(() => _currentView = view);
    _animController.forward();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final isHod = _selectedRole == 'HOD';

    try {
      // Supabase Auth is the ONLY supported sign-in: every data operation
      // goes through RLS, which requires a real authenticated session.
      final realRole = await AuthService.signInWithEmail(
        email: email,
        password: password,
        role: _selectedRole,
      );

      // The role toggle is a UX shortcut, NOT authorization. Route by the
      // account's real role; if the toggle disagrees, sign out and explain.
      final selectedIsHod = _selectedRole == 'HOD';
      final realIsHod = realRole == 'hod';
      if (realRole.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await AuthService.signOut();
        _showSnackbar(
          'Could not verify this account\'s role. Contact the HOD.',
          const Color(0xFFE53935),
        );
        return;
      }
      if (selectedIsHod != realIsHod) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await AuthService.signOut();
        final realLabel = realIsHod ? 'HOD' : 'Supervisor';
        _showSnackbar(
          'This account is registered as a $realLabel. '
          'Select $realLabel on the login screen to continue.',
          const Color(0xFFE53935),
        );
        return;
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(
        'Login failed: ${e.message}. Use a valid Supabase account — '
        'demo: ${isHod ? 'hod@thavvu.com / Hod@1234' : 'supervisor@thavvu.com / Super@1234'}',
        const Color(0xFFE53935),
      );
      return;
    } catch (e) {
      // Catch-all for network / unexpected errors.
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(
        'Connection error: ${e.toString().replaceAll('Exception: ', '')}',
        const Color(0xFFE53935),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    // HOD logins pass through the owner-approval gate before the admin app.
    final destination = isHod
        ? HodApprovalScreen(
            email: email,
            isDemo: email.toLowerCase() == 'hod@thavvu.com',
          )
        : const MainShell();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(
          'Reset link sent to ${_emailController.text}', const Color(0xFF0FA37A));
      _switchView(0);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(e.message, const Color(0xFFE53935));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('Error: ${e.toString()}', const Color(0xFFE53935));
    }
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Registration is a REQUEST, not a sign-up: no auth user is created
      // until the HOD approves it, and the HOD assigns the login password
      // at approval time (supervisors log in with HOD-assigned credentials).
      final result = await _regRepo.submit(
        fullName: _nameCtrl.text.trim(),
        empId: _empIdCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        siteName: _siteCtrl.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message =
          result['message']?.toString() ?? 'Request submitted for HOD approval.';
      _showSnackbar(message, const Color(0xFF0FA37A));
      _nameCtrl.clear();
      _empIdCtrl.clear();
      _phoneCtrl.clear();
      _siteCtrl.clear();
      _emailController.clear();
      _switchView(0);
    } on RegistrationSubmitException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(e.message, const Color(0xFFE53935));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(
        'Error: ${e.toString().replaceAll('Exception: ', '')}',
        const Color(0xFFE53935),
      );
    }
  }

  /// Registers a brand-new HOD tenant (own account, own secure password)
  /// and signs them straight in. Each HOD is isolated to their department.
  Future<void> _handleHodSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hodPassCtrl.text != _hodConfirmCtrl.text) {
      _showSnackbar('Passwords do not match', const Color(0xFFE53935));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      await client.rpc('hod_signup', params: {
        'p_full_name': _hodNameCtrl.text.trim(),
        'p_email': _hodEmailCtrl.text.trim(),
        'p_phone': _hodPhoneCtrl.text.trim(),
        'p_password': _hodPassCtrl.text,
      });
      if (!mounted) return;

      // Account created — sign in with the chosen password. The account's
      // real role is hod, so this routes to the HOD app (approval gate).
      final realRole = await AuthService.signInWithEmail(
        email: _hodEmailCtrl.text.trim(),
        password: _hodPassCtrl.text,
        role: 'HOD',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (realRole != 'hod') {
        await AuthService.signOut();
        _showSnackbar(
          'Account created but sign-in failed. Please log in manually.',
          const Color(0xFFE53935),
        );
        return;
      }
      _clearHodFields();
      final destination = HodApprovalScreen(
        email: _hodEmailCtrl.text.trim(),
        isDemo: false,
      );
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(
        'Sign-in failed: ${e.message}. Please log in manually.',
        const Color(0xFFE53935),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      _showSnackbar(
        msg.contains('already exists')
            ? 'An account already exists with this email. Please sign in.'
            : 'Registration failed: $msg',
        const Color(0xFFE53935),
      );
    }
  }

  void _clearHodFields() {
    _hodNameCtrl.clear();
    _hodEmailCtrl.clear();
    _hodPhoneCtrl.clear();
    _hodPassCtrl.clear();
    _hodConfirmCtrl.clear();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary,
              AppTheme.accent,
              Color(0xFF1E3A8A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildTopLogo(),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildCard(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(Icons.business, size: 40, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Thavvu ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Access',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF4FC3F7),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Site Management · Simplified',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white60,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: _currentView == 0
                ? _buildLoginForm()
                : _currentView == 1
                    ? _buildForgotPasswordForm()
                    : _currentView == 2
                        ? _buildCreateAccountForm()
                        : _buildHodRegisterForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardHeader(
            'Welcome Back', 'Sign in to continue', Icons.lock_outline_rounded),
        const SizedBox(height: 28),
        _buildRoleSelector(),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _emailController,
          label: 'Employee ID / Email',
          hint: 'EMP001 or name@site.com',
          icon: Icons.email_outlined,
          validator: (v) =>
              v == null || v.isEmpty ? 'Enter your ID or email' : null,
        ),
        const SizedBox(height: 18),
        _buildInputField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: Colors.grey.shade400,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) => v == null || v.length < 6
              ? 'Password must be at least 6 characters'
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Remember me',
                    style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
              ],
            ),
            GestureDetector(
              onTap: () => _switchView(1),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
            label: 'Sign In', icon: Icons.login_rounded, onTap: _handleLogin),
        const SizedBox(height: 20),
        _buildDivider('or'),
        const SizedBox(height: 20),
        _buildSecondaryButton(
            label: 'Create New Account',
            icon: Icons.person_add_outlined,
            onTap: () => _switchView(2)),
        const SizedBox(height: 12),
        _buildSecondaryButton(
            label: 'Register as HOD',
            icon: Icons.workspace_premium_outlined,
            onTap: () => _switchView(3)),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
                'Supervisors need HOD approval · HODs can self-register',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE6A817),
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Row(
        children: [
          _buildRoleOption('Supervisor', Icons.engineering_outlined),
          _buildRoleOption('HOD', Icons.admin_panel_settings_outlined),
        ],
      ),
    );
  }

  Widget _buildRoleOption(String role, IconData icon) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1976D2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                role,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _switchView(0),
          child: const Row(
            children: [
              Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF1976D2)),
              SizedBox(width: 6),
              Text('Back to Login',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCardHeader(
            'Reset Password',
            'Enter your email to receive reset link',
            Icons.mail_outline_rounded),
        const SizedBox(height: 28),
        _buildInputField(
          controller: _emailController,
          label: 'Registered Email',
          hint: 'name@site.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              v == null || !v.contains('@') ? 'Enter valid email' : null,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFF1976D2).withOpacity(0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1976D2)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A reset link will be sent to your registered email. Contact HOD if access is unavailable.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF555555), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
            label: 'Send Reset Link',
            icon: Icons.send_rounded,
            onTap: _handleForgotPassword),
      ],
    );
  }

  Widget _buildCreateAccountForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _switchView(0),
          child: const Row(
            children: [
              Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF1976D2)),
              SizedBox(width: 6),
              Text('Back to Login',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCardHeader('Create Account', 'Register as a new supervisor',
            Icons.person_add_outlined),
        const SizedBox(height: 24),
        _buildInputField(
            controller: _nameCtrl,
            label: 'Full Name',
            hint: 'Rajesh Kumar',
            icon: Icons.person_outline,
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter your full name'
                : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _empIdCtrl,
            label: 'Employee ID',
            hint: 'EMP001',
            icon: Icons.badge_outlined,
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter your employee ID'
                : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            hint: '+91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
              return digits.length < 8 ? 'Enter a valid phone number' : null;
            }),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _siteCtrl,
            label: 'Site / Stock Point',
            hint: 'Site A - Chennai',
            icon: Icons.location_on_outlined,
            validator: (v) => v == null || v.trim().length < 2
                ? 'Enter your site / stock point'
                : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'name@site.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_reset, size: 18, color: Color(0xFFE6A817)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "After approval your HOD will assign your login password — you'll be notified via SMS/Email.",
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF7A5C00), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
            label: 'Submit for Approval',
            icon: Icons.how_to_reg_rounded,
            onTap: _handleCreateAccount),
      ],
    );
  }

  Widget _buildHodRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _switchView(0),
          child: const Row(
            children: [
              Icon(Icons.arrow_back, size: 18, color: Color(0xFF1976D2)),
              SizedBox(width: 6),
              Text('Back to login',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCardHeader('Register as HOD',
            'Create your department workspace', Icons.workspace_premium_outlined),
        const SizedBox(height: 24),
        _buildInputField(
            controller: _hodNameCtrl,
            label: 'Full Name',
            hint: 'Your name',
            icon: Icons.person_outline,
            validator: (v) => v == null || v.trim().length < 3
                ? 'Enter your full name'
                : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _hodEmailCtrl,
            label: 'Email Address',
            hint: 'you@company.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _hodPhoneCtrl,
            label: 'Phone Number',
            hint: '+91 98765 43210',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
              return digits.length < 8 ? 'Enter a valid phone number' : null;
            }),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _hodPassCtrl,
            label: 'Create Password',
            hint: 'Minimum 6 characters',
            icon: Icons.lock_outline,
            obscure: true,
            validator: (v) => v == null || v.length < 6
                ? 'Password must be at least 6 characters'
                : null),
        const SizedBox(height: 14),
        _buildInputField(
            controller: _hodConfirmCtrl,
            label: 'Confirm Password',
            hint: 'Re-enter password',
            icon: Icons.lock_outline,
            obscure: true,
            validator: (v) => v == null || v != _hodPassCtrl.text
                ? 'Passwords do not match'
                : null),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.security_outlined, size: 18, color: Color(0xFFE6A817)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Your account is created instantly. You'll manage your own supervisors, sites and data — fully isolated from other departments.",
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF7A5C00), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
            label: 'Create HOD Account',
            icon: Icons.check_circle_outline,
            onTap: _handleHodSignup),
      ],
    );
  }

  Widget _buildCardHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1628))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0A1628)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1976D2)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1976D2))),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.8)),
      ],
    );
  }
}
