/// SessionInfo: Information about a session
/// 
/// Stores session name and last modified timestamp
class SessionInfo {
  final String name;
  final DateTime lastModified;

  SessionInfo({
    required this.name,
    required this.lastModified,
  });

  /// Create SessionInfo from JSON
  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      name: json['name'] as String,
      lastModified: DateTime.parse(json['lastModifiedAt'] as String),
    );
  }

  /// Convert SessionInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lastModifiedAt': lastModified.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionInfo && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'SessionInfo(name: $name, lastModified: $lastModified)';
}



