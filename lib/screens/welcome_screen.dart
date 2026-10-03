import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/user_lookup_service.dart';
import '../utils/phone_validator.dart';
import '../widgets/auth_liquid_glass.dart';
import '../widgets/theme_toggle_button.dart';
import 'auth_password_screen.dart';
import 'signup_wizard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.initialPhone,
  });

  static const String route = '/welcome';

  final String? initialPhone;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null && widget.initialPhone!.isNotEmpty) {
      String init = widget.initialPhone!;
      if (init.startsWith('+234')) {
        init = init.substring(4);
      } else if (init.startsWith('234')) {
        init = init.substring(3);
      } else if (init.startsWith('0')) {
        init = init.substring(1);
      }
      _phoneCtrl.text = init;
    }

    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/brand/meledata-icon.png'), context);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _cleanInputPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('234') && clean.length > 10) {
      clean = '0${clean.substring(3)}';
    } else if (clean.length == 10 &&
        (clean.startsWith('7') || clean.startsWith('8') || clean.startsWith('9'))) {
      clean = '0$clean';
    }
    return clean;
  }

  String? _detectNetwork(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('234')) {
      clean = clean.substring(3);
    }
    if (!clean.startsWith('0')) {
      clean = '0$clean';
    }
    if (clean.length < 4) return null;
    final prefix = clean.substring(0, 4);

    const mtn = {
      '0803', '0806', '0703', '0706', '0813', '0816', '0810', '0814',
      '0903', '0906', '0913', '0916', '0704', '0702'
    };
    const airtel = {
      '0802', '0808', '0708', '0812', '0701', '0902', '0901', '0904',
      '0907', '0912'
    };
    const glo = {
      '0805', '0807', '0705', '0815', '0811', '0905', '0915'
    };
    const mobile9 = {
      '0809', '0818', '0817', '0909', '0908'
    };

    if (mtn.contains(prefix)) return 'MTN';
    if (airtel.contains(prefix)) return 'Airtel';
    if (glo.contains(prefix)) return 'GLO';
    if (mobile9.contains(prefix)) return '9mobile';
    return null;
  }

  Color _networkBadgeColor(String network) {
    switch (network) {
      case 'MTN':
        return const Color(0xFFFFCC00);
      case 'Airtel':
        return const Color(0xFFFF334B);
      case 'GLO':
        return const Color(0xFF10B981);
      case '9mobile':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF2563EB);
    }
  }

  void _onPhoneChanged(String val) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  Future<void> _handleContinue() async {
    if (_loading) return;

    final rawPhone = _phoneCtrl.text;
    final normalized = _cleanInputPhone(rawPhone);
    final validation = PhoneValidator.validate(normalized);

    if (!validation.isValid) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = validation.error;
      });
      _shakeKey.currentState?.shake();
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final phone = validation.cleanPhone;

    try {
      final res = await UserLookupService().lookup(phone);
      if (!mounted) return;

      final exists = res['exists'] == true;

      setState(() => _loading = false);

      if (exists) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AuthPasswordScreen(identifier: phone),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 320),
          ),
        );
      } else {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SignupWizardScreen(phone: phone),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 320),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      String message = 'Unable to connect to service. Check your internet connection.';
      final errStr = e.toString().toLowerCase();

      if (errStr.contains('429') || errStr.contains('rate limit')) {
        message = 'Too many attempts. Please wait a few moments and try again.';
      } else if (errStr.contains('timeout')) {
        message = 'Connection timed out. Please tap Continue to retry.';
      }

      setState(() {
        _loading = false;
        _errorMessage = message;
      });
      _shakeKey.currentState?.shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectedNet = _detectNetwork(_phoneCtrl.text);
    final isFocused = _phoneFocusNode.hasFocus;
    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Soft Neomorphic Ambient Light Blobs behind Hero Section
            Positioned(
              top: -30,
              left: -40,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.07),
                        blurRadius: 90,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -20,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.05),
                        blurRadius: 80,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Foreground Content
            SafeArea(
              child: Column(
                children: [
                  // Top Bar with Theme Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [ThemeToggleButton(size: 34)],
                    ),
                  ),

                  // Responsive Scrollable View
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            const SizedBox(height: 10),

                            // Tactile Hero Section: Floating Service Chips + Centered Logo Tile Anchor
                            SizedBox(
                              height: 240,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Card 1: Top Left, tilted -3° (Mini MTN SME Data badge)
                                  Positioned(
                                    top: 14,
                                    left: 12,
                                    child: Transform.rotate(
                                      angle: -3 * math.pi / 180,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 1.0,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0A0F172A),
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                            BoxShadow(
                                              color: Color(0x050F172A),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFFCC00),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'MTN 1GB',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ₦439',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Card 2: Top Right, tilted +2° ("Instant Top-Up" chip)
                                  Positioned(
                                    top: 22,
                                    right: 12,
                                    child: Transform.rotate(
                                      angle: 2 * math.pi / 180,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 1.0,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0A0F172A),
                                              blurRadius: 20,
                                              offset: Offset(0, 10),
                                            ),
                                            BoxShadow(
                                              color: Color(0x050F172A),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.bolt_rounded,
                                              color: Color(0xFF2563EB),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Instant Top-Up',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Sub-second',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Logo Tile (Center Anchor)
                                  Positioned(
                                    top: 76,
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE0E7FF),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF2563EB)
                                                .withValues(alpha: 0.18),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 6),
                                          ),
                                          const BoxShadow(
                                            color: Color(0x0A0F172A),
                                            blurRadius: 16,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Image.asset(
                                          'assets/brand/meledata_playstore_icon_512.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Card 3: Center Below Logo (Airtel & Glo bundle pill)
                                  Positioned(
                                    top: 178,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A0F172A),
                                            blurRadius: 18,
                                            offset: Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: Color(0x050F172A),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFF334B),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Airtel 1GB · ₦500',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '·',
                                              style: TextStyle(
                                                color: Color(0xFFCBD5E1),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Glo 3GB · ₦1,200',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Brand Title: "MELE DATA", 30sp, FontWeight.w900, #0F172A, letterSpacing: -0.8
                            Text(
                              'MELE DATA',
                              textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  color: theme.brightness == Brightness.dark 
                                      ? Colors.white 
                                      : const Color(0xFF0F172A),
                                ),
                            ),

                            const SizedBox(height: 4),

                            // Heading: "Seamless utilities at your fingertips", 16sp, FontWeight.w600, #334155
                            Text(
                              'Seamless utilities at your fingertips',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.brightness == Brightness.dark 
                                    ? Colors.white.withValues(alpha: 0.9) 
                                    : const Color(0xFF334155),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Subtitle: "Enter your mobile number to get instant access.", 13sp, #64748B
                            Text(
                              'Enter your mobile number to get instant access.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Interactive Tactile Input Field Container
                            ShakeWidget(
                              key: _shakeKey,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                    if (isFocused && !hasError)
                                      BoxShadow(
                                        color: const Color(0xFF2563EB)
                                            .withValues(alpha: 0.15),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                      ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocusNode,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  onChanged: _onPhoneChanged,
                                  onSubmitted: (_) => _handleContinue(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                    color: theme.brightness == Brightness.dark 
                                        ? Colors.white 
                                        : const Color(0xFF0F172A),
                                  ),
                                  cursorColor: const Color(0xFF2563EB),
                                  decoration: InputDecoration(
                                    hintText: '801 234 5678',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: theme.brightness == Brightness.dark 
                                          ? Colors.white38 
                                          : const Color(0xFF94A3B8),
                                    ),
                                    filled: true,
                                    fillColor: theme.cardColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: hasError ? const Color(0xFFEF4444) : (theme.brightness == Brightness.dark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                        width: 1.2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: hasError ? const Color(0xFFEF4444) : (theme.brightness == Brightness.dark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: hasError ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                                        width: 1.2,
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 0,
                                      minHeight: 0,
                                    ),
                                    prefixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 14),
                                        // Compact Nigeria Flag chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.brightness == Brightness.dark 
                                                ? const Color(0xFF1E293B) 
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                '🇳🇬',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '+234',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.brightness == Brightness.dark 
                                                      ? Colors.white 
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Vertical separator line
                                        Container(
                                          height: 24,
                                          width: 1,
                                          color: theme.brightness == Brightness.dark 
                                              ? Colors.white12 
                                              : const Color(0xFFE2E8F0),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                    ),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (detectedNet != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _networkBadgeColor(detectedNet)
                                                  .withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _networkBadgeColor(detectedNet)
                                                    .withValues(alpha: 0.45),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              detectedNet.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                color: _networkBadgeColor(detectedNet),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (_phoneCtrl.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.cancel_rounded,
                                              size: 18,
                                            ),
                                            color: const Color(0xFF94A3B8),
                                            onPressed: () {
                                              _phoneCtrl.clear();
                                              setState(() => _errorMessage = null);
                                            },
                                          ),
                                      ],
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Error Display
                            if (hasError) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 15,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFEF4444),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Signature Tactile Primary Button (The Pressable Anchor)
                            _TactilePrimaryButton(
                              loading: _loading,
                              onPressed: _handleContinue,
                            ),

                            const SizedBox(height: 24),

                            // Minimal Trust Footer Pill
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fast, secure & automated delivery',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signature Tactile Primary Button: Full width, height 56px, borderRadius 16px,
/// rich deep electric royal blue gradient with micro bounce interaction.
class _TactilePrimaryButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _TactilePrimaryButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_TactilePrimaryButton> createState() => _TactilePrimaryButtonState();
}

class _TactilePrimaryButtonState extends State<_TactilePrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) {
        HapticFeedback.heavyImpact();
        setState(() => _pressed = true);
      },
      onTapUp: widget.loading ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF97316), // Premium Orange
                Color(0xFF3B82F6), // Premium Blue
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
