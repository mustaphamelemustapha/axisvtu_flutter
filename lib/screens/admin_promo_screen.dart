import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class AdminPromoScreen extends StatefulWidget {
  static const String route = '/admin/promos';

  const AdminPromoScreen({super.key});

  @override
  State<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _AdminPromoScreenState extends State<AdminPromoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _maxUsesUserCtrl = TextEditingController(text: '1');
  final _maxUsesTotalCtrl = TextEditingController(text: '100');
  
  bool _isPercentage = false;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _maxUsesUserCtrl.dispose();
    _maxUsesTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _createPromo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null) throw Exception("Not authenticated");

      final adminService = AdminService(token: token);
      await adminService.createPromo({
        'code': _codeCtrl.text.trim().toUpperCase(),
        'description': _descCtrl.text.trim(),
        'discount_amount': double.parse(_discountCtrl.text.trim()),
        'is_percentage': _isPercentage,
        'max_uses_per_user': int.parse(_maxUsesUserCtrl.text.trim()),
        'max_total_uses': int.parse(_maxUsesTotalCtrl.text.trim()),
        'is_active': _isActive,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo Code created successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back after creation
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Promo Code')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AxisTextField(
                controller: _codeCtrl,
                label: 'Promo Code (e.g. LAUNCH20)',
                textCapitalization: TextCapitalization.characters,
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AxisTextField(
                controller: _descCtrl,
                label: 'Description',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AxisTextField(
                      controller: _discountCtrl,
                      label: 'Discount Amount',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Percentage?'),
                      Switch(
                        value: _isPercentage,
                        onChanged: (val) => setState(() => _isPercentage = val),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AxisTextField(
                      controller: _maxUsesUserCtrl,
                      label: 'Max uses per user',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AxisTextField(
                      controller: _maxUsesTotalCtrl,
                      label: 'Total max uses',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Is Active?'),
                  Switch(
                    value: _isActive,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Create Promo',
                  onPressed: _isLoading ? null : _createPromo,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
