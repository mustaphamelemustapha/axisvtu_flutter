import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ElitePhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final String network;
  final VoidCallback? onContactTap;
  final Function(String)? onChanged;

  const ElitePhoneInput({
    super.key,
    required this.controller,
    required this.network,
    this.onContactTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF08101F) : const Color(0xFFCBD5E1).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: _NetworkIcon(network: network, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: 'Enter Phone Number',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty && onContactTap != null) {
                return IconButton(
                  onPressed: onContactTap,
                  icon: Icon(
                    Icons.contact_page_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 26,
                  ),
                );
              }
              return IconButton(
                onPressed: () => controller.clear(),
                icon: Icon(
                  Icons.cancel_rounded,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _NetworkIcon extends StatelessWidget {
  final String network;
  final double size;
  const _NetworkIcon({required this.network, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = switch (network.toLowerCase()) {
      'mtn' => 'assets/networks/mtn.svg',
      'airtel' => 'assets/networks/airtel.svg',
      'glo' => 'assets/networks/glo.svg',
      '9mobile' => 'assets/networks/9mobile.svg',
      _ => '',
    };

    if (asset.isEmpty) {
      return Icon(Icons.cell_tower_rounded, size: size * 0.7);
    }

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          asset,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => Icon(Icons.cell_tower_rounded, size: size * 0.7),
        ),
      ),
    );
  }
}
