
/// Session: Represents a Blueprint Canvas session/project
/// 
/// Stores metadata about a canvas session including:
/// - ID, name, timestamps
/// - File paths for JSON data and optional thumbnails
/// - Ready for future extensions (previews, metadata)
class Session {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime lastModifiedAt;
  final String jsonPath;
  final String? thumbnailPath;

  Session({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.lastModifiedAt,
    required this.jsonPath,
    this.thumbnailPath,
  });

  /// Create a copy with modified properties
  Session copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    String? jsonPath,
    String? thumbnailPath,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      jsonPath: jsonPath ?? this.jsonPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  /// Convert Session to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'jsonPath': jsonPath,
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Create Session from JSON
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: DateTime.parse(json['lastModifiedAt'] as String),
      jsonPath: json['jsonPath'] as String,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  /// Generate a default session name based on timestamp
  static String generateDefaultName() {
    final now = DateTime.now();
    return 'Blueprint Session ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Generate a unique session ID
  static String generateId() {
    return 'session_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Session(id: $id, name: $name, createdAt: $createdAt)';
}

/// CanvasSessionData: Data structure for canvas state (shapes, viewport, settings)
/// 
/// This represents the actual canvas content that gets saved/loaded
class CanvasSessionData {
  final List<Map<String, dynamic>> shapes;
  final Map<String, dynamic>? viewport;
  final Map<String, dynamic>? settings;

  CanvasSessionData({
    required this.shapes,
    this.viewport,
    this.settings,
  });

  /// Convert CanvasSessionData to JSON
  Map<String, dynamic> toJson() {
    return {
      'shapes': shapes,
      'viewport': viewport,
      'settings': settings,
    };
  }

  /// Create CanvasSessionData from JSON
  factory CanvasSessionData.fromJson(Map<String, dynamic> json) {
    return CanvasSessionData(
      shapes: List<Map<String, dynamic>>.from(json['shapes'] as List? ?? []),
      viewport: json['viewport'] as Map<String, dynamic>?,
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }

  /// Create empty CanvasSessionData
  factory CanvasSessionData.empty() {
    return CanvasSessionData(shapes: []);
  }
}

