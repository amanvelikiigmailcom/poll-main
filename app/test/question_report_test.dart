import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flyprox_app/screens/voting/vote_screen.dart';
import 'package:flyprox_app/services/local_game_service.dart';
import 'package:flyprox_app/services/question_report_service.dart';
import 'package:flyprox_app/utils/constants.dart';
import 'package:flyprox_app/widgets/common/question_report_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'email draft correctly encodes question text and includes its identifier',
      () {
    const report = QuestionReport(
      questionId: 'question_42',
      questionText: 'Who says "yes & no"? 50% of the time?',
    );
    final uri = report.emailUri;
    expect(uri.scheme, 'mailto');
    expect(uri.path, AppConstants.supportEmail);
    expect(uri.queryParameters['subject'], contains('question_42'));
    expect(uri.queryParameters['body'], contains(report.questionText));
    expect(uri.queryParameters['body'], contains('Question ID: question_42'));
    expect(uri.toString(), contains('%20'));
  });

  test('launcher failures are returned as unavailable instead of reported sent',
      () async {
    final service = QuestionReportService(openEmail: (_) async {
      throw StateError('No email handler');
    });
    expect(
        await service.openDraft(const QuestionReport(
            questionId: 'question_42', questionText: 'Example prompt?')),
        isFalse);
  });

  testWidgets(
      'current question can be reviewed and cancelled; fallback copies no participant data',
      (tester) async {
    const privateNames = [
      'PlayerSecret',
      'AliceSecret',
      'BobSecret',
      'CamSecret'
    ];
    await LocalGameService.instance.savePlayerAndFriends(
      playerName: privateNames.first,
      friends: privateNames.sublist(1),
    );
    final opened = <Uri>[];
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: VoteScreen(
        reportService: QuestionReportService(openEmail: (uri) async {
          opened.add(uri);
          return false;
        }),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Report question'));
    await tester.tap(find.text('Report question'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Question 1 of 12'), findsOneWidget);
    expect(await LocalGameService.instance.getStars(), 0);
    expect(await LocalGameService.instance.secondsUntilNextRound(), 0);

    await tester.tap(find.text('Report question'));
    await tester.pumpAndSettle();
    final report = tester
        .widget<QuestionReportDialog>(find.byType(QuestionReportDialog))
        .report;
    await tester.tap(find.text('Open email'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    final body = opened.single.queryParameters['body']!;
    expect(body, contains(report.questionId));
    expect(body, contains(report.questionText));
    for (final name in privateNames) {
      expect(body, isNot(contains(name)));
    }
    expect(
        find.text('Couldn’t open an email app. Copy the report and email it to '
            '${AppConstants.supportEmail}.'),
        findsOneWidget);
    await tester.tap(find.text('Copy report'));
    await tester.pumpAndSettle();
    expect(copiedText, contains(report.questionId));
    expect(copiedText, contains(report.questionText));
    for (final name in privateNames) {
      expect(copiedText, isNot(contains(name)));
    }
    expect(opened, hasLength(1));
  });

  testWidgets('a pending email open cannot launch a second draft',
      (tester) async {
    final opening = Completer<bool>();
    var openCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => QuestionReportDialog(
                report: const QuestionReport(
                    questionId: 'question_42', questionText: 'Example prompt?'),
                service: QuestionReportService(openEmail: (_) {
                  openCount++;
                  return opening.future;
                }),
              ),
            ),
            child: const Text('Review report'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Review report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open email'));
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(openCount, 1);
    opening.complete(true);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Email draft opened. Send it from your email app when ready.'),
        findsOneWidget);
    expect(find.text('Report sent'), findsNothing);
  });
}
