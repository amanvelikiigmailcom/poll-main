import 'package:equatable/equatable.dart';

/// Status of a friend relationship.
enum FriendStatus { pending, accepted, rejected }

/// Relationship record between two users.
class Friend extends Equatable {
  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
  });

  /// Unique relationship id.
  final String id;

  /// The user who sent the friend request.
  final String userId;

  /// The user who received the friend request.
  final String friendId;
  final FriendStatus status;
  final DateTime createdAt;

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String,
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      status: _statusFromString(json['status'] as String? ?? 'pending'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'friendId': friendId,
        'status': _statusToString(status),
        'createdAt': createdAt.toIso8601String(),
      };

  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    FriendStatus? status,
    DateTime? createdAt,
  }) {
    return Friend(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static FriendStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return FriendStatus.accepted;
      case 'rejected':
        return FriendStatus.rejected;
      default:
        return FriendStatus.pending;
    }
  }

  static String _statusToString(FriendStatus status) {
    switch (status) {
      case FriendStatus.accepted:
        return 'accepted';
      case FriendStatus.rejected:
        return 'rejected';
      case FriendStatus.pending:
        return 'pending';
    }
  }

  @override
  List<Object?> get props => [id, userId, friendId, status, createdAt];
}

/// Lightweight user representation used in friend lists and suggestions.
class FriendUser extends Equatable {
  const FriendUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.grade,
    required this.schoolName,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  /// School grade (8–12).
  final int grade;
  final String schoolName;
  final bool isOnline;

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      grade: json['grade'] as int? ?? 8,
      schoolName: json['schoolName'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
        'grade': grade,
        'schoolName': schoolName,
        'isOnline': isOnline,
      };

  FriendUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    int? grade,
    String? schoolName,
    bool? isOnline,
  }) {
    return FriendUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      grade: grade ?? this.grade,
      schoolName: schoolName ?? this.schoolName,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [id, name, avatarUrl, grade, schoolName, isOnline];
}
