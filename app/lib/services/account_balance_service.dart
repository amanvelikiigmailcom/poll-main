import 'api_service.dart';

/// Signed-in progress is never inferred from guest progress or a client delta.
class AccountBalanceService {
  AccountBalanceService({required this.readToken, required this.fetchBalance,
    required this.readCached, required this.writeCached, required this.guestBalance});
  final Future<String?> Function() readToken;
  final Future<dynamic> Function(String token) fetchBalance;
  final Future<int?> Function(String token) readCached;
  final Future<void> Function(String token, int value) writeCached;
  final Future<int> Function() guestBalance;

  Future<int?> load() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      final value = await guestBalance();
      return await readToken() == token ? value : null;
    }
    try {
      final value = await fetchBalance(token);
      if (await readToken() != token) return null;
      if (value is! int || value < 0 || value > 9007199254740991) {
        throw const FormatException('Invalid server balance');
      }
      await writeCached(token, value);
      return await readToken() == token ? value : null;
    } on FormatException {
      return null;
    } catch (error) {
      if (await readToken() != token || error is ApiException && error.statusCode == 401) return null;
      final value = await readCached(token);
      return await readToken() == token && value != null && value >= 0 && value <= 9007199254740991 ? value : null;
    }
  }
}
