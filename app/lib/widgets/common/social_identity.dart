/// Render only names explicitly projected by the campus-authorized server.
String socialDisplayName(Map<String, dynamic> user) {
  final name = ['firstName', 'lastName']
      .map((key) => user[key])
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');
  return name.isEmpty ? '@${user['username'] ?? ''}' : name;
}
