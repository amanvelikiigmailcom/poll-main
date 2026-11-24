import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/services/profile_link.dart';
import 'package:flyprox_app/widgets/common/social_identity.dart';

void main() {
  test('profile links accept only the exact HTTPS host and valid handle', () {
    expect(
      ProfileLink.handle(Uri.parse('https://api.flyprox.com/p/@Alex_123')),
      'alex_123',
    );
    for (final url in [
      'http://api.flyprox.com/p/@alex_123',
      'https://evil.test/p/@alex_123',
      'https://api.flyprox.com:444/p/@alex_123',
      'https://user@api.flyprox.com/p/@alex_123',
      'https://api.flyprox.com/p/@bad%20name',
      'https://api.flyprox.com/p/@ab',
      'https://api.flyprox.com/p/@alex/extra',
      'https://api.flyprox.com/i/ABCDEF',
    ]) {
      expect(ProfileLink.handle(Uri.parse(url)), isNull, reason: url);
    }
  });
  test(
    'friend name uses real first and last name, or the handle on older servers',
    () {
      expect(
        socialDisplayName({
          'firstName': ' Alex ',
          'lastName': 'Smith',
          'username': 'alex',
        }),
        'Alex Smith',
      );
      expect(socialDisplayName({'username': 'alex'}), '@alex');
      expect(
        socialDisplayName({
          'firstName': '',
          'lastName': null,
          'username': 'alex',
        }),
        '@alex',
      );
    },
  );
}
