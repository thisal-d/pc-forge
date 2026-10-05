class SupportTicketModel {
  final int ticketId;
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

  const SupportTicketModel({
    required this.ticketId,
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

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      ticketId: json['ticketId'] as int? ?? 0,
      orderId: json['orderId'] as int?,
      productId: json['productId'] as int?,
      productName: json['productName'] as String?,
      issueType: json['issueType'] as String? ?? 'Hardware Failure',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      attachmentUrl: json['attachmentUrl'] as String?,
      status: json['status'] as String? ?? 'Open',
      priority: json['priority'] as String? ?? 'Normal',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
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
