import 'package:flutter/foundation.dart';
import '../features/auth/data/models/user_model.dart';

/// In-memory session manager for storing current user credentials and JWT token.
class AuthSession extends ChangeNotifier {
  static final AuthSession instance = AuthSession._internal();

  AuthSession._internal();

  UserModel? currentUser;
  String? token;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  void setSession({required UserModel user, required String token}) {
    currentUser = user;
    this.token = token;
    notifyListeners();
  }

  void updateCurrentUser(UserModel updatedUser, {String? newToken}) {
    currentUser = updatedUser;
    if (newToken != null && newToken.isNotEmpty) {
      token = newToken;
    }
    notifyListeners();
  }

  void clearSession() {
    currentUser = null;
    token = null;
    notifyListeners();
  }
}
