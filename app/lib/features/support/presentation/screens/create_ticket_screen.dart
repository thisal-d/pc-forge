import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/data/order_service.dart';
import '../../data/support_service.dart';
import 'ai_support_chat_screen.dart';

class CreateTicketScreen extends StatefulWidget {
  final int? initialOrderId;

  const CreateTicketScreen({super.key, this.initialOrderId});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  int? _selectedOrderId;
  String? _selectedProductName;
  String _selectedIssueType = 'Overheating';
  bool _isSubmitting = false;

  final List<String> _issueTypes = [
    'Overheating',
    'Hardware Failure',
    'Won\'t Turn On / No POST',
    'Damaged on Arrival',
    'General Inquiry',
  ];

  final List<String> _sampleImages = [
    'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOrderId = widget.initialOrderId;

    final orders = OrderService.instance.orders;
    if (orders.isNotEmpty) {
      if (_selectedOrderId != null && orders.any((o) => o.orderId == _selectedOrderId)) {
        final matched = orders.firstWhere((o) => o.orderId == _selectedOrderId);
        if (matched.items.isNotEmpty) {
          _selectedProductName = matched.items.first.productName;
        }
      } else {
        _selectedOrderId = orders.first.orderId;
        if (orders.first.items.isNotEmpty) {
          _selectedProductName = orders.first.items.first.productName;
        }
      }
    }

    if (_subjectController.text.isEmpty) {
      _subjectController.text = 'GPU is overheating';
      _descriptionController.text =
          'The GPU temperatures reach over 90°C during gaming sessions and cause sudden shutdowns.';
      _attachmentUrlController.text = _sampleImages[0];
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await SupportService.instance.createServiceRequest(
        orderId: _selectedOrderId,
        productName: _selectedProductName,
        problemCategory: _selectedIssueType,
        problemDescription: _descriptionController.text.trim(),
        troubleshootingSummary: _subjectController.text.trim(),
        attemptCount: 1,
        attachmentUrl: _attachmentUrlController.text.trim().isNotEmpty
            ? _attachmentUrlController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Request submitted successfully!'),
            backgroundColor: AppColors.stockGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit service request: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = OrderService.instance.orders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submit Service Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AI Assistant Recommended Banner
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preferred: Chat with AI Agent',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Get instant warranty checks, real-time troubleshooting, and automated service request intake.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AiSupportChatScreen(orderId: _selectedOrderId),
                                ),
                              );
                            },
                            child: const Text(
                              'Switch to AI Chat Support \u2192',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Order Selector
              const Text(
                'Purchased Order Reference',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              if (orders.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _selectedOrderId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.receipt_long_rounded),
                  ),
                  items: orders.map((order) {
                    return DropdownMenuItem<int>(
                      value: order.orderId,
                      child: Text('Order #ORD-${order.orderId} (LKR ${order.totalAmount.toStringAsFixed(2)})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedOrderId = val;
                      final selected = orders.firstWhere((o) => o.orderId == val);
                      if (selected.items.isNotEmpty) {
                        _selectedProductName = selected.items.first.productName;
                      }
                    });
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.secondaryText, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No previous orders found. Creating general technical inquiry.',
                          style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // 2. Component Name
              if (_selectedProductName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.memory_rounded, color: AppColors.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked Component: $_selectedProductName',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Issue Type
              const Text(
                'Issue Category',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _issueTypes.map((type) {
                  final isSelected = _selectedIssueType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedIssueType = type);
                    },
                    selectedColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primaryDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryBlue : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 4. Subject & Description
              const Text(
                'Subject / Summary *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  hintText: 'e.g. GPU thermal throttling or no display signal',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a subject' : null,
              ),

              const SizedBox(height: 16),

              const Text(
                'Detailed Hardware Issue Description *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe diagnostic steps, system specs, when the issue occurs...',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please describe the issue' : null,
              ),

              const SizedBox(height: 16),

              // 5. Photo Attachment
              const Text(
                'Photo / Diagnostics Attachment URL',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Attach an image URL of error screen, physical damage, or benchmark temp',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _attachmentUrlController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  prefixIcon: const Icon(Icons.attach_file_rounded),
                  suffixIcon: _attachmentUrlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _attachmentUrlController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),

              // Quick sample image picker buttons
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Sample photos:', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                  const SizedBox(width: 8),
                  for (int i = 0; i < _sampleImages.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text('Photo ${i + 1}', style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          _attachmentUrlController.text = _sampleImages[i];
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ],
              ),

              if (_attachmentUrlController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    _attachmentUrlController.text.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                      color: AppColors.specPillBackground,
                      alignment: Alignment.center,
                      child: const Text('Invalid photo preview URL', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Service Request',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
