import 'package:flutter/material.dart';
import '../models/canvas_media.dart';

/// MediaManager: Manages media items (emoji stickers and images) on the canvas
class MediaManager extends ChangeNotifier {
  final List<CanvasMedia> _mediaItems = [];
  String? _selectedMediaId;

  List<CanvasMedia> get mediaItems => List.unmodifiable(_mediaItems);
  String? get selectedMediaId => _selectedMediaId;
  CanvasMedia? get selectedMedia => _selectedMediaId != null
      ? _mediaItems.firstWhere(
          (m) => m.id == _selectedMediaId,
          orElse: () => _mediaItems.first, // Fallback
        )
      : null;

  /// Add a media item to the canvas
  void addMedia(CanvasMedia media) {
    _mediaItems.add(media);
    notifyListeners();
  }

  /// Remove a media item from the canvas
  void removeMedia(String mediaId) {
    _mediaItems.removeWhere((m) => m.id == mediaId);
    if (_selectedMediaId == mediaId) {
      _selectedMediaId = null;
    }
    notifyListeners();
  }

  /// Update media position
  void updateMediaPosition(String mediaId, Offset newPosition) {
    final index = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (index != -1) {
      _mediaItems[index] = _mediaItems[index].copyWith(position: newPosition);
      notifyListeners();
    }
  }

  /// Update media size
  void updateMediaSize(String mediaId, Size newSize) {
    final index = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (index != -1) {
      _mediaItems[index] = _mediaItems[index].copyWith(size: newSize);
      notifyListeners();
    }
  }

  /// Update media notes
  void updateMediaNotes(String mediaId, String notes) {
    final index = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (index != -1) {
      _mediaItems[index] = _mediaItems[index].copyWith(notes: notes);
      notifyListeners();
    }
  }

  /// Update media border visibility
  void updateMediaBorder(String mediaId, bool showBorder) {
    final index = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (index != -1) {
      _mediaItems[index] = _mediaItems[index].copyWith(showBorder: showBorder);
      notifyListeners();
    }
  }

  /// Select a media item
  void selectMedia(String? mediaId) {
    // Deselect all
    for (var media in _mediaItems) {
      if (media.isSelected) {
        final index = _mediaItems.indexOf(media);
        _mediaItems[index] = media.copyWith(isSelected: false);
      }
    }

    // Select new media
    if (mediaId != null) {
      final index = _mediaItems.indexWhere((m) => m.id == mediaId);
      if (index != -1) {
        _mediaItems[index] = _mediaItems[index].copyWith(isSelected: true);
        _selectedMediaId = mediaId;
      }
    } else {
      _selectedMediaId = null;
    }
    notifyListeners();
  }

  /// Get media by ID
  CanvasMedia? getMedia(String mediaId) {
    try {
      return _mediaItems.firstWhere((m) => m.id == mediaId);
    } catch (e) {
      return null;
    }
  }

  /// Get media at a specific position
  CanvasMedia? getMediaAtPosition(Offset position) {
    for (var media in _mediaItems.reversed) {
      if (media.containsPoint(position)) {
        return media;
      }
    }
    return null;
  }

  /// Select all media in a rectangle
  void selectMediaInRect(Rect rect) {
    for (var media in _mediaItems) {
      if (rect.overlaps(media.bounds)) {
        final index = _mediaItems.indexOf(media);
        _mediaItems[index] = media.copyWith(isSelected: true);
        _selectedMediaId = media.id;
      }
    }
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    for (var media in _mediaItems) {
      if (media.isSelected) {
        final index = _mediaItems.indexOf(media);
        _mediaItems[index] = media.copyWith(isSelected: false);
      }
    }
    _selectedMediaId = null;
    notifyListeners();
  }

  /// Remove all selected media
  void removeSelectedMedia() {
    _mediaItems.removeWhere((m) => m.isSelected);
    _selectedMediaId = null;
    notifyListeners();
  }

  /// Clear all media
  void clear() {
    _mediaItems.clear();
    _selectedMediaId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaItems.clear();
    super.dispose();
  }
}

