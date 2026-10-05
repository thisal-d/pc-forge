class ServiceRequestModel {
  final int serviceRequestId;
  final String serviceRequestNumber;
  final int userId;
  final String? customerName;
  final int? orderId;
  final int? productId;
  final String? productName;
  final String title;
  final String? description;
  final String problemDescription;
  final String problemCategory;
  final String? troubleshootingSummary;
  final int attemptCount;
  final String warrantyStatus;
  final DateTime? warrantyExpiryDate;
  final String? preferredDate;
  final String? preferredTime;
  final String status;
  final String priority;
  final String? assignedStaffName;
  final String? technicianNotes;
  final String? resolution;
  final String? attachmentUrl;
  final DateTime createdAt;

  const ServiceRequestModel({
    required this.serviceRequestId,
    required this.serviceRequestNumber,
    required this.userId,
    this.customerName,
    this.orderId,
    this.productId,
    this.productName,
    this.title = '',
    this.description,
    required this.problemDescription,
    this.problemCategory = 'General',
    this.troubleshootingSummary,
    this.attemptCount = 0,
    this.warrantyStatus = 'Active',
    this.warrantyExpiryDate,
    this.preferredDate,
    this.preferredTime,
    this.status = 'PENDING',
    this.priority = 'Normal',
    this.assignedStaffName,
    this.technicianNotes,
    this.resolution,
    this.attachmentUrl,
    required this.createdAt,
  });

  ServiceRequestModel copyWith({
    int? serviceRequestId,
    String? serviceRequestNumber,
    int? userId,
    String? customerName,
    int? orderId,
    int? productId,
    String? productName,
    String? title,
    String? description,
    String? problemDescription,
    String? problemCategory,
    String? troubleshootingSummary,
    int? attemptCount,
    String? warrantyStatus,
    DateTime? warrantyExpiryDate,
    String? preferredDate,
    String? preferredTime,
    String? status,
    String? priority,
    String? assignedStaffName,
    String? technicianNotes,
    String? resolution,
    String? attachmentUrl,
    DateTime? createdAt,
  }) {
    return ServiceRequestModel(
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      serviceRequestNumber: serviceRequestNumber ?? this.serviceRequestNumber,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      title: title ?? this.title,
      description: description ?? this.description,
      problemDescription: problemDescription ?? this.problemDescription,
      problemCategory: problemCategory ?? this.problemCategory,
      troubleshootingSummary: troubleshootingSummary ?? this.troubleshootingSummary,
      attemptCount: attemptCount ?? this.attemptCount,
      warrantyStatus: warrantyStatus ?? this.warrantyStatus,
      warrantyExpiryDate: warrantyExpiryDate ?? this.warrantyExpiryDate,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTime: preferredTime ?? this.preferredTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      resolution: resolution ?? this.resolution,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime? expDate;
    if (json['warrantyExpiryDate'] != null) {
      expDate = DateTime.tryParse(json['warrantyExpiryDate'].toString());
    } else if (json['warranty_expiry_date'] != null) {
      expDate = DateTime.tryParse(json['warranty_expiry_date'].toString());
    }

    DateTime created = DateTime.now();
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    final sId = (json['serviceRequestId'] as num?)?.toInt() ??
        (json['service_request_id'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        (json['ticketId'] as num?)?.toInt() ??
        0;

    final sNum = json['serviceRequestNumber']?.toString() ??
        json['service_request_number']?.toString() ??
        json['rmaNumber']?.toString() ??
        'SR-${sId.toString().padLeft(6, '0')}';

    final probDesc = json['problemDescription']?.toString() ??
        json['problem_description']?.toString() ??
        json['description']?.toString() ??
        '';

    final parsedTitle = json['title']?.toString() ??
        json['subject']?.toString() ??
        (probDesc.isNotEmpty ? probDesc : 'Service Request');

    final parsedDesc = json['description']?.toString() ??
        json['problemDescription']?.toString() ??
        json['problem_description']?.toString();

    return ServiceRequestModel(
      serviceRequestId: sId,
      serviceRequestNumber: sNum,
      userId: (json['userId'] as num?)?.toInt() ?? (json['user_id'] as num?)?.toInt() ?? 1,
      customerName: json['customerName']?.toString() ?? json['customer_name']?.toString(),
      orderId: (json['orderId'] as num?)?.toInt() ?? (json['order_id'] as num?)?.toInt(),
      productId: (json['productId'] as num?)?.toInt() ?? (json['product_id'] as num?)?.toInt(),
      productName: json['productName']?.toString() ?? json['product_name']?.toString(),
      title: parsedTitle,
      description: parsedDesc,
      problemDescription: probDesc.isNotEmpty ? probDesc : parsedTitle,
      problemCategory: json['problemCategory']?.toString() ??
          json['problem_category']?.toString() ??
          json['issueType']?.toString() ??
          'General',
      troubleshootingSummary: json['troubleshootingSummary']?.toString() ?? json['troubleshooting_summary']?.toString(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ??
          (json['attempt_count'] as num?)?.toInt() ??
          (json['troubleshootingAttemptCount'] as num?)?.toInt() ??
          (json['troubleshooting_attempt_count'] as num?)?.toInt() ??
          0,
      warrantyStatus: json['warrantyStatus']?.toString() ?? json['warranty_status']?.toString() ?? 'Active',
      warrantyExpiryDate: expDate,
      preferredDate: json['preferredDate']?.toString() ?? json['preferred_date']?.toString(),
      preferredTime: json['preferredTime']?.toString() ?? json['preferred_time']?.toString(),
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      priority: json['priority']?.toString() ?? 'Normal',
      assignedStaffName: json['assignedStaffName']?.toString() ?? json['assigned_staff_name']?.toString(),
      technicianNotes: json['technicianNotes']?.toString() ?? json['technician_notes']?.toString(),
      resolution: json['resolution']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString() ?? json['attachment_url']?.toString(),
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceRequestId': serviceRequestId,
      'serviceRequestNumber': serviceRequestNumber,
      'userId': userId,
      'customerName': customerName,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'title': title,
      'description': description,
      'problemDescription': problemDescription,
      'problemCategory': problemCategory,
      'troubleshootingSummary': troubleshootingSummary,
      'attemptCount': attemptCount,
      'warrantyStatus': warrantyStatus,
      'warrantyExpiryDate': warrantyExpiryDate?.toIso8601String(),
      'preferredDate': preferredDate,
      'preferredTime': preferredTime,
      'status': status,
      'priority': priority,
      'assignedStaffName': assignedStaffName,
      'technicianNotes': technicianNotes,
      'resolution': resolution,
      'attachmentUrl': attachmentUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
