import re

with open('lib/screens/signup_wizard_screen.dart', 'r') as f:
    content = f.read()

# Add imports
if "import 'package:google_fonts/google_fonts.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:google_fonts/google_fonts.dart';\nimport 'package:flutter_animate/flutter_animate.dart';")

# Replace TextStyle( with GoogleFonts.plusJakartaSans(
content = content.replace('TextStyle(', 'GoogleFonts.plusJakartaSans(')

# Animated Progress Bar
old_progress = """                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF2457F5)
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),"""

new_progress = """                      child: AnimatedContainer(
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
                      ),"""
content = content.replace(old_progress, new_progress)

# Add focus nodes
old_focus = """  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();"""

new_focus = """  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _referralFocus = FocusNode();
  final FocusNode _stateFocus = FocusNode();"""
content = content.replace(old_focus, new_focus)

# Add listeners
old_listeners = """    _passwordFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
    _confirmPinFocus.addListener(() => setState(() {}));"""
new_listeners = """    _passwordFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
    _confirmPinFocus.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _referralFocus.addListener(() => setState(() {}));
    _stateFocus.addListener(() => setState(() {}));"""
content = content.replace(old_listeners, new_listeners)

# Dispose listeners
old_dispose = """    _passwordFocus.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();"""
new_dispose = """    _passwordFocus.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _referralFocus.dispose();
    _stateFocus.dispose();"""
content = content.replace(old_dispose, new_dispose)

# Add animate to children of PageView
old_pageview = """                    _buildStep1Password(isDark),
                    _buildStep2Pin(isDark),
                    _buildStep3NameAndEmail(isDark),
                    _buildStep4State(isDark),"""
new_pageview = """                    _buildStep1Password(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep2Pin(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep3NameAndEmail(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),
                    _buildStep4State(isDark).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutQuint),"""
content = content.replace(old_pageview, new_pageview)

# Name Input
old_name_input = """                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: _nameCtrl,"""
new_name_input = """                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _nameFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        width: _nameFocus.hasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: _nameFocus.hasFocus && !isDark
                          ? const [BoxShadow(color: Color(0x1F2563EB), blurRadius: 8, spreadRadius: 2)]
                          : [],
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,"""
content = content.replace(old_name_input, new_name_input)

# Email Input
old_email_input = """                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _emailInlineError != null
                            ? const Color(0xFFE11D48)
                            : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: _emailCtrl,"""
new_email_input = """                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A101D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _emailInlineError != null
                            ? const Color(0xFFE11D48)
                            : _emailFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        width: _emailFocus.hasFocus ? 1.5 : 1.0,
                      ),
                      boxShadow: _emailFocus.hasFocus && !isDark
                          ? const [BoxShadow(color: Color(0x1F2563EB), blurRadius: 8, spreadRadius: 2)]
                          : [],
                    ),
                    child: TextField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,"""
content = content.replace(old_email_input, new_email_input)

# Referral Input
old_referral_input = """                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0A101D) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: TextField(
                        controller: _referralCtrl,"""
new_referral_input = """                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0A101D) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _referralFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          width: _referralFocus.hasFocus ? 1.5 : 1.0,
                        ),
                        boxShadow: _referralFocus.hasFocus && !isDark
                            ? const [BoxShadow(color: Color(0x1F2563EB), blurRadius: 8, spreadRadius: 2)]
                            : [],
                      ),
                      child: TextField(
                        controller: _referralCtrl,
                        focusNode: _referralFocus,"""
content = content.replace(old_referral_input, new_referral_input)

# State Search Input
old_search_input = """              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (q) => setState(() => _stateSearchQuery = q),"""
new_search_input = """              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _stateFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                    width: _stateFocus.hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: _stateFocus.hasFocus && !isDark
                      ? const [BoxShadow(color: Color(0x1F2563EB), blurRadius: 8, spreadRadius: 2)]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: _stateFocus.hasFocus ? const Color(0xFF2563EB) : (isDark ? Colors.white54 : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        focusNode: _stateFocus,
                        onChanged: (q) => setState(() => _stateSearchQuery = q),"""
content = content.replace(old_search_input, new_search_input)

# Add missing style class if it causes issues
with open('lib/screens/signup_wizard_screen.dart', 'w') as f:
    f.write(content)
