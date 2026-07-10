import 'package:flutter/material.dart';
import '../models/metadata.dart';
import '../utils/constants.dart';

class BookCover extends StatelessWidget {
  final BookMetadata metadata;
  final double height;
  final double width;
  final bool showShadow;

  const BookCover({
    super.key,
    required this.metadata,
    this.height = 280,
    this.width = 210,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(128),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          AppConstants.coverPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[900],
              child: const Icon(
                Icons.book_rounded,
                size: 64,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}
