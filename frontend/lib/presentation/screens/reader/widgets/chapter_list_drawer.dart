/// Chapter List Drawer
/// Table of Contents slide-out drawer for the reader

import 'package:flutter/material.dart';
import '../../../../data/models/book_model.dart';
import '../../../../data/models/user_data_model.dart';
import '../../../theme/app_theme.dart';

class ChapterListDrawer extends StatelessWidget {
  final List<ChapterModel> chapters;
  final int currentChapterIndex;
  final List<BookmarkModel> bookmarks;
  final void Function(int index) onChapterSelected;

  const ChapterListDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    this.bookmarks = const [],
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceLight,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list, size: 20, color: AppColors.textPrimaryLight),
                  const SizedBox(width: 10),
                  Text('Table of Contents',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close, size: 20, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),

            // Chapter list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isCurrent = index == currentChapterIndex;
                  final hasBookmark = bookmarks.any((b) => b.chapterId == chapter.id);

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onChapterSelected(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary.withValues(alpha: 0.08) : null,
                        border: Border(
                          left: BorderSide(
                            color: isCurrent ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Chapter number
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.primary : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                )),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title
                          Expanded(
                            child: Text(chapter.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                color: AppColors.textPrimaryLight,
                              ),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          // Bookmark indicator
                          if (hasBookmark)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFD700),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
