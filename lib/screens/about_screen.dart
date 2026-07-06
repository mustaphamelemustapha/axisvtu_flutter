import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/concentric_circles_bg.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const String route = '/about';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.2.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white;

    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 24),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'About MELE DATA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    const SizedBox(height: 10),
          
          // Version Info Cards
          _InfoCard(
            label: 'App Version',
            value: 'V$_version',
            cardBg: cardBg,
            textMain: textMain,
            textDim: textDim,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            label: 'App Update',
            value: 'Latest Version',
            valueColor: Colors.greenAccent,
            cardBg: cardBg,
            textMain: textMain,
            textDim: textDim,
          ),
          
          const SizedBox(height: 24),
          Text(
            'This will notify you if an update is available. Keeping your MELE DATA app updated ensures you get the most out of our services.',
            style: TextStyle(
              color: textDim,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 60),
          
          // Credits Section
          Center(
            child: Column(
              children: [
                Text(
                  'Designed by',
                  style: TextStyle(
                    color: textDim,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mustapha Mele',
                  style: TextStyle(
                    color: textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Founder MMTechGlobe',
                  style: TextStyle(
                    color: textDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Certification Section
          Center(
            child: Column(
              children: [
                Text(
                  'Certified by',
                  style: TextStyle(
                    color: textDim,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                // CAC Logo Only
                Image.asset(
                  'assets/brand/cac_logo.jpg',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
    this.valueColor,
    required this.cardBg,
    required this.textMain,
    required this.textDim,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Color cardBg;
  final Color textMain;
  final Color textDim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textMain.withValues(alpha: 0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textDim,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
