import 'package:flutter/material.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import 'views/login_mobile_view.dart';
import 'views/login_web_view.dart';
import 'widgets/login_form_card.dart';

/// LoginScreen owns the login state and logic, and hands the shared
/// [LoginFormCard] to either the mobile or the web layout by screen width.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthController _authController;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_onAuthUpdate);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  void _onAuthUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _authController.removeListener(_onAuthUpdate);
    _authController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    _authController.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = await _authController.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    // The user's role picks the dashboard and menu.
    if (user != null && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard, arguments: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = LoginFormCard(
      formKey: _formKey,
      usernameController: _usernameController,
      passwordController: _passwordController,
      authController: _authController,
      onSubmit: _handleLogin,
    );

    // Login is always rendered in the signature white & sage look,
    // matching the splash screen regardless of the app theme mode.
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pureWhite,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ResponsiveLayout(
              mobile: (context) => LoginMobileView(form: form),
              web: (context) => LoginWebView(form: form),
            ),
          ),
        ),
      ),
    );
  }
}
