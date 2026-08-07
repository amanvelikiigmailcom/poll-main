import 'package:dio/dio.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class UserService {
  final ApiService _api;
  final StorageService _storage;

  UserService(this._api, this._storage);

  /// Creates or updates the user's basic profile (name, gender, age, etc.).
  Future<User> saveProfile(Map<String, dynamic> data) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/users/profile',
      data: data,
    );
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Associates the user with a school by [schoolId].
  Future<User> saveSchool(String schoolId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/users/profile/school',
      data: {'schoolId': schoolId},
    );
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Sets the user's grade / class (8–12, optional letter).
  Future<User> saveClass(int grade, {String? gradeClass}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/users/profile/class',
      data: {
        'grade': grade,
        if (gradeClass != null) 'gradeClass': gradeClass,
      },
    );
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Uploads the user's profile photo. [filePath] is the local file path.
  Future<User> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });

    final response = await _api.post<Map<String, dynamic>>(
      '/api/users/profile/photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Fetches the current user's profile from the server and updates local cache.
  Future<User> getProfile() async {
    final response = await _api.get<Map<String, dynamic>>('/api/users/profile');
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Updates specific profile fields. [data] may include any subset of user fields.
  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/api/users/profile',
      data: data,
    );
    final user = User.fromJson(response.data!);
    await _storage.saveUser(user);
    return user;
  }

  /// Returns the locally cached user without a network call.
  User? getCachedUser() => _storage.getUser();
}
