import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../theme_manager.dart';
import '../models/canvas_media.dart';

/// MediaPanel: Clean minimal dock for media import
/// 
/// Design Philosophy:
/// "I import media. I place media. I shut up."
class MediaPanel extends StatefulWidget {
  final ThemeManager themeManager;
  final Function(String emoji) onEmojiSelected;
  final Function(Uint8List imageData, Size size, String filePath, bool isSvg) onImageSelected;
  final VoidCallback onClose;
  final double dockScale; // Scale factor for dock size

  const MediaPanel({
    super.key,
    required this.themeManager,
    required this.onEmojiSelected,
    required this.onImageSelected,
    required this.onClose,
    this.dockScale = 1.0,
  });

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  String _selectedCategory = EmojiStickers.categories.first.name;
  bool _isImporting = false;
  String? _hoveredEmoji;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _handleFileImport() async {
    if (_isImporting) return;
    
    setState(() => _isImporting = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final file = result.files.single;
      
      if (file.bytes == null) {
        throw Exception('File data is empty');
      }

      final bytes = file.bytes!;
      final extension = file.extension?.toLowerCase() ?? '';
      final isSvg = extension == 'svg';
      final fileName = file.name;

      Size imageSize;
      if (isSvg) {
        imageSize = const Size(200, 200);
      } else {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
      }

      final filePath = kIsWeb ? fileName : (file.path ?? fileName);

      widget.onImageSelected(bytes, imageSize, filePath, isSvg);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text('Click canvas to place', style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green.shade900,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() => _isImporting = false);
    } catch (e) {
      setState(() => _isImporting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate scaled dimensions with better proportions
    final dockWidth = (260 * widget.dockScale).clamp(195.0, 520.0); // Larger base width
    final headerHeight = (36 * widget.dockScale).clamp(30.0, 54.0); // Slightly taller header
    final tabHeight = (34 * widget.dockScale).clamp(28.0, 50.0); // Taller tabs
    final categoryHeight = (36 * widget.dockScale).clamp(30.0, 54.0); // Taller categories
    final emojiSize = (28 * widget.dockScale).clamp(20.0, 42.0); // Larger emojis
    final gridPadding = (10 * widget.dockScale).clamp(8.0, 20.0); // More padding
    final gridSpacing = (6 * widget.dockScale).clamp(4.0, 12.0); // Better spacing
    final crossAxisCount = (dockWidth / 65).floor().clamp(3, 8); // Better cell calculation

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: widget.themeManager,
        builder: (context, _) {
          final theme = widget.themeManager.currentTheme;

          return Container(
            width: dockWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: theme.panelColor.withValues(alpha: 0.95),
              border: Border(
                right: BorderSide(
                  color: theme.borderColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(theme, headerHeight),

                // Tabs
                _buildTabs(theme, tabHeight),

                // Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmojiView(theme, categoryHeight, crossAxisCount, emojiSize, gridPadding, gridSpacing),
                      _buildImportView(theme),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(CanvasTheme theme, double headerHeight) {
    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.borderColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 14, color: theme.accentColor.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            'Media',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(CanvasTheme theme, double tabHeight) {
    return Container(
      height: tabHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.borderColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: theme.accentColor,
        unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
        indicatorColor: theme.accentColor,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: 'EMOJI'),
          Tab(text: 'IMPORT'),
        ],
      ),
    );
  }

  Widget _buildEmojiView(CanvasTheme theme, double categoryHeight, int crossAxisCount, double emojiSize, double gridPadding, double gridSpacing) {
    return Column(
      children: [
        // Category pills (horizontal scroll)
        Container(
          height: categoryHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: EmojiStickers.categories.length,
            itemBuilder: (context, index) {
              final category = EmojiStickers.categories[index];
              final isSelected = _selectedCategory == category.name;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.accentColor.withValues(alpha: 0.2)
                          : theme.backgroundColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? theme.accentColor
                            : theme.borderColor.withValues(alpha: 0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.icon, style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 3),
                        Text(
                          category.name,
                          style: TextStyle(
                            color: isSelected
                                ? theme.accentColor
                                : theme.textColor.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Emoji grid
        Expanded(
          child: _buildEmojiGrid(theme, crossAxisCount, emojiSize, gridPadding, gridSpacing),
        ),
      ],
    );
  }

  Widget _buildEmojiGrid(CanvasTheme theme, int crossAxisCount, double emojiSize, double gridPadding, double gridSpacing) {
    final category = EmojiStickers.categories.firstWhere(
      (c) => c.name == _selectedCategory,
      orElse: () => EmojiStickers.categories.first,
    );

    return GridView.builder(
      padding: EdgeInsets.all(gridPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.0,
        crossAxisSpacing: gridSpacing,
        mainAxisSpacing: gridSpacing,
      ),
      itemCount: category.emojis.length,
      itemBuilder: (context, index) {
        final emoji = category.emojis[index];
        final isHovered = _hoveredEmoji == emoji;
        
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredEmoji = emoji),
          onExit: (_) => setState(() => _hoveredEmoji = null),
          child: GestureDetector(
            onTap: () => widget.onEmojiSelected(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: isHovered
                    ? theme.backgroundColor.withValues(alpha: 0.3)
                    : theme.backgroundColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isHovered
                      ? theme.accentColor.withValues(alpha: 0.3)
                      : theme.borderColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: isHovered ? 1.15 : 1.0,
                  child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportView(CanvasTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Upload button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _handleFileImport,
              icon: _isImporting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.textColor),
                      ),
                    )
                  : Icon(Icons.upload_file, size: 16, color: theme.textColor),
              label: Text(
                _isImporting ? 'Loading...' : 'Upload PNG/SVG',
                style: TextStyle(color: theme.textColor, fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor.withValues(alpha: 0.2),
                disabledBackgroundColor: theme.accentColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: theme.accentColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: theme.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Supported',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'PNG, JPG, SVG',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
