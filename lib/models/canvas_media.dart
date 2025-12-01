import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'canvas_shape.dart'; // For shared z-index counter

/// Data class for imported image media
class MediaImportData {
  final Uint8List imageData;
  final Size size;
  final String filePath;
  final bool isSvg;

  MediaImportData({
    required this.imageData,
    required this.size,
    required this.filePath,
    required this.isSvg,
  });
}

/// MediaType: Type of media item
enum MediaType {
  emoji,  // Emoji sticker (text-based)
  image,  // PNG/JPG image (file-based)
  svg,    // SVG vector graphic (file-based)
}

/// CanvasMedia: Represents a media item (emoji or image) on the canvas
class CanvasMedia {
  final String id;
  Offset position;
  Size size;
  MediaType type;
  String? emoji; // For emoji type
  Uint8List? imageData; // For image/SVG type
  String? filePath; // For file-based media
  String notes; // Optional notes/annotations
  bool isSelected;
  bool showBorder; // Whether to show border/highlight
  int zIndex; // Z-order for layering (higher = on top)
  Size? intrinsicSize; // Intrinsic size of the image (for accurate border rendering)

  CanvasMedia({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    this.emoji,
    this.imageData,
    this.filePath,
    this.notes = '',
    this.isSelected = false,
    this.showBorder = true, // Default to showing border
    int? zIndex,
    this.intrinsicSize, // Intrinsic image size (for accurate border rendering)
  }) : zIndex = zIndex ?? _generateZIndex();

  /// Create a copy with modified properties
  CanvasMedia copyWith({
    Offset? position,
    Size? size,
    String? notes,
    bool? isSelected,
    bool? showBorder,
    int? zIndex,
    Size? intrinsicSize,
  }) {
    return CanvasMedia(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      type: type,
      emoji: emoji,
      imageData: imageData,
      filePath: filePath,
      notes: notes ?? this.notes,
      isSelected: isSelected ?? this.isSelected,
      showBorder: showBorder ?? this.showBorder,
      zIndex: zIndex ?? this.zIndex,
      intrinsicSize: intrinsicSize ?? this.intrinsicSize,
    );
  }

  /// Check if a point is inside this media's bounds
  bool containsPoint(Offset point) {
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    return rect.contains(point);
  }

  /// Get the center point of this media
  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  /// Get the bounding rectangle of this media
  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  /// Create an emoji sticker
  static CanvasMedia createEmoji(Offset position, String emoji, {double size = 64.0}) {
    return CanvasMedia(
      id: _generateId(),
      position: position,
      size: Size(size, size),
      type: MediaType.emoji,
      emoji: emoji,
      showBorder: true, // Faint border on import
    );
  }

  /// Create an image media item
  static CanvasMedia createImage(
    Offset position,
    Uint8List imageData,
    Size size,
    String? filePath, {
    Size? intrinsicSize,
  }) {
    return CanvasMedia(
      id: _generateId(),
      position: position,
      size: size,
      type: MediaType.image,
      imageData: imageData,
      filePath: filePath,
      showBorder: true, // Faint border on import
      intrinsicSize: intrinsicSize ?? size, // Use provided intrinsic size or fallback to display size
    );
  }

  /// Create an SVG media item
  static CanvasMedia createSvg(
    Offset position,
    Uint8List svgData,
    Size size,
    String? filePath, {
    Size? intrinsicSize,
  }) {
    return CanvasMedia(
      id: _generateId(),
      position: position,
      size: size,
      type: MediaType.svg,
      imageData: svgData,
      filePath: filePath,
      showBorder: true, // Faint border on import
      intrinsicSize: intrinsicSize ?? size, // Use provided intrinsic size or fallback to display size
    );
  }

  /// Generate unique ID
  static String _generateId() {
    return 'media_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  }

  /// Generate unique z-index (shared across shapes and media)
  /// Uses the same global counter as CanvasShape for unified layering
  static int _generateZIndex() {
    // Access the shared global z-index counter from CanvasShape
    // This ensures shapes and media are interleaved based on creation order
    return CanvasShape.globalZIndexCounter++;
  }

  static int _counter = 0;
}

/// Emoji categories for organization
class EmojiCategory {
  final String name;
  final String icon;
  final List<String> emojis;

  const EmojiCategory({
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

/// Predefined emoji categories with curated emoji stickers
class EmojiStickers {
  static const List<EmojiCategory> categories = [
    EmojiCategory(
      name: 'Faces',
      icon: '😀',
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰',
        '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜',
        '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏',
      ],
    ),
    EmojiCategory(
      name: 'Gestures',
      icon: '👍',
      emojis: [
        '👍', '👎', '👊', '✊', '🤛', '🤜', '🤞', '✌️',
        '🤟', '🤘', '👌', '🤌', '🤏', '👈', '👉', '👆',
        '👇', '☝️', '👋', '🤚', '🖐', '✋', '🖖', '👏',
        '🙌', '🤲', '🤝', '🙏', '✍️', '💪', '🦾', '🦿',
      ],
    ),
    EmojiCategory(
      name: 'Objects',
      icon: '⭐',
      emojis: [
        '⭐', '🌟', '💫', '✨', '🔥', '💥', '💢', '💤',
        '💨', '🌙', '☀️', '⭐', '🌟', '💫', '⚡', '☄️',
        '💎', '🔮', '🎯', '🎲', '🎪', '🎭', '🎨', '🎬',
        '🎤', '🎧', '🎵', '🎶', '🎹', '🥁', '🎸', '🎺',
      ],
    ),
    EmojiCategory(
      name: 'Nature',
      icon: '🌿',
      emojis: [
        '🌿', '🍀', '🌱', '🌲', '🌳', '🌴', '🌵', '🌾',
        '🌷', '🌸', '🌹', '🌺', '🌻', '🌼', '🌽', '🌾',
        '🍁', '🍂', '🍃', '🦋', '🐛', '🐝', '🐞', '🦗',
        '🕷', '🦂', '🐢', '🐍', '🐉', '🦎', '🦖', '🦕',
      ],
    ),
    EmojiCategory(
      name: 'Food',
      icon: '🍕',
      emojis: [
        '🍕', '🍔', '🍟', '🌭', '🍿', '🧂', '🥓', '🥚',
        '🍳', '🥞', '🧇', '🥨', '🥯', '🥖', '🍞', '🥐',
        '🧀', '🥗', '🥙', '🥪', '🌮', '🌯', '🥫', '🍝',
        '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🍚', '🍙',
      ],
    ),
    EmojiCategory(
      name: 'Symbols',
      icon: '❤️',
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
        '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉', '☸️',
        '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈',
      ],
    ),
  ];
}

