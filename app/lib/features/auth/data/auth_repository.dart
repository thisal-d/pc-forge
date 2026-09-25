import '../../../core/auth_session.dart';
import '../../../services/api_service.dart';
import 'models/user_model.dart';

class AuthRepository {
  final ApiService _apiService;

  AuthRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Authenticate with backend API and store session upon success
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.login(
      email: email,
      password: password,
    );

    final token = response['token'] as String? ?? '';
    final user = UserModel.fromJson(response);

    if (token.isNotEmpty) {
      AuthSession.instance.setSession(user: user, token: token);
    }

    return user;
  }

  /// Register new user account with backend API and store session
  Future<UserModel> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _apiService.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: 'Customer',
    );

    final token = response['token'] as String? ?? '';
    final user = UserModel.fromJson(response);

    if (token.isNotEmpty) {
      AuthSession.instance.setSession(user: user, token: token);
    }

    return user;
  }

  /// Update current user profile details (Member 01)
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final currentSession = AuthSession.instance;
    final token = currentSession.token;

    try {
      final response = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword,
        token: token,
      );

      final updatedUser = UserModel.fromJson(response);
      final newToken = response['token'] as String? ?? token;

      currentSession.updateCurrentUser(updatedUser, newToken: newToken);
      return updatedUser;
    } catch (e) {
      // Rethrow so callers can show the real error to the user
      rethrow;
    }
  }

  /// Clear active user session
  void logout() {
    AuthSession.instance.clearSession();
  }
}
