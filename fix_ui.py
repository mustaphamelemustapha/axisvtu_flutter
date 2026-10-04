import re

with open('lib/screens/signup_wizard_screen.dart', 'r') as f:
    content = f.read()

# 1. Update title tracking
content = content.replace('letterSpacing: -0.6,', 'letterSpacing: -1.0,')
content = content.replace('height: 1.45,', 'height: 1.5,')

# 2. Make all input border radius 16 (currently some are 14)
content = content.replace('BorderRadius.circular(14)', 'BorderRadius.circular(16)')

# 3. Enhance shadows in ALL steps
def replace_shadow(match):
    # Match the block for boxShadow. It might be complex, so we just regex replace the ternary for shadow
    return "boxShadow: " + match.group(1) + " ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],"

content = re.sub(r'boxShadow:\s*([a-zA-Z0-9_\.]+)\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[.*?\]\s*:\s*\[\],', replace_shadow, content, flags=re.DOTALL)

# Handle the specific ones in Step 1 and 2
content = re.sub(r'boxShadow:\s*_passwordFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[\s*BoxShadow\([^]]+\)\s*\]\s*:\s*\[\],', 'boxShadow: _passwordFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)
content = re.sub(r'boxShadow:\s*_pinFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[\s*BoxShadow\([^]]+\)\s*\]\s*:\s*\[\],', 'boxShadow: _pinFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)
content = re.sub(r'boxShadow:\s*_confirmPinFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[\s*BoxShadow\([^]]+\)\s*\]\s*:\s*\[\],', 'boxShadow: _confirmPinFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)

# Name/Email/Referral Shadows which use the first regex but might have missed
content = re.sub(r'boxShadow:\s*_nameFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[BoxShadow\([^]]+\)\]\s*:\s*\[\],', 'boxShadow: _nameFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)
content = re.sub(r'boxShadow:\s*_emailFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[BoxShadow\([^]]+\)\]\s*:\s*\[\],', 'boxShadow: _emailFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)
content = re.sub(r'boxShadow:\s*_referralFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[BoxShadow\([^]]+\)\]\s*:\s*\[\],', 'boxShadow: _referralFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)
content = re.sub(r'boxShadow:\s*_stateFocus\.hasFocus\s*&&\s*!isDark\s*\?\s*const\s*\[BoxShadow\([^]]+\)\]\s*:\s*\[\],', 'boxShadow: _stateFocus.hasFocus ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12), blurRadius: 12, spreadRadius: 2)] : [],', content)

# 4. Standardize text field paddings in Step 3 and 4 to match Step 1 (which uses 56px height)
# In Step 3, we have `padding: const EdgeInsets.symmetric(horizontal: 14)` on the AnimatedContainer
content = content.replace('padding: const EdgeInsets.symmetric(horizontal: 14),', 'height: 56, padding: const EdgeInsets.symmetric(horizontal: 14),')
# But wait, TextField has contentPadding.
content = content.replace('contentPadding: const EdgeInsets.symmetric(vertical: 14)', 'contentPadding: const EdgeInsets.symmetric(vertical: 16)')

with open('lib/screens/signup_wizard_screen.dart', 'w') as f:
    f.write(content)

