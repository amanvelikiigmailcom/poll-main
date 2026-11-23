import 'package:flyprox_app/services/storage_service.dart';

class SessionStorage extends StorageService {
  String? token = 'first-account';
  @override
  Future<String?> getToken() async => token;
  @override
  Future<void> clearToken() async {
    token = null;
    notifyListeners();
  }
}
