import 'package:flutter/material.dart';

import 'purchase_auth_service.dart';

class PinGuard {
  const PinGuard._();

  static Future<bool> authorizeDebit({
    required BuildContext context,
    String reason = 'purchase',
  }) {
    return PurchaseAuthService.authorizePin(
      context: context,
      reason: reason,
    );
  }
}
