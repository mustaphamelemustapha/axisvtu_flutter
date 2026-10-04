import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../services/transaction_pin_service.dart';
import '../state/session.dart';
import '../widgets/auth_liquid_glass.dart';
import '../widgets/primary_button.dart';
import '../widgets/state_select_sheet.dart';
import 'auth_password_screen.dart';
import 'shell_screen.dart';
import 'welcome_screen.dart';
import '../widgets/concentric_circles_bg.dart';

class SignupWizardScreen extends StatefulWidget {
  final String phone;

  const SignupWizardScreen({
    super.key,
    required this.phone,
  });

  static const String route = '/signup-wizard';

  @override
  State<SignupWizardScreen> createState() => _SignupWizardScreenState();
}

class _SignupWizardScreenState extends State<SignupWizardScreen> {
  final PageController _pageController = PageController();

  // Wizard Data in local state
  int _currentStep = 0; // 0: Password, 1: PIN, 2: Name/Email, 3: State, 4: Push
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmPinCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _referralCtrl = TextEditingController();
  String? _selectedState;

  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _referralFocus = FocusNode();
  final FocusNode _stateFocus = FocusNode();

  // UI state
  bool _obscurePassword = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _showReferralField = false;
  bool _loading = false;
  String? _emailInlineError;
  String _stateSearchQuery = '';
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
    _confirmPinFocus.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _referralFocus.addListener(() => setState(() {}));
    _stateFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _referralCtrl.dispose();
    _passwordFocus.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _referralFocus.dispose();
    _stateFocus.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    final regex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$');
    return regex.hasMatch(trimmed);
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    _pageController.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    if (_currentStep == 0) {
      // Step 1 back -> Return to WelcomeScreen keeping phone prefilled
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(initialPhone: widget.phone),
        ),
        (_) => false,
      );
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submitRegistration({bool requestPush = true}) async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _emailInlineError = null;
    });

    HapticFeedback.mediumImpact();

    final session = context.read<SessionController>();
    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    final cleanName = _nameCtrl.text.trim();
    final cleanPass = _passwordCtrl.text;
    final cleanPin = _pinCtrl.text.trim();
    final cleanReferral = _referralCtrl.text.trim();

    try {
      final ok = await session.register(
        cleanName,
        cleanEmail,
        widget.phone,
        cleanPass,
        referralCode: cleanReferral.isNotEmpty ? cleanReferral : null,
        state: _selectedState,
        pin: cleanPin,
      );

      if (!mounted) return;

      if (ok) {
        // Guarantee PIN is saved via TransactionPinService if Render backend hasn't deployed register with pin yet
        if (cleanPin.isNotEmpty && session.token != null) {
          try {
            await TransactionPinService(token: session.token!).setup(
              pin: cleanPin,
              confirmPin: cleanPin,
            );
          } catch (_) {}
        }

        // Trigger built-in system notification prompt directly
        if (requestPush) {
          try {
            if (Firebase.apps.isNotEmpty) {
              await FirebaseMessaging.instance.requestPermission(
                alert: true,
                badge: true,
                sound: true,
              );
            }
          } catch (_) {}
        }

        if (!mounted) return;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushNamedAndRemoveUntil(
          ShellScreen.route,
          (_) => false,
        );
        return;
      }

      // Registration failed
      _handleRegistrationError(session.error ?? 'Registration failed');
    } catch (e) {
      if (!mounted) return;
      _handleRegistrationError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _handleRegistrationError(String rawError) {
    HapticFeedback.heavyImpact();
    final lower = rawError.toLowerCase();

    if (lower.contains('email already') || lower.contains('email_already') || (lower.contains('email') && lower.contains('registered'))) {
      // Rule: Jump back to Step 3 (index 2) with clear inline error, keeping all other data
      _emailInlineError = 'This email is already in use. Please enter a different email address.';
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      _shakeKey.currentState?.shake();
      return;
    }

    if (lower.contains('phone number already') || lower.contains('phone_number already')) {
      // Phone already registered -> Route to login
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Account Exists', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Text(
            'The phone number ${widget.phone} is already registered. Would you like to log in?',
            style: GoogleFonts.plusJakartaSans(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => AuthPasswordScreen(identifier: widget.phone),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2457F5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rawError.isNotEmpty ? rawError : 'Unable to complete signup. Please check your connection and try again.'),
        backgroundColor: const Color(0xFFE11D48),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: ConcentricCirclesBg(
          child: Column(
            children: [
              // Top Bar with Back button and Step indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _previousStep,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const Spacer(),
                    Text(
                      'Step ${_currentStep + 1} of 4',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  children: List.generate(4, (index) {
                    final isCompleted = index <= _currentStep;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF2457F5)
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // PageView Steps
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Only navigate through buttons
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    _buildStep1Password(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep2Pin(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep3NameAndEmail(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep4State(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Step 3.1: Create Password
  // ----------------------------------------------------
  Widget _buildStep1Password(bool isDark) {
    final password = _passwordCtrl.text;
    final isValid = password.length >= 8;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhonePill(
            phone: widget.phone,
            onChange: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => WelcomeScreen(initialPhone: widget.phone),
                ),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Create password',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong password to protect your MELE DATA wallet and transactions.',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LiquidGlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASSWORD',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _passwordFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                  ),
                  child: TextField(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (isValid) _nextStep();
                    },
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: const Color(0xFF2563EB),
                    decoration: InputDecoration(
                      hintText: 'Minimum 8 characters',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: _passwordFocus.hasFocus
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0A101D) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFF2563EB),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isValid ? const Color(0xFF10B981) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'At least 8 characters (${password.length}/8)',
                style: GoogleFonts.plusJakartaSans(
                  color: isValid ? const Color(0xFF10B981) : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          PrimaryButton(
            label: 'Continue',
            onPressed: isValid ? _nextStep : null,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Step 3.2: Set Transaction PIN
  // ----------------------------------------------------
  Widget _buildStep2Pin(bool isDark) {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();
    final isPinValid = pin.length == 4;
    final isMatch = isPinValid && pin == confirm;
    final showMismatch = confirm.length == 4 && !isMatch;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhonePill(
            phone: widget.phone,
            onChange: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => WelcomeScreen(initialPhone: widget.phone),
                ),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Set transaction PIN',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a 4-digit numeric PIN for authorizing purchases and wallet transfers.',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LiquidGlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW 4-DIGIT PIN',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _pinFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                  ),
                  child: TextField(
                    controller: _pinCtrl,
                    focusNode: _pinFocus,
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 8,
                    ),
                    cursorColor: const Color(0xFF2563EB),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                        letterSpacing: 8,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0A101D) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: const Color(0xFF2563EB),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'CONFIRM 4-DIGIT PIN',
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _confirmPinFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                  ),
                  child: TextField(
                    controller: _confirmPinCtrl,
                    focusNode: _confirmPinFocus,
                    keyboardType: TextInputType.number,
                    obscureText: _obscureConfirmPin,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (isMatch) _nextStep();
                    },
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 8,
                    ),
                    cursorColor: const Color(0xFF2563EB),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                        letterSpacing: 8,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0A101D) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: showMismatch ? const Color(0xFFE11D48) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: showMismatch ? const Color(0xFFE11D48) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: showMismatch ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showMismatch) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFF43F5E), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'PINs do not match',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF43F5E), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 36),
          PrimaryButton(
            label: 'Continue',
            onPressed: isMatch ? _nextStep : null,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Step 3.3: Name & Email
  // ----------------------------------------------------
  Widget _buildStep3NameAndEmail(bool isDark) {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final isNameValid = name.length >= 2;
    final isEmailFormatValid = _isEmailValid(email);
    final canContinue = isNameValid && isEmailFormatValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your name?",
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use your name and email for your transaction receipts and password recovery.',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ShakeWidget(
            key: _shakeKey,
            child: LiquidGlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FULL NAME',
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _nameFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        width: _nameFocus.hasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: _nameFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Mustapha Mele',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'EMAIL ADDRESS (REQUIRED)',
                    style: GoogleFonts.plusJakartaSans(
                      color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _emailInlineError != null
                            ? const Color(0xFFE11D48)
                            : _emailFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        width: _emailFocus.hasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: _emailFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                    ),
                    child: TextField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      onChanged: (_) {
                        if (_emailInlineError != null) {
                          setState(() => _emailInlineError = null);
                        } else {
                          setState(() {});
                        }
                      },
                      onSubmitted: (_) {
                        if (canContinue) _nextStep();
                      },
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. name@example.com',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (_emailInlineError != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFF43F5E), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _emailInlineError!,
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF43F5E), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Referral toggle
                  if (!_showReferralField)
                    GestureDetector(
                      onTap: () => setState(() => _showReferralField = true),
                      child: Text(
                        'Have a referral code?',
                        style: GoogleFonts.plusJakartaSans(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'REFERRAL CODE (OPTIONAL)',
                      style: GoogleFonts.plusJakartaSans(
                        color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0A101D) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _referralFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          width: _referralFocus.hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: _referralFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                      ),
                      child: TextField(
                        controller: _referralCtrl,
                        focusNode: _referralFocus,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter referral code',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: isDark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          PrimaryButton(
            label: 'Continue',
            onPressed: canContinue ? _nextStep : null,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Step 3.4: Select State
  // ----------------------------------------------------
  Widget _buildStep4State(bool isDark) {
    final filtered = _stateSearchQuery.isEmpty
        ? kNigerianStates
        : kNigerianStates.where((s) => s.toLowerCase().contains(_stateSearchQuery.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your state',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your state of residence. Required for localized network deals.',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF475569),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Search input
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _stateFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                    width: _stateFocus.hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: _stateFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: _stateFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white54 : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        focusNode: _stateFocus,
                        onChanged: (q) => setState(() => _stateSearchQuery = q),
                        style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search state (e.g. Lagos, Kano)...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // State list
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemBuilder: (context, idx) {
              final stateName = filtered[idx];
              final isSelected = _selectedState == stateName;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedState = stateName);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2457F5).withValues(alpha: isDark ? 0.2 : 0.1)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2457F5)
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
                    ),
                    boxShadow: isDark || isSelected
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stateName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : const Color(0xFF2457F5))
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF2457F5), size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Continue button anchored at bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: PrimaryButton(
            label: _selectedState != null ? 'Create Account' : 'Select a State to Continue',
            onPressed: _selectedState != null && !_loading
                ? () => _submitRegistration(requestPush: true)
                : null,
            loading: _loading,
          ),
        ),
      ],
    );
  }
}
