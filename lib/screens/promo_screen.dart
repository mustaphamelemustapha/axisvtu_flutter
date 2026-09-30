import 'package:provider/provider.dart';
import '../state/session.dart';
import 'package:flutter/material.dart';
import '../models/promo.dart';
import '../services/promo_service.dart';
import 'package:intl/intl.dart';
import '../theme/axis_tokens.dart';

class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> {
  final _codeController = TextEditingController();
  
  PromoService get _promoService {
    final token = context.read<Session>().token;
    if (token == null) throw Exception("Not authenticated");
    return PromoService(token: token);
  }
  
  String _errorText = '';
  bool _isLoading = false;
  bool _isClaiming = false;
  List<UserPromo> _promos = [];

  @override
  void initState() {
    super.initState();
    _fetchPromos();
  }

  Future<void> _fetchPromos() async {
    setState(() => _isLoading = true);
    try {
      final promos = await _promoService.getMyPromos();
      setState(() {
        _promos = promos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error gently or ignore if empty
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _claimCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorText = 'Enter a promo code.';
      });
      return;
    } 

    setState(() {
      _errorText = '';
      _isClaiming = true;
    });

    try {
      final newPromo = await _promoService.claimPromo(_codeController.text.trim());
      setState(() {
        _promos.insert(0, newPromo);
        _isClaiming = false;
        _codeController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo code claimed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceAll('Exception: ', '');
        _isClaiming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF151B2B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF2A3448) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                          border: isDark ? null : Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
                      ),
                    ),
                  ),
                  Text(
                    'Promo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Claim Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Have a promo code?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Redeem a code to unlock discounted plans and rewards.',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.transparent),
                                  ),
                                  child: TextField(
                                    controller: _codeController,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'ENTER CODE',
                                      hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5), fontWeight: FontWeight.w700),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _isClaiming ? null : _claimCode,
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  decoration: BoxDecoration(
                                    color: _isClaiming ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isClaiming
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Claim',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorText,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text(
                      'Your promos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Promos List or Empty State
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_promos.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_activity_outlined, size: 48, color: subtitleColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No promos yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Claim a promo code above to get discounts on your next purchase.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: subtitleColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _promos.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final promo = _promos[index];
                          final isUsed = promo.status == 'USED';
                          
                          // Format amount
                          final amountText = promo.promoCode.isPercentage 
                              ? '${promo.promoCode.discountAmount.toStringAsFixed(0)}%' 
                              : '₦${promo.promoCode.discountAmount.toStringAsFixed(0)}';
                              
                          // Format date
                          final dateText = isUsed 
                              ? (promo.usedAt != null ? 'Used ${DateFormat('MMM d').format(promo.usedAt!)}' : 'Used')
                              : 'Claimed ${DateFormat('MMM d').format(promo.promoCode.createdAt)}';

                          return _buildPromoCard(
                            title: promo.promoCode.code,
                            subtitle: promo.promoCode.description ?? 'Special discount code.',
                            statusLabel: isUsed ? 'Used' : 'Ready to use',
                            statusColor: isUsed ? subtitleColor : const Color(0xFF16A34A),
                            statusBgColor: isUsed 
                                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                                : const Color(0xFF16A34A).withOpacity(0.1),
                            priceLabel: amountText,
                            dateLabel: dateText,
                            isDark: isDark,
                            cardColor: cardColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            borderColor: borderColor,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  }

  Widget _buildPromoCard({
    required String title,
    required String subtitle,
    String? actionLabel,
    required String statusLabel,
    required Color statusColor,
    required Color statusBgColor,
    required String priceLabel,
    required String dateLabel,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              if (actionLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildPill(statusLabel, statusColor, statusBgColor),
              const SizedBox(width: 8),
              _buildPill(
                  priceLabel,
                  isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              const SizedBox(width: 8),
              _buildPill(
                  dateLabel,
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
