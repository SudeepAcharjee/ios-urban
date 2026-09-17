import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

abstract class IAuthRepository {
  Future<void> sendOTP(String email);
  Future<bool> verifyOTP(String email, String otp);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
}

class AuthRepository implements IAuthRepository {
  static const String baseUrl = 'https://urban-services-backend.vercel.app/api'; 


  @override
  Future<void> sendOTP(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
  }

  @override
  Future<bool> verifyOTP(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Verification failed');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to send reset email');
    }
  }

  @override
  Future<void> logout() async {
    // Implement local logout (clear shared preferences, etc.)
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    // Implement logic to get current user from local storage or firebase
    return null;
  }
}

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository();
});


