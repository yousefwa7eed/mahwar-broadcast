import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<String?> getUserRole() async {
    if (currentUser == null) return null;

    final response = await _client
        .from('profiles')
        .select('role')
        .eq('id', currentUser!.id)
        .maybeSingle();

    return response?['role'] as String?;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String role,
    required String fullName,
    required String phoneNumber,
    String? nationalId,
    String? workshopName,
    String? address,
    double? latitude,
    double? longitude,
    String? supportScope,
    bool? hasVehicle,
    String? vehicleSpecs,
    String? vehicleMake,
    String? vehicleModel,
    int? vehicleYear,
    String? vehiclePlate,
    String? vehicleColor,
    List<String>? specializations,
    String? carMake,
    String? carModel,
    int? carYear,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'national_id': nationalId,
        'specializations': specializations,
        'workshop_name': workshopName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'support_scope': supportScope,
        'has_vehicle': hasVehicle,
        'vehicle_specs': vehicleSpecs,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_plate': vehiclePlate,
        'vehicle_color': vehicleColor,
        'car_make': carMake,
        'car_model': carModel,
        'car_year': carYear,
      },
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<String?> getUserName() async {
    if (currentUser == null) return null;

    final response = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', currentUser!.id)
        .maybeSingle();

    final name = response?['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;

    return currentUser!.userMetadata?['full_name'] as String?;
  }

  Future<void> deleteAccount() async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('No active session');

    final response = await _client.functions.invoke(
      'delete-account',
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    if (response.status != 200) {
      final body = response.data;
      throw Exception(body?['error'] ?? 'Failed to delete account');
    }

    await _client.auth.signOut();
  }
}
