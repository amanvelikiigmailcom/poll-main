/// Explicit public projection: no phone, balance or voter identity.
class PersonProfile {
  PersonProfile.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      username = json['username'] as String,
      relationship = json['relationship'] as String? ?? 'none',
      firstName = json['relationship'] == 'friends'
          ? json['firstName'] as String? ?? ''
          : '',
      lastName = json['relationship'] == 'friends'
          ? json['lastName'] as String? ?? ''
          : '',
      campus = (json['campus'] as Map?)?['name'] as String?,
      graduationYear = json['graduationYear'] as int?;

  final String id, username, relationship, firstName, lastName;
  final String? campus;
  final int? graduationYear;
  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? '@$username' : name;
  }
}

class ProfileNomination {
  ProfileNomination.fromJson(Map<String, dynamic> json)
    : questionId = json['questionId'] as String,
      question = json['question'] as String,
      count = json['count'] as int;
  final String questionId, question;
  final int count;
}

class PersonNominations {
  PersonNominations.fromJson(Map<String, dynamic> json)
    : friendsCount = json['friendsCount'] as int,
      votesReceived = json['votesReceived'] as int,
      items = (json['items'] as List)
          .map(
            (item) => ProfileNomination.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      nextCursor = json['nextCursor'] as String?;
  final int friendsCount, votesReceived;
  final List<ProfileNomination> items;
  final String? nextCursor;
}
