/// Explicit public projection. Never pass raw API maps into a share image.
class ReceivedVote {
  const ReceivedVote({
    required this.id,
    required this.question,
    required this.voterGender,
    required this.graduationYear,
    required this.participants,
  });

  factory ReceivedVote.fromJson(Map<String, dynamic> json) => ReceivedVote(
    id: json['id'] is String ? json['id'] as String : '',
    question: json['question'] is String ? json['question'] as String : '',
    voterGender: switch (json['voterGender']) {
      'female' => 'female',
      'male' => 'male',
      'nonbinary' => 'nonbinary',
      _ => null,
    },
    graduationYear: json['graduationYear'] is int
        ? json['graduationYear'] as int
        : null,
    participants: [
      for (final item
          in json['participants'] is List
              ? json['participants'] as List
              : const [])
        if (item is Map &&
            item['name'] is String &&
            (item['name'] as String).trim().isNotEmpty)
          VoteParticipant(
            name: (item['name'] as String).trim(),
            graduationYear: item['graduationYear'] is int
                ? item['graduationYear'] as int
                : null,
          ),
    ],
  );

  final String id;
  final String question;
  final String? voterGender;
  final int? graduationYear;
  final List<VoteParticipant> participants;

  String get voterLabel => publicVoterLabel(voterGender, graduationYear);
}

class VoteParticipant {
  const VoteParticipant({required this.name, this.graduationYear});
  final String name;
  final int? graduationYear;
}

String publicVoterLabel(Object? gender, Object? year) {
  final who = switch (gender) {
    'female' => 'a girl',
    'male' => 'a boy',
    'nonbinary' => 'a non-binary student',
    _ => 'a student',
  };
  return 'From $who${year is int ? ' · Class of $year' : ''}';
}
