import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'auth_repository.dart';
import 'pages/forgot_password_page.dart';
import 'pages/add_phone_page.dart';
import 'saved_accounts_repository.dart';
import 'saved_credentials_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialIdentifier});

  final String? initialIdentifier;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoadingEmail = false;
  bool isBusy = false;
  bool _obscurePassword = true;
  String? errorText;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null &&
        widget.initialIdentifier!.isNotEmpty) {
      emailController.text = widget.initialIdentifier!;
    }
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _maybePromptAddPhone() async {
    final user = authRepository.currentUser();
    if (user == null) return;
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) return;
    if (!mounted) return;
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm số điện thoại'),
        content: const Text(
          'Bạn chưa thêm số điện thoại. Thêm số để đăng nhập/khôi phục mật khẩu bằng SĐT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thêm ngay'),
          ),
        ],
      ),
    );
    if (shouldAdd == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddPhonePage()),
      );
    }
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() {
      isBusy = value;
    });
  }

  bool _isEmail(String input) => input.contains('@');

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email hoặc số điện thoại';
    }
    if (_isEmail(value)) {
    if (!value.contains('@') || !value.contains('.')) {
      return 'Email không đúng định dạng';
      }
    } else {
      if (value.length < 6) return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoadingEmail = true;
      errorText = null;
    });
    final identifier = emailController.text.trim();
    try {
      if (_isEmail(identifier)) {
        await authRepository.signInWithEmail(
          identifier,
          passwordController.text,
        );

        // Sau khi đăng nhập thành công: lưu thông tin tài khoản + mật khẩu để chuyển đổi nhanh
        final user = authRepository.currentUser();
        if (user != null) {
          await SavedAccountsRepository.instance.saveAccountFromUser(user);
          await SavedCredentialsRepository.instance.savePassword(
            uid: user.uid,
            password: passwordController.text,
          );
        }

        await _maybePromptAddPhone();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Tài khoản chưa đăng ký';
          break;
        case 'wrong-password':
          errorMessage = 'Mật khẩu không đúng';
          break;
        case 'invalid-email':
          errorMessage = 'Email không đúng định dạng';
          break;
        case 'user-disabled':
          errorMessage = 'Tài khoản đã bị vô hiệu hóa';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều lần thử. Vui lòng đợi vài phút';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      setState(() {
        errorText = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmail = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _setBusy(true);
    try {
      await authRepository.signInWithGoogle();
      
      // Lưu tài khoản sau khi đăng nhập thành công
      final user = authRepository.currentUser();
      if (user != null) {
        try {
          await SavedAccountsRepository.instance.saveAccountFromUser(user);
        } catch (e) {
          // Ignore errors khi lưu tài khoản
          debugPrint('Error saving account after Google sign in: $e');
        }
      }
      
      // Success - navigation handled by auth state listener
      await _maybePromptAddPhone();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'google-signin-developer-error':
          errorMessage = 'Lỗi cấu hình Google Sign-In. Vui lòng kiểm tra SHA-1 fingerprint trong Firebase Console.';
          break;
        case 'google-signin-network-error':
          errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'Tài khoản này đã được đăng ký bằng phương thức khác. Vui lòng sử dụng email/mật khẩu.';
          break;
        case 'invalid-credential':
          errorMessage = 'Thông tin đăng nhập không hợp lệ. Vui lòng thử lại.';
          break;
        case 'google-signin-failed':
          errorMessage = 'Đăng nhập Google thất bại. Vui lòng thử lại.';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      _showError(errorMessage);
    } catch (e) {
      // Handle non-Firebase errors (e.g., user cancelled)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - don't show error
        return;
      }
      _showError('Đăng nhập Google thất bại. Vui lòng thử lại.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _signInWithFacebook() async {
    _setBusy(true);
    try {
      await authRepository.signInWithFacebook();
      
      // Lưu tài khoản sau khi đăng nhập thành công
      final user = authRepository.currentUser();
      if (user != null) {
        try {
          await SavedAccountsRepository.instance.saveAccountFromUser(user);
        } catch (e) {
          // Ignore errors khi lưu tài khoản
          debugPrint('Error saving account after Facebook sign in: $e');
        }
      }
      
      // Success - navigation handled by auth state listener
      await _maybePromptAddPhone();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'facebook-login-network-error':
          errorMessage = 'Lỗi kết nối. Vui lòng kiểm tra internet và thử lại.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'Tài khoản này đã được đăng ký bằng phương thức khác. Vui lòng sử dụng email/mật khẩu.';
          break;
        case 'invalid-credential':
          errorMessage = 'Thông tin đăng nhập không hợp lệ. Vui lòng thử lại.';
          break;
        case 'facebook-login-failed':
          errorMessage = 'Đăng nhập Facebook thất bại. Vui lòng kiểm tra:\n'
              '1. Facebook App ID đã được cấu hình trong Firebase Console\n'
              '2. OAuth redirect URI đã được thêm vào Facebook App Settings\n'
              '3. Facebook App đã được kích hoạt trong Firebase Authentication';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập: ${e.code}';
      }
      _showError(errorMessage);
    } catch (e) {
      // Handle non-Firebase errors (e.g., user cancelled)
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancelled') || errorStr.contains('cancel')) {
        // User cancelled - don't show error
        return;
      }
      _showError('Đăng nhập Facebook thất bại. Vui lòng thử lại.');
    } finally {
      _setBusy(false);
    }
  }

  void _showError(String? message) {
    if (!mounted || message == null) return;
    // Sử dụng SchedulerBinding để đảm bảo context vẫn valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
    );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = isBusy || isLoadingEmail;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.3),
              colorScheme.secondaryContainer.withOpacity(0.2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo/Icon Section with Animation
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withOpacity(0.1),
                                    colorScheme.secondary.withOpacity(0.1),
                                  ],
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/app_icon.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // Title
                      Text(
                        'Chào mừng trở lại',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Đăng nhập để tiếp tục',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Email Field
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildModernTextField(
                          controller: emailController,
                          label: 'Email hoặc số điện thoại',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !disabled,
                          validator: _validateEmail,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildPasswordField(
                          controller: passwordController,
                          label: 'Mật khẩu',
                          enabled: !disabled,
                          validator: _validatePassword,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Error Message with Animation
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.2),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: errorText != null
                            ? Container(
                                key: ValueKey(errorText),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.red.shade700,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        errorText!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (errorText != null) const SizedBox(height: 20),
                      
                      // Login Button
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildAnimatedButton(
                          onPressed: (isLoadingEmail || disabled) ? null : _login,
                          isLoading: isLoadingEmail,
                          text: 'Đăng nhập',
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Forgot Password
                      TextButton(
                        onPressed: disabled
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, _) =>
                                        const ForgotPasswordPage(),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          TextButton(
                            onPressed: disabled
                                ? null
                                : () async {
                                    final result = await Navigator.of(context)
                                        .push<dynamic>(
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, _) =>
                                            const RegisterScreen(),
                                        transitionsBuilder: (context, animation,
                                            secondaryAnimation, child) {
                                          return SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(1.0, 0.0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (result is Map) {
                                      final status = result['status'] as String?;
                                      if (status == 'email') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Đăng ký email thành công. Vui lòng kiểm tra hộp thư để xác thực.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      } else if (status == 'facebook') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                                'Đăng ký bằng Facebook thành công.'),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: colorScheme.onSurface.withOpacity(0.2),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Hoặc',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: colorScheme.onSurface.withOpacity(0.2),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Social Login Buttons
                      _buildGoogleButton(
                        onPressed: disabled ? null : _signInWithGoogle,
                        isLoading: isBusy,
                      ),
                      const SizedBox(height: 12),
                      _buildSocialButton(
                        onPressed: disabled ? null : _signInWithFacebook,
                        isLoading: isBusy,
                        icon: Icons.facebook,
                        label: 'Facebook',
                        color: const Color(0xFF1877F2),
                        textColor: Colors.white,
                        borderColor: const Color(0xFF1877F2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    required bool enabled,
    required String? Function(String?) validator,
    required ColorScheme colorScheme,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required String? Function(String?) validator,
    required ColorScheme colorScheme,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: IconButton(
            key: ValueKey(_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      obscureText: _obscurePassword,
      enabled: enabled,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String text,
    required ColorScheme colorScheme,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        elevation: onPressed == null ? 0 : 4,
        shadowColor: colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: onPressed == null
                ? null
                : LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
            color: onPressed == null
                ? colorScheme.surfaceContainerHighest
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                      : Text(
                          key: const ValueKey('text'),
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton({
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        elevation: onPressed == null ? 0 : 3,
        shadowColor: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.grey.shade100,
          highlightColor: Colors.grey.shade50,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: onPressed == null
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    ),
                  )
                else
                  _buildGoogleLogo(),
                const SizedBox(width: 14),
                Text(
                  'Đăng nhập bằng Google',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Image.asset(
        'assets/icons/Google_logo.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required Color borderColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        elevation: onPressed == null ? 0 : 2,
        shadowColor: borderColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        color: color,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Icon(icon, color: textColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Đăng nhập bằng $label',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


