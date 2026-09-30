class PromoCode {
  final int id;
  final String code;
  final String? description;
  final double discountAmount;
  final bool isPercentage;
  final int maxUsesPerUser;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  PromoCode({
    required this.id,
    required this.code,
    this.description,
    required this.discountAmount,
    required this.isPercentage,
    required this.maxUsesPerUser,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      id: json['id'],
      code: json['code'],
      description: json['description'],
      discountAmount: (json['discount_amount'] as num).toDouble(),
      isPercentage: json['is_percentage'] ?? false,
      maxUsesPerUser: json['max_uses_per_user'] ?? 1,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class UserPromo {
  final int id;
  final String status;
  final DateTime? usedAt;
  final PromoCode promoCode;

  UserPromo({
    required this.id,
    required this.status,
    this.usedAt,
    required this.promoCode,
  });

  factory UserPromo.fromJson(Map<String, dynamic> json) {
    return UserPromo(
      id: json['id'],
      status: json['status'],
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      promoCode: PromoCode.fromJson(json['promo_code']),
    );
  }
}
