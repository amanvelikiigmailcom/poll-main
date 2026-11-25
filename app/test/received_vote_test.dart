import 'package:flutter_test/flutter_test.dart';
import 'package:flyprox_app/models/received_vote.dart';

void main() {
  test(
    'public cohort labels handle all genders and never infer missing values',
    () {
      expect(publicVoterLabel('female', 2029), 'From a girl · Class of 2029');
      expect(publicVoterLabel('male', 2030), 'From a boy · Class of 2030');
      expect(
        publicVoterLabel('nonbinary', 2028),
        'From a non-binary student · Class of 2028',
      );
      expect(publicVoterLabel(null, null), 'From a student');
      expect(publicVoterLabel('invented', '2030'), 'From a student');
    },
  );
  test(
    'share model only parses the public projection, not revealed identity',
    () {
      final vote = ReceivedVote.fromJson({
        'id': 'v',
        'question': 'Question?',
        'voterGender': 'female',
        'graduationYear': 2029,
        'name': 'SECRET VOTER',
        'voterId': 'SECRET',
        'participants': [
          {'name': ' Alex ', 'graduationYear': 2030},
          {'name': ''},
          null,
          'invalid',
        ],
      });
      expect(vote.voterLabel, 'From a girl · Class of 2029');
      expect(vote.participants.single.name, 'Alex');
      expect(vote.participants.single.graduationYear, 2030);
      final missing = ReceivedVote.fromJson({
        'voterGender': 'invented',
        'graduationYear': '2030',
      });
      expect(missing.voterGender, isNull);
      expect(missing.graduationYear, isNull);
    },
  );
}
