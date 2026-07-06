import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/services_service.dart';
import '../state/session.dart';
import 'electricity_screen.dart';
import 'electricity_amount_screen.dart';
import '../widgets/purchase_loading_overlay.dart';
import '../services/api_client.dart';

class ElectricityMeterScreen extends StatefulWidget {
  final ElectricityProvider provider;

  const ElectricityMeterScreen({
    super.key,
    required this.provider,
  });

  @override
  State<ElectricityMeterScreen> createState() => _ElectricityMeterScreenState();
}

class _ElectricityMeterScreenState extends State<ElectricityMeterScreen> {
  final TextEditingController _meterCtrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _meterCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyMeter() async {
    final token = (context.read<SessionController>().token ?? '').trim();
    if (token.isEmpty) return;

    final meterNumber = _meterCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (meterNumber.length < 5) {
      setState(() => _error = 'Enter a valid meter number.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final res = await ServicesService(token: token).verifyElectricity(
        disco: widget.provider.discoId,
        meterType: widget.provider.type,
        meterNumber: meterNumber,
      );
      final ok = res['ok'] == true;
      
      if (!mounted) return;
      
      if (ok) {
        final customerName = (res['customer_name'] ?? '').toString().trim();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ElectricityAmountScreen(
              provider: widget.provider,
              meterNumber: meterNumber,
              customerName: customerName,
            ),
          ),
        );
      } else {
        setState(() {
          _error = (res['message'] ?? 'Unable to verify meter number.').toString();
        });
      }
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      if (!mounted) return;
      setState(() {
        _error = msg.isNotEmpty ? msg : 'Unable to verify meter number right now.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141E) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Electricity',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Provider Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2638) : Colors.white,
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)
                  ),
                ),
                child: ClipOval(
                  child: Icon(Icons.electrical_services, color: isDark ? Colors.white54 : Colors.grey, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              // Provider Name
              Text(
                widget.provider.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Biller Product Field (Static)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Biller product',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Token Purchase',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Meter Number Field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter Meter Number',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _error != null ? Colors.red.withOpacity(0.5) : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _meterCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '0000000000000000',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verifyMeter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _verifying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
