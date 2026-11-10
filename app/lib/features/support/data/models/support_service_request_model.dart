class SupportServiceRequestModel {
  final int serviceRequestId;
  final int? orderId;
  final int? productId;
  final String? productName;
  final String issueType;
  final String subject;
  final String description;
  final String? attachmentUrl;
  final String status;
  final String priority;
  final DateTime createdAt;

  // Backward compatibility alias for ticketId
  int get ticketId => serviceRequestId;

  const SupportServiceRequestModel({
    required this.serviceRequestId,
    this.orderId,
    this.productId,
    this.productName,
    required this.issueType,
    required this.subject,
    required this.description,
    this.attachmentUrl,
    this.status = 'Open',
    this.priority = 'Normal',
    required this.createdAt,
  });

  factory SupportServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final sId = json['serviceRequestId'] as int? ??
        json['service_request_id'] as int? ??
        json['ticketId'] as int? ??
        json['ticket_id'] as int? ??
        json['id'] as int? ??
        0;

    return SupportServiceRequestModel(
      serviceRequestId: sId,
      orderId: json['orderId'] as int? ?? json['order_id'] as int?,
      productId: json['productId'] as int? ?? json['product_id'] as int?,
      productName: json['productName'] as String? ?? json['product_name'] as String?,
      issueType: json['issueType'] as String? ?? json['issue_type'] as String? ?? json['problemCategory'] as String? ?? 'Hardware Failure',
      subject: json['subject'] as String? ?? json['title'] as String? ?? '',
      description: json['description'] as String? ?? json['problemDescription'] as String? ?? '',
      attachmentUrl: json['attachmentUrl'] as String? ?? json['attachment_url'] as String?,
      status: json['status'] as String? ?? 'Open',
      priority: json['priority'] as String? ?? 'Normal',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceRequestId': serviceRequestId,
      'ticketId': serviceRequestId,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'issueType': issueType,
      'subject': subject,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Backward-compatibility alias
typedef SupportTicketModel = SupportServiceRequestModel;
