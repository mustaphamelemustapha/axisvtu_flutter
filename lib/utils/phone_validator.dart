class PhoneValidationResult {
  final bool isValid;
  final String? error;
  final String cleanPhone;

  const PhoneValidationResult({
    required this.isValid,
    this.error,
    required this.cleanPhone,
  });
}

class PhoneValidator {
  static const Set<String> _validPrefixes = {
    '070',
    '080',
    '081',
    '090',
    '091',
  };

  /// Cleans raw input by removing spaces, hyphens, and parentheses.
  static String clean(String raw) {
    return raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Validates a Nigerian phone number according to strict requirements:
  /// - Must start with 0
  /// - Must not be +234 or 234
  /// - Must have 11 digits
  /// - Must start with a valid Nigerian mobile network prefix (070, 080, 081, 090, 091)
  static PhoneValidationResult validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const PhoneValidationResult(
        isValid: false,
        error: 'Please enter your phone number',
        cleanPhone: '',
      );
    }

    // Check if user entered country code format
    if (trimmed.startsWith('+234') || trimmed.startsWith('234')) {
      return const PhoneValidationResult(
        isValid: false,
        error: 'Enter your number starting with 0',
        cleanPhone: '',
      );
    }

    final cleaned = clean(trimmed);

    // Check for non-digit characters
    if (!RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return PhoneValidationResult(
        isValid: false,
        error: 'Phone number can only contain digits',
        cleanPhone: cleaned,
      );
    }

    if (!cleaned.startsWith('0')) {
      return PhoneValidationResult(
        isValid: false,
        error: 'Enter your number starting with 0',
        cleanPhone: cleaned,
      );
    }

    if (cleaned.length < 11) {
      return PhoneValidationResult(
        isValid: false,
        error: 'Phone number must be 11 digits (${cleaned.length}/11)',
        cleanPhone: cleaned,
      );
    }

    if (cleaned.length > 11) {
      return PhoneValidationResult(
        isValid: false,
        error: 'Phone number must be exactly 11 digits',
        cleanPhone: cleaned,
      );
    }

    final prefix = cleaned.substring(0, 3);
    if (!_validPrefixes.contains(prefix)) {
      return PhoneValidationResult(
        isValid: false,
        error: 'Please enter a valid Nigerian network number (e.g. 080, 081, 070, 090, 091)',
        cleanPhone: cleaned,
      );
    }

    return PhoneValidationResult(
      isValid: true,
      error: null,
      cleanPhone: cleaned,
    );
  }
}
