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

  // Appointment Date & Time (Optional, 9 AM - 6 PM, max 10 per day)
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '10:00 AM';
  bool _includeAppointment = true;
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

  String get _formattedSelectedDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    if (_includeAppointment) {
      _checkDateAvailability(_formattedSelectedDate);
    }
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
    if (_includeAppointment && _availability != null && _availability!['isAvailable'] == false) {
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
      final rawTitle = _titleController.text.trim();
      final rawDesc = _descriptionController.text.trim();

      // Simple fallback if both are blank so request has a friendly label
      final finalTitle = rawTitle.isNotEmpty
          ? rawTitle
          : (rawDesc.isNotEmpty ? rawDesc : 'General PC Service Request');

      await SupportService.instance.createServiceRequest(
        title: finalTitle,
        description: rawDesc.isNotEmpty ? rawDesc : null,
        preferredDate: _includeAppointment ? _formattedSelectedDate : null,
        preferredTime: _includeAppointment ? _selectedTime : null,
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

              // Preferred Appointment Date & Time (Optional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preferred Appointment (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryDark),
                  ),
                  Switch(
                    value: _includeAppointment,
                    activeColor: AppColors.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        _includeAppointment = val;
                        if (val && _availability == null) {
                          _checkDateAvailability(_formattedSelectedDate);
                        }
                      });
                    },
                  ),
                ],
              ),

              if (_includeAppointment) ...[
                const SizedBox(height: 6),
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
                          filled: true,
                          fillColor: AppColors.surface,
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
                      Text('Checking appointment capacity...', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                    ],
                  )
                else if (_availability != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAvailable ? AppColors.stockGreen.withValues(alpha: 0.08) : AppColors.alertRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                          size: 16,
                          color: isAvailable ? AppColors.stockGreen : AppColors.alertRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isAvailable
                                ? '$remainingSlots of 10 slots available on this date'
                                : 'Fully booked ($bookedCount/10 slots used). Max 10 requests allowed per day.',
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
              ],

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
