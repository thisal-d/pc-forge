import 'package:flutter/foundation.dart';
import '../../orders/data/order_service.dart';

/// Stores and manages legitimate user shipping contact details.
/// Strictly partitioned by userId to guarantee privacy and prevent data cross-contamination.
class UserShippingContact {
  final String recipientName;
  final String phoneNumber;
  final String address;
  final String city;

  const UserShippingContact({
    required this.recipientName,
    required this.phoneNumber,
    required this.address,
    required this.city,
  });

  Map<String, dynamic> toJson() => {
    'recipientName': recipientName,
    'phoneNumber': phoneNumber,
    'address': address,
    'city': city,
  };

  factory UserShippingContact.fromJson(Map<String, dynamic> json) => UserShippingContact(
    recipientName: json['recipientName'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String? ?? '',
    address: json['address'] as String? ?? '',
    city: json['city'] as String? ?? '',
  );
}

class UserContactService extends ChangeNotifier {
  static final UserContactService instance = UserContactService._internal();

  UserContactService._internal();

  final Map<int, UserShippingContact> _savedContacts = {};

  /// Retrieves legitimate saved contact details for an authenticated user.
  /// If none exist in memory, attempts to resolve from previous orders placed by THIS user.
  /// Never returns fake, placeholder, or other users' contact data.
  UserShippingContact? getSavedContact(int userId) {
    if (userId <= 0) return null;

    if (_savedContacts.containsKey(userId)) {
      return _savedContacts[userId];
    }

    // Try to resolve from previous orders placed by THIS user in OrderService
    try {
      final userOrders = OrderService.instance.orders.where((o) => o.userId == userId).toList();
      if (userOrders.isNotEmpty) {
        final latest = userOrders.first;
        final raw = latest.shippingAddress;
        final parts = raw.split(',').map((p) => p.trim()).toList();
        if (parts.length >= 4) {
          final contact = UserShippingContact(
            recipientName: parts[0],
            phoneNumber: parts[1],
            address: parts[2],
            city: parts.sublist(3).join(', '),
          );
          _savedContacts[userId] = contact;
          return contact;
        }
      }
    } catch (_) {
      // Graceful fallback: return null
    }

    return null;
  }

  /// Saves or updates contact details specifically for the designated user ID.
  void saveContact(int userId, UserShippingContact contact) {
    if (userId <= 0) return;
    _savedContacts[userId] = contact;
    notifyListeners();
  }

  /// Removes contact details (for testing or account reset)
  @visibleForTesting
  void clearForUser(int userId) {
    _savedContacts.remove(userId);
    notifyListeners();
  }

  @visibleForTesting
  void clearAll() {
    _savedContacts.clear();
    notifyListeners();
  }
}
