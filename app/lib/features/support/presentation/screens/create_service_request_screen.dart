import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/data/order_service.dart';
import '../../data/support_service.dart';
import 'ai_support_chat_screen.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final int? initialOrderId;

  const CreateServiceRequestScreen({super.key, this.initialOrderId});

  @override
  State<CreateServiceRequestScreen> createState() => _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  int? _selectedOrderId;
  String? _selectedProductName;
  String _selectedIssueType = 'Overheating';
  bool _isSubmitting = false;

  // Appointment Date & Time (9 AM - 6 PM, max 10 per day)
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '10:00 AM';
  bool _isCheckingAvailability = false;
  Map<String, dynamic>? _availability;

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
  ];

  final List<String> _issueTypes = [
    'Overheating',
    'Hardware Failure',
    'Won\'t Turn On / No POST',
    'Damaged on Arrival',
    'General Inquiry',
  ];

  String get _formattedSelectedDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

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

    _checkDateAvailability(_formattedSelectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkDateAvailability(String dateStr) async {
    setState(() => _isCheckingAvailability = true);
    try {
      final info = await SupportService.instance.checkAvailability(dateStr);
      if (mounted) {
        setState(() {
          _availability = info;
          _isCheckingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingAvailability = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _checkDateAvailability(_formattedSelectedDate);
    }
  }

  Future<void> _submitServiceRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_availability != null && _availability!['isAvailable'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected date is fully booked (10/10 slots filled). Please pick another date.'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final titleText = _titleController.text.trim();
      final descText = _descriptionController.text.trim();

      await SupportService.instance.createServiceRequest(
        title: titleText,
        description: descText.isNotEmpty ? descText : null,
        problemDescription: descText.isNotEmpty ? descText : titleText,
        orderId: _selectedOrderId,
        productName: _selectedProductName,
        problemCategory: _selectedIssueType,
        troubleshootingSummary: titleText,
        preferredDate: _formattedSelectedDate,
        preferredTime: _selectedTime,
        attemptCount: 1,
        attachmentUrl: _attachmentUrlController.text.trim().isNotEmpty
            ? _attachmentUrlController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Request submitted successfully! Status: Pending'),
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
    final isAvailable = _availability == null || _availability!['isAvailable'] == true;
    final remainingSlots = _availability?['remainingSlots'] ?? 10;
    final bookedCount = _availability?['bookedCount'] ?? 0;

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
              // Optional AI Troubleshooting Banner
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
                            'Want step-by-step diagnostic guidance?',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Chat with our AI diagnostic assistant for real-time troubleshooting before booking.',
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
                              'Switch to AI Diagnostic Chat \u2192',
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

              // 1. Title (Required)
              const Text(
                'Title *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'e.g. PC won\'t boot / GPU display fault',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title for the service request' : null,
              ),

              const SizedBox(height: 16),

              // 2. Description (Optional)
              const Text(
                'Description (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Provide any additional symptoms or details (optional)...',
                ),
              ),

              const SizedBox(height: 16),

              // 3. Appointment Date & Time Slot (9 AM - 6 PM, max 10 per day)
              const Text(
                'Appointment Date & Time (9:00 AM - 6:00 PM) *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAvailable ? AppColors.border : AppColors.alertRed),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formattedSelectedDate,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTime,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _timeSlots.map((time) {
                        return DropdownMenuItem<String>(
                          value: time,
                          child: Text(time, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTime = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isCheckingAvailability)
                const Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Checking date capacity...', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                  ],
                )
              else if (_availability != null)
                Text(
                  isAvailable
                      ? '$remainingSlots of 10 appointment slots available on this date'
                      : 'Fully booked ($bookedCount/10 slots used). Maximum 10 requests allowed per day.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? AppColors.stockGreen : AppColors.alertRed,
                  ),
                ),

              const SizedBox(height: 16),

              // 4. Order Selector (Optional if bought from store)
              const Text(
                'Purchased Order Reference (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final orderItems = <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Order (External / Store PC)'),
                    ),
                    ...orders.map((order) {
                      return DropdownMenuItem<int?>(
                        value: order.orderId,
                        child: Text('Order #ORD-${order.orderId} (LKR ${order.totalAmount.toStringAsFixed(2)})'),
                      );
                    }),
                  ];

                  if (_selectedOrderId != null && !orders.any((o) => o.orderId == _selectedOrderId)) {
                    orderItems.add(
                      DropdownMenuItem<int?>(
                        value: _selectedOrderId,
                        child: Text('Order #ORD-$_selectedOrderId'),
                      ),
                    );
                  }

                  return DropdownButtonFormField<int?>(
                    initialValue: _selectedOrderId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.receipt_long_rounded),
                    ),
                    items: orderItems,
                    onChanged: (val) {
                      setState(() {
                        _selectedOrderId = val;
                        if (val != null && orders.any((o) => o.orderId == val)) {
                          final selected = orders.firstWhere((o) => o.orderId == val);
                          if (selected.items.isNotEmpty) {
                            _selectedProductName = selected.items.first.productName;
                          }
                        } else {
                          _selectedProductName = null;
                        }
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 16),

              // 5. Issue Category
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

              // 6. Photo Attachment
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
                  onPressed: (_isSubmitting || !isAvailable) ? null : _submitServiceRequest,
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

// Backward-compatibility alias
typedef CreateTicketScreen = CreateServiceRequestScreen;

