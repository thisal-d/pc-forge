import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/support_service.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final bool isManual;

  const CreateServiceRequestScreen({
    super.key,
    this.isManual = false,
  });

  @override
  State<CreateServiceRequestScreen> createState() => _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;

  // Appointment Date & Time (Loaded from configured master slots)
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedSlotId;
  String? _selectedTime;
  List<Map<String, dynamic>> _availableSlots = [];
  bool _isCheckingAvailability = false;
  Map<String, dynamic>? _availability;

  String get _formattedSelectedDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _checkDateAvailability(_formattedSelectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkDateAvailability(String dateStr) async {
    setState(() => _isCheckingAvailability = true);
    try {
      final info = await SupportService.instance.checkAvailability(dateStr);
      List<Map<String, dynamic>> slots = [];
      if (info['slots'] is List && (info['slots'] as List).isNotEmpty) {
        slots = (info['slots'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        slots = await SupportService.instance.fetchTimeSlotsForDate(dateStr);
      }

      int? autoSlotId;
      String? autoTime = _selectedTime;

      final openSlots = slots.where((s) => s['isAvailable'] == true && s['isClosed'] != true).toList();
      if (openSlots.isNotEmpty) {
        final existingMatch = openSlots.where((s) => s['slotId'] == _selectedSlotId).firstOrNull;
        final chosen = existingMatch ?? openSlots.first;
        autoSlotId = chosen['slotId'] as int?;
        autoTime = (chosen['label'] as String?)?.isNotEmpty == true
            ? chosen['label'] as String
            : '${chosen['startTime']} - ${chosen['endTime']}';
      } else if (slots.isNotEmpty) {
        autoSlotId = null;
        autoTime = null;
      }

      if (mounted) {
        setState(() {
          _availability = info;
          _availableSlots = slots;
          _selectedSlotId = autoSlotId;
          _selectedTime = autoTime ?? _selectedTime ?? '10:00 AM';
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
    if (_availability != null && _availability!['isAvailable'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected date is fully booked. Please pick another date.'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    if (_availableSlots.isNotEmpty && _selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available time slot.'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final rawTitle = _titleController.text.trim();
      final rawDesc = _descriptionController.text.trim();

      // Simple fallback if both are blank so request has a friendly label
      final finalTitle = rawTitle.isNotEmpty
          ? rawTitle
          : (rawDesc.isNotEmpty ? rawDesc : 'General PC Service Request');

      await SupportService.instance.createServiceRequest(
        title: finalTitle,
        description: rawDesc.isNotEmpty ? rawDesc : null,
        preferredDate: _formattedSelectedDate,
        preferredTime: _selectedTime ?? 'Standard',
        slotId: _selectedSlotId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Request submitted successfully! Status: Booked'),
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
    final isAvailable = _availability == null || _availability!['isAvailable'] == true;
    final remainingSlots = _availability?['remainingSlots'] ?? (_availableSlots.isNotEmpty ? _availableSlots.fold<int>(0, (acc, s) => acc + ((s['remainingSlots'] as int?) ?? 0)) : 10);
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
              // Friendly helper card for non-technical users
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent_rounded, size: 28, color: AppColors.primaryBlue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simple & Hassle-Free',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No technical PC knowledge required. All form fields are optional — just tell us what happened in your own words and we will take care of the rest!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Title (Optional)
              const Text(
                'Title (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g. PC won\'t turn on, loud fan noise, screen freezes',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  prefixIcon: const Icon(Icons.title_rounded, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Description (Optional)
              const Text(
                'Description (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe what happened in your own words. How did the issue start? Any weird sounds or lights?',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Appointment Date & Time (Required)
              const Row(
                children: [
                  Text(
                    'Appointment Date & Time',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.alertRed),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date Picker Card
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAvailable ? AppColors.border : AppColors.alertRed),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 22, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Appointment Date (Tap to change)',
                              style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formattedSelectedDate,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 24, color: AppColors.secondaryText),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Capacity and Status Banner
              if (_isCheckingAvailability)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Checking slot availability...', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                    ],
                  ),
                )
              else if (_availability != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable ? AppColors.stockGreen.withValues(alpha: 0.08) : AppColors.alertRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAvailable ? AppColors.stockGreen.withValues(alpha: 0.25) : AppColors.alertRed.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: isAvailable ? AppColors.stockGreen : AppColors.alertRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAvailable
                              ? '$remainingSlots capacity available on this date'
                              : 'Fully booked ($bookedCount slots used). Please pick another date.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isAvailable ? AppColors.stockGreen : AppColors.alertRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Configured Time Slots Section
              const Text(
                'Available Time Slots',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),

              if (_availableSlots.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableSlots.map((slot) {
                    final slotId = slot['slotId'] as int?;
                    final isSelected = _selectedSlotId != null && _selectedSlotId == slotId;
                    final isSlotAvail = slot['isAvailable'] == true && slot['isClosed'] != true;
                    final remaining = slot['remainingSlots'] ?? 0;
                    final label = (slot['label'] as String?)?.isNotEmpty == true
                        ? slot['label'] as String
                        : '${slot['startTime']} - ${slot['endTime']}';

                    return InkWell(
                      onTap: isSlotAvail
                          ? () {
                              setState(() {
                                _selectedSlotId = slotId;
                                _selectedTime = label;
                              });
                            }
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : !isSlotAvail
                                  ? const Color(0xFFF1F5F9)
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : !isSlotAvail
                                    ? const Color(0xFFE2E8F0)
                                    : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : !isSlotAvail
                                      ? AppColors.secondaryText
                                      : AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : !isSlotAvail
                                            ? AppColors.secondaryText
                                            : AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  !isSlotAvail
                                      ? (slot['isClosed'] == true ? 'Closed' : 'Full')
                                      : '$remaining slots left',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : !isSlotAvail
                                            ? AppColors.alertRed
                                            : AppColors.stockGreen,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (!_isCheckingAvailability)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 20, color: AppColors.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTime ?? 'Standard Appointment (10:00 AM)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitServiceRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Submit Service Request',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
