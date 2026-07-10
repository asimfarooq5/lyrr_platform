import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/player_controller.dart';
import '../controllers/reader_controller.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/reader_view.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late PlayerController _playerController;
  late ReaderController _readerController;

  @override
  void initState() {
    super.initState();
    _playerController = context.read<PlayerController>();
    _readerController = context.read<ReaderController>();
    _playerController.loadAudio(AppConstants.audioPath);
    _readerController.attachPlayerController(_playerController);
  }

  @override
  void dispose() {
    _playerController.pause();
    super.dispose();
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final controller = context.watch<ReaderController>();
            final colors = ReaderColors.of(controller.themeMode);
            return Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reader Settings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.text)),
                      IconButton(icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: colors.dividerColor, height: 1),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Font Size', style: TextStyle(color: colors.text)),
                      Row(children: [
                        IconButton(icon: Icon(Icons.remove_circle_outline, color: colors.text),
                            onPressed: () { controller.decreaseFontSize(); setModalState(() {}); }),
                        Text('${controller.fontSize.toInt()} px',
                            style: TextStyle(fontWeight: FontWeight.bold, color: colors.text)),
                        IconButton(icon: Icon(Icons.add_circle_outline, color: colors.text),
                            onPressed: () { controller.increaseFontSize(); setModalState(() {}); }),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Line Spacing', style: TextStyle(color: colors.text)),
                      Row(children: [
                        _spacingBtn(controller, 1.2, 'Narrow', colors),
                        const SizedBox(width: 8),
                        _spacingBtn(controller, 1.5, 'Normal', colors),
                        const SizedBox(width: 8),
                        _spacingBtn(controller, 1.8, 'Wide', colors),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('Color Theme',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.text)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _themeTile(controller, ReaderThemeMode.light, 'Light', AppTheme.lightBg, AppTheme.lightTextPrimary),
                      _themeTile(controller, ReaderThemeMode.sepia, 'Sepia', AppTheme.sepiaBg, AppTheme.sepiaTextPrimary),
                      _themeTile(controller, ReaderThemeMode.dark, 'Dark', AppTheme.darkBg, AppTheme.darkTextPrimary),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _spacingBtn(ReaderController controller, double spacing, String label, ReaderColors colors) {
    final isSelected = (controller.lineSpacing - spacing).abs() < 0.05;
    return GestureDetector(
      onTap: () => controller.setLineSpacing(spacing),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : colors.dividerColor),
        ),
        child: Text(label,
            style: TextStyle(color: isSelected ? Colors.white : colors.text,
                fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _themeTile(ReaderController controller, ReaderThemeMode mode, String label, Color bg, Color fg) {
    final isSelected = controller.themeMode == mode;
    return GestureDetector(
      onTap: () => controller.setThemeMode(mode),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[800]!, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Text('Aa', style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Serif')),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: fg.withOpacity(0.8), fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerController = context.watch<ReaderController>();
    final colors = ReaderColors.of(readerController.themeMode);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.text),
            onPressed: () => Navigator.pop(context)),
        title: Text(readerController.book?.metadata.title ?? 'Reader',
            style: TextStyle(color: colors.text, fontFamily: 'Serif', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: Icon(Icons.text_fields_rounded, color: colors.text),
              onPressed: _showSettingsBottomSheet),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ReaderView()),
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: colors.cardBackground.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.dividerColor.withOpacity(0.5), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                ProgressBar(),
                SizedBox(height: 8),
                PlayerControls(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
