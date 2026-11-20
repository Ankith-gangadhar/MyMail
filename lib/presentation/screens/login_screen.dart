import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/mymail_auth_service.dart';
import '../providers/vault_providers.dart';
import '../widgets/glass_container.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _getFriendlyAuthError(dynamic error) {
    if (error is MyMailAuthException) {
      return error.message;
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('invalid-credential') ||
        raw.contains('wrong-password') ||
        raw.contains('user-not-found') ||
        raw.contains('incorrect, malformed or has expired') ||
        raw.contains('auth credential is incorrect')) {
      return 'Incorrect email or password. Please verify your details or sign up.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'An account with this email already exists. Please sign in.';
    }
    if (raw.contains('weak-password') || raw.contains('password should be at least')) {
      return 'Password must be at least 6 characters long.';
    }
    if (raw.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment before trying again.';
    }
    if (raw.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    }
    if (raw.contains('popup-closed-by-user')) {
      return 'Google sign-in was cancelled.';
    }
    if (raw.contains('popup-blocked')) {
      return 'Popup was blocked by your browser. Please allow popups for localhost.';
    }
    if (raw.contains('unauthorized-domain')) {
      return 'This domain is not authorized. Please make sure you open http://localhost:8080 (not 127.0.0.1).';
    }
    if (raw.contains('operation-not-allowed')) {
      return 'Sign-In provider is not enabled in Firebase Console.';
    }

    if (error is FirebaseAuthException && error.message != null) {
      final clean = error.message!.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (clean.isNotEmpty) return clean;
    }

    final clean = error.toString()
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll('FirebaseAuthException:', '')
        .replaceAll('Exception:', '')
        .trim();
    return clean.isNotEmpty ? clean : 'Authentication failed. Please check your details and try again.';
  }

  void _showErrorBanner(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5225).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5225),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFFF5225).withOpacity(0.35),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        _showErrorBanner(_getFriendlyAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await ref.read(authNotifierProvider.notifier).signUpWithEmail(
              _emailController.text,
              _passwordController.text,
              _nameController.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Welcome to MyMail.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF1E2024),
            ),
          );
        }
      } else {
        await ref.read(authNotifierProvider.notifier).signInWithEmail(
              _emailController.text,
              _passwordController.text,
            );
      }
    } catch (e) {
      if (mounted) {
        _showErrorBanner(_getFriendlyAuthError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF9F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191817),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your registered email address to reset your master vault password.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF726F68),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'name@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF5E36),
                      Color(0xFFFF3310),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFFF855F),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF451A).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: isSending
                        ? null
                        : () async {
                            final email = resetEmailController.text.trim();
                            if (email.isEmpty) return;

                            setSheetState(() => isSending = true);
                            await ref.read(authNotifierProvider.notifier).sendPasswordReset(email);

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Password reset instructions sent to $email'),
                                  backgroundColor: const Color(0xFF141518),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: Center(
                      child: isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Send Reset Link',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassColors.backgroundIvory,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Icon Badge (Electric Ember Orange Glow)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF5E36),
                          Color(0xFFFF3310),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF8A65),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF451A).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Headline
                Center(
                  child: Text(
                    _isSignUp ? 'Create Account' : 'Welcome to MyMail',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF121316),
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _isSignUp
                        ? 'Set up your master vault account'
                        : 'Sign in to access your secure email vault',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF726F68),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Google Sign In Button (Transparent Glassy Pill)
                SizedBox(
                  height: 54,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.78),
                              Colors.white.withOpacity(0.48),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.92),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(27),
                            onTap: _isLoading ? null : _handleGoogleSignIn,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google "G" Icon
                                Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 28,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF191817),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider: "or with email"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black.withOpacity(0.10))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'or with email',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black.withOpacity(0.45),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.black.withOpacity(0.10))),
                  ],
                ),

                const SizedBox(height: 20),

                // Form Fields
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            fillColor: Colors.white.withOpacity(0.60),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF191817), width: 1.5),
                            ),
                          ),
                          validator: (v) =>
                              _isSignUp && (v == null || v.trim().isEmpty)
                                  ? 'Please enter your name'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          fillColor: Colors.white.withOpacity(0.60),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF191817), width: 1.5),
                          ),
                        ),
                        validator: (v) =>
                            v == null || !v.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                              color: Colors.black45,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          fillColor: Colors.white.withOpacity(0.60),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.85), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF5225), width: 1.5),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                      ),

                      if (!_isSignUp) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordSheet,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: Color(0xFFFF5225),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                      ],

                      // Submit Button (Electric Ember Orange Glow Pill)
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF5E36),
                              Color(0xFFFF3310),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(
                            color: const Color(0xFFFF855F),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF451A).withOpacity(0.38),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(27),
                            onTap: _isLoading ? null : _handleEmailSubmit,
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      _isSignUp ? 'Create Account' : 'Sign In',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Toggle Sign In / Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account?' : "Don't have an account?",
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13.5),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _isSignUp = !_isSignUp);
                      },
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: Color(0xFFFF5225),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
