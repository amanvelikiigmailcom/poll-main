abstract final class ProfileLink {
  static String? handle(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host != 'api.flyprox.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'p') {
      return null;
    }
    final value = uri.pathSegments.last
        .replaceFirst(RegExp(r'^@'), '')
        .toLowerCase();
    return RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(value) ? value : null;
  }
}
