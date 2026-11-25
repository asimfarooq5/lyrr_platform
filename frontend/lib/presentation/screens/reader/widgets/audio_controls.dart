/// Audio Controls Widget
/// Professional Audible & Apple Books inspired audio experience:
/// - Docked Mini-Player Bar (sleek, non-intrusive, integrated scrub line)
/// - Expandable Audible-Style Full Player Modal (cover art, big transport,
///   ±15s skips, speed selector presets, sleep timer with live countdown,
///   and audio source badges).

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AudioControls extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final bool isTtsPlaying;
  final bool isTtsMode;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeek;
  final Function(double) onSpeedChange;
  final VoidCallback onTtsToggle;
  final Color? textColor;
  final Color? bgColor;

  // Metadata & Extended Controls
  final String? bookTitle;
  final String? chapterTitle;
  final String? authorName;
  final String? coverUrl;
  final Duration? sleepTimerRemaining;
  final Function(int minutes, {bool endOfChapter})? onSetSleepTimer;
  final VoidCallback? onCancelSleepTimer;
  final VoidCallback? onOpenVoicePicker;
  final double voicePitch;
  final double volume;
  final Function(double)? onPitchChange;
  final Function(double)? onVolumeChange;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final bool hasPreviousChapter;
  final bool hasNextChapter;

  const AudioControls({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackSpeed,
    this.isTtsPlaying = false,
    this.isTtsMode = false,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onTtsToggle,
    this.textColor,
    this.bgColor,
    this.bookTitle,
    this.chapterTitle,
    this.authorName,
    this.coverUrl,
    this.sleepTimerRemaining,
    this.onSetSleepTimer,
    this.onCancelSleepTimer,
    this.onOpenVoicePicker,
    this.voicePitch = 1.0,
    this.volume = 1.0,
    this.onPitchChange,
    this.onVolumeChange,
    this.onPreviousChapter,
    this.onNextChapter,
    this.hasPreviousChapter = false,
    this.hasNextChapter = false,
  });

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _skip(Duration delta) {
    var next = currentPosition + delta;
    if (next < Duration.zero) next = Duration.zero;
    if (next > totalDuration) next = totalDuration;
    onSeek(next);
  }

  void _openFullPlayerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AudibleFullPlayerSheet(
        isPlaying: isPlaying || isTtsPlaying,
        isTtsMode: isTtsMode,
        currentPosition: currentPosition,
        totalDuration: totalDuration,
        playbackSpeed: playbackSpeed,
        bookTitle: bookTitle ?? 'LYRR Audio',
        chapterTitle: chapterTitle ?? 'Current Chapter',
        authorName: authorName,
        coverUrl: coverUrl,
        sleepTimerRemaining: sleepTimerRemaining,
        onPlayPause: onPlayPause,
        onSeek: onSeek,
        onSpeedChange: onSpeedChange,
        onTtsToggle: onTtsToggle,
        onSkip: _skip,
        onSetSleepTimer: onSetSleepTimer,
        onCancelSleepTimer: onCancelSleepTimer,
        onOpenVoicePicker: onOpenVoicePicker,
        voicePitch: voicePitch,
        volume: volume,
        onPitchChange: onPitchChange,
        onVolumeChange: onVolumeChange,
        onPreviousChapter: onPreviousChapter,
        onNextChapter: onNextChapter,
        hasPreviousChapter: hasPreviousChapter,
        hasNextChapter: hasNextChapter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playing = isPlaying || isTtsPlaying;
    final progress = totalDuration.inMilliseconds > 0
        ? (currentPosition.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFullPlayerSheet(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF01A1425), Color(0xF02A1F3D)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hairline scrub indicator across top
                  if (!isTtsMode && totalDuration.inMilliseconds > 0)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Play / Pause Circle
                        GestureDetector(
                          onTap: onPlayPause,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF8B5CF6)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title, Chapter, and Audio Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chapterTitle ?? (bookTitle ?? 'Audio Playback'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isTtsMode
                                          ? Colors.amber.withValues(alpha: 0.2)
                                          : AppColors.primaryLight.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isTtsMode ? 'AI Voice' : 'Studio Narration',
                                      style: TextStyle(
                                        color: isTtsMode ? Colors.amberAccent : AppColors.primaryLight,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isTtsMode
                                          ? (playing ? 'Narrating text · tap to expand' : 'Paused · tap to open player')
                                          : '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Sleep timer indicator badge if active
                        if (sleepTimerRemaining != null && sleepTimerRemaining! > Duration.zero) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bedtime, size: 12, color: Colors.indigoAccent),
                                const SizedBox(width: 3),
                                Text(
                                  '${sleepTimerRemaining!.inMinutes}m',
                                  style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],

                        // Quick skip -15s button (only if audio recording mode)
                        if (!isTtsMode)
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white70, size: 22),
                            tooltip: 'Rewind 10s',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _skip(const Duration(seconds: -10)),
                          ),

                        // Expand Pill / Open Full Sheet Button
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 26),
                          tooltip: 'Open Full Audible Player',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: () => _openFullPlayerSheet(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Audible-style Full Bottom Sheet Player
class _AudibleFullPlayerSheet extends StatefulWidget {
  final bool isPlaying;
  final bool isTtsMode;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final String bookTitle;
  final String chapterTitle;
  final String? authorName;
  final String? coverUrl;
  final Duration? sleepTimerRemaining;
  final VoidCallback onPlayPause;
  final Function(Duration) onSeek;
  final Function(double) onSpeedChange;
  final VoidCallback onTtsToggle;
  final Function(Duration) onSkip;
  final Function(int minutes, {bool endOfChapter})? onSetSleepTimer;
  final VoidCallback? onCancelSleepTimer;
  final VoidCallback? onOpenVoicePicker;
  final double voicePitch;
  final double volume;
  final Function(double)? onPitchChange;
  final Function(double)? onVolumeChange;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final bool hasPreviousChapter;
  final bool hasNextChapter;

  const _AudibleFullPlayerSheet({
    required this.isPlaying,
    required this.isTtsMode,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackSpeed,
    required this.bookTitle,
    required this.chapterTitle,
    this.authorName,
    this.coverUrl,
    this.sleepTimerRemaining,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSpeedChange,
    required this.onTtsToggle,
    required this.onSkip,
    this.onSetSleepTimer,
    this.onCancelSleepTimer,
    this.onOpenVoicePicker,
    required this.voicePitch,
    required this.volume,
    this.onPitchChange,
    this.onVolumeChange,
    this.onPreviousChapter,
    this.onNextChapter,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
  });

  @override
  State<_AudibleFullPlayerSheet> createState() => _AudibleFullPlayerSheetState();
}

class _AudibleFullPlayerSheetState extends State<_AudibleFullPlayerSheet> {
  double? _dragValue;

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _showSpeedPicker() {
    final speeds = [0.75, 0.9, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E182A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Narration Speed',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final s in speeds)
                ListTile(
                  title: Text(
                    '${s}x ${s == 1.0 ? '(Normal)' : ''}',
                    style: TextStyle(
                      color: (widget.playbackSpeed - s).abs() < 0.05 ? AppColors.primaryLight : Colors.white,
                      fontWeight: (widget.playbackSpeed - s).abs() < 0.05 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: (widget.playbackSpeed - s).abs() < 0.05
                      ? const Icon(Icons.check, color: AppColors.primaryLight)
                      : null,
                  onTap: () {
                    widget.onSpeedChange(s);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerPicker() {
    final options = [
      (0, 'Turn Off Timer', false),
      (15, '15 Minutes', false),
      (30, '30 Minutes', false),
      (45, '45 Minutes', false),
      (60, '60 Minutes', false),
      (0, 'End of Chapter', true),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E182A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bedtime, color: Colors.indigoAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Sleep Timer',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final opt in options)
                ListTile(
                  leading: Icon(
                    opt.$3 ? Icons.bookmark_border : Icons.timer_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(opt.$2, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (opt.$1 == 0 && !opt.$3) {
                      widget.onCancelSleepTimer?.call();
                    } else {
                      widget.onSetSleepTimer?.call(opt.$1, endOfChapter: opt.$3);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final total = widget.totalDuration.inMilliseconds.toDouble();
    final pos = widget.currentPosition.inMilliseconds.toDouble();
    final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    final displayPos = _dragValue != null && total > 0
        ? Duration(milliseconds: (_dragValue! * total).round())
        : widget.currentPosition;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Dismiss button, Mode Badge, Voice Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, color: fg, size: 30),
                    tooltip: 'Minimize Player',
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isTtsMode
                          ? Colors.amber.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.isTtsMode ? Colors.amberAccent : AppColors.primaryLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isTtsMode ? Icons.auto_awesome : Icons.headset_rounded,
                          size: 14,
                          color: widget.isTtsMode ? Colors.amberAccent : AppColors.primaryLight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.isTtsMode ? 'AI Text-to-Speech' : 'Audiobook Narration',
                          style: TextStyle(
                            color: widget.isTtsMode ? Colors.amberAccent : AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      widget.isTtsMode ? Icons.record_voice_over : Icons.spatial_audio,
                      color: fg.withValues(alpha: 0.8),
                      size: 22,
                    ),
                    tooltip: 'Toggle Narration Mode',
                    onPressed: widget.onTtsToggle,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Book Cover Card
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1B4E), Color(0xFF1E1035)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.coverUrl != null && widget.coverUrl!.isNotEmpty
                      ? Image.network(
                          widget.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              const SizedBox(height: 18),

              // Chapter & Book Titles
              Text(
                widget.chapterTitle,
                style: const TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.bookTitle + (widget.authorName != null ? ' · ${widget.authorName}' : ''),
                style: TextStyle(
                  color: fg.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Scrub Bar (if not pure TTS or if duration is known)
              if (!widget.isTtsMode) ...[
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primaryLight,
                    inactiveTrackColor: fg.withValues(alpha: 0.15),
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primaryLight.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _dragValue ?? progress,
                    onChanged: (val) => setState(() => _dragValue = val),
                    onChangeEnd: (val) {
                      setState(() => _dragValue = null);
                      if (total > 0) {
                        widget.onSeek(Duration(milliseconds: (val * total).round()));
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(displayPos),
                        style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.6)),
                      ),
                      Text(
                        _formatDuration(widget.totalDuration),
                        style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Device voice synchronizes live with paragraph reading',
                    style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Main Transport Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous Chapter
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: widget.hasPreviousChapter ? fg : fg.withValues(alpha: 0.3),
                      size: 32,
                    ),
                    tooltip: 'Previous Chapter',
                    onPressed: widget.hasPreviousChapter ? widget.onPreviousChapter : null,
                  ),
                  const SizedBox(width: 12),

                  // Rewind 15s
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: fg, size: 30),
                    tooltip: 'Rewind 10 seconds',
                    onPressed: () => widget.onSkip(const Duration(seconds: -10)),
                  ),
                  const SizedBox(width: 16),

                  // Hero Play / Pause Button
                  GestureDetector(
                    onTap: widget.onPlayPause,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF9333EA)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Forward 15s
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: fg, size: 30),
                    tooltip: 'Forward 10 seconds',
                    onPressed: () => widget.onSkip(const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 12),

                  // Next Chapter
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: widget.hasNextChapter ? fg : fg.withValues(alpha: 0.3),
                      size: 32,
                    ),
                    tooltip: 'Next Chapter',
                    onPressed: widget.hasNextChapter ? widget.onNextChapter : null,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Secondary Actions Bar (Speed, Sleep Timer, Voice)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Speed Selector
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _showSpeedPicker,
                    icon: const Icon(Icons.speed, size: 18, color: AppColors.primaryLight),
                    label: Text('${widget.playbackSpeed}x', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),

                  // Sleep Timer
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      backgroundColor: widget.sleepTimerRemaining != null
                          ? Colors.indigo.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: widget.sleepTimerRemaining != null
                            ? const BorderSide(color: Colors.indigoAccent)
                            : BorderSide.none,
                      ),
                    ),
                    onPressed: _showSleepTimerPicker,
                    icon: Icon(
                      Icons.bedtime,
                      size: 18,
                      color: widget.sleepTimerRemaining != null ? Colors.indigoAccent : Colors.white70,
                    ),
                    label: Text(
                      widget.sleepTimerRemaining != null
                          ? '${widget.sleepTimerRemaining!.inMinutes}m left'
                          : 'Sleep',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  // Voice / Narration Settings
                  if (widget.isTtsMode && widget.onOpenVoicePicker != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: fg,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: widget.onOpenVoicePicker,
                      icon: const Icon(Icons.record_voice_over, size: 18, color: Colors.amberAccent),
                      label: const Text('Voice', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: const Color(0xFF281C3D),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_rounded, color: Colors.white54, size: 48),
    );
  }
}
