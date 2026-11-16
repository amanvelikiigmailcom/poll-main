import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vote screen shows intro round 1 with no category names',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: 'Аман',
      friends: ['Али', 'Маша', 'Даня'],
    );

    await tester.pumpWidget(const MaterialApp(home: VoteScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(find.textContaining('make the whole group laugh'), findsOneWidget);
    expect(find.textContaining('Sympathy'), findsNothing);
    expect(find.textContaining('General'), findsNothing);
    expect(find.textContaining('Humor'), findsNothing);
    expect(find.textContaining('Симпатия'), findsNothing);
    expect(find.textContaining('Обычное'), findsNothing);
  });
}
