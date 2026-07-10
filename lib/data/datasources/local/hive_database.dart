import 'package:hive_flutter/hive_flutter.dart';
import '../../../models/metadata.dart';
import '../../../models/chapter.dart';
import '../../../models/paragraph.dart';
import '../../../models/word.dart';
import '../../../models/sync_word.dart';
import '../../models/highlight.dart';
import '../../models/bookmark.dart';
import '../../models/note.dart';
import '../../models/reading_progress.dart';
import '../../models/download_info.dart';

class HiveDatabase {
  static const String libraryBoxName = 'library';
  static const String highlightsBoxName = 'highlights';
  static const String bookmarksBoxName = 'bookmarks';
  static const String notesBoxName = 'notes';
  static const String progressBoxName = 'progress';
  static const String downloadsBoxName = 'downloads';
  static const String settingsBoxName = 'settings';

  static Future<void> init({String? subDir}) async {
    if (subDir == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(subDir);
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookMetadataAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChapterAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ParagraphAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(WordAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(SyncWordAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HighlightAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(NoteAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ReadingProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(DownloadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(DownloadInfoAdapter());
    }

    if (!Hive.isBoxOpen(libraryBoxName)) {
      await Hive.openBox<BookMetadata>(libraryBoxName);
    }
    if (!Hive.isBoxOpen(highlightsBoxName)) {
      await Hive.openBox<Highlight>(highlightsBoxName);
    }
    if (!Hive.isBoxOpen(bookmarksBoxName)) {
      await Hive.openBox<Bookmark>(bookmarksBoxName);
    }
    if (!Hive.isBoxOpen(notesBoxName)) {
      await Hive.openBox<Note>(notesBoxName);
    }
    if (!Hive.isBoxOpen(progressBoxName)) {
      await Hive.openBox<ReadingProgress>(progressBoxName);
    }
    if (!Hive.isBoxOpen(downloadsBoxName)) {
      await Hive.openBox<DownloadInfo>(downloadsBoxName);
    }
    if (!Hive.isBoxOpen(settingsBoxName)) {
      await Hive.openBox(settingsBoxName);
    }
  }

  static Box<BookMetadata> get libraryBox => Hive.box(libraryBoxName);
  static Box<Highlight> get highlightsBox => Hive.box(highlightsBoxName);
  static Box<Bookmark> get bookmarksBox => Hive.box(bookmarksBoxName);
  static Box<Note> get notesBox => Hive.box(notesBoxName);
  static Box<ReadingProgress> get progressBox => Hive.box(progressBoxName);
  static Box<DownloadInfo> get downloadsBox => Hive.box(downloadsBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}

class BookMetadataAdapter extends TypeAdapter<BookMetadata> {
  @override
  final int typeId = 0;

  @override
  BookMetadata read(BinaryReader reader) {
    return BookMetadata(
      id: reader.readInt(),
      title: reader.readString(),
      author: reader.readString(),
      duration: reader.readInt(),
      language: reader.readString(),
      cover: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, BookMetadata obj) {
    writer.writeInt(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.author);
    writer.writeInt(obj.duration);
    writer.writeString(obj.language);
    writer.writeString(obj.cover);
  }
}

class ChapterAdapter extends TypeAdapter<Chapter> {
  @override
  final int typeId = 1;

  @override
  Chapter read(BinaryReader reader) {
    return Chapter(
      title: reader.readString(),
      paragraphs: reader.readList().cast<Paragraph>(),
    );
  }

  @override
  void write(BinaryWriter writer, Chapter obj) {
    writer.writeString(obj.title);
    writer.writeList(obj.paragraphs);
  }
}

class ParagraphAdapter extends TypeAdapter<Paragraph> {
  @override
  final int typeId = 2;

  @override
  Paragraph read(BinaryReader reader) {
    return Paragraph(words: reader.readList().cast<Word>());
  }

  @override
  void write(BinaryWriter writer, Paragraph obj) {
    writer.writeList(obj.words);
  }
}

class WordAdapter extends TypeAdapter<Word> {
  @override
  final int typeId = 9;

  @override
  Word read(BinaryReader reader) {
    return Word(id: reader.readString(), text: reader.readString());
  }

  @override
  void write(BinaryWriter writer, Word obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.text);
  }
}

class SyncWordAdapter extends TypeAdapter<SyncWord> {
  @override
  final int typeId = 10;

  @override
  SyncWord read(BinaryReader reader) {
    return SyncWord(
      id: reader.readString(),
      start: reader.readDouble(),
      end: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, SyncWord obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.start);
    writer.writeDouble(obj.end);
  }
}

class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final int typeId = 3;

  @override
  Highlight read(BinaryReader reader) {
    return Highlight(
      id: reader.readString(),
      bookId: reader.readString(),
      chapterId: reader.readString(),
      paragraphIndex: reader.readInt(),
      startWordIndex: reader.readInt(),
      endWordIndex: reader.readInt(),
      selectedText: reader.readString(),
      color: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      noteId: reader.readBool() ? reader.readString() : null,
      wordIds: reader.readList().cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Highlight obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.bookId);
    writer.writeString(obj.chapterId);
    writer.writeInt(obj.paragraphIndex);
    writer.writeInt(obj.startWordIndex);
    writer.writeInt(obj.endWordIndex);
    writer.writeString(obj.selectedText);
    writer.writeString(obj.color);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.noteId != null);
    if (obj.noteId != null) writer.writeString(obj.noteId!);
    writer.writeList(obj.wordIds);
  }
}

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 4;

  @override
  Bookmark read(BinaryReader reader) {
    return Bookmark(
      id: reader.readString(),
      bookId: reader.readString(),
      chapterId: reader.readString(),
      paragraphIndex: reader.readInt(),
      wordIndex: reader.readInt(),
      previewText: reader.readBool() ? reader.readString() : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.bookId);
    writer.writeString(obj.chapterId);
    writer.writeInt(obj.paragraphIndex);
    writer.writeInt(obj.wordIndex);
    writer.writeBool(obj.previewText != null);
    if (obj.previewText != null) writer.writeString(obj.previewText!);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 5;

  @override
  Note read(BinaryReader reader) {
    return Note(
      id: reader.readString(),
      highlightId: reader.readString(),
      text: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.highlightId);
    writer.writeString(obj.text);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}

class ReadingProgressAdapter extends TypeAdapter<ReadingProgress> {
  @override
  final int typeId = 6;

  @override
  ReadingProgress read(BinaryReader reader) {
    return ReadingProgress(
      bookId: reader.readString(),
      chapterId: reader.readString(),
      paragraphIndex: reader.readInt(),
      wordIndex: reader.readInt(),
      positionSeconds: reader.readDouble(),
      progress: reader.readDouble(),
      lastReadAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingProgress obj) {
    writer.writeString(obj.bookId);
    writer.writeString(obj.chapterId);
    writer.writeInt(obj.paragraphIndex);
    writer.writeInt(obj.wordIndex);
    writer.writeDouble(obj.positionSeconds);
    writer.writeDouble(obj.progress);
    writer.writeInt(obj.lastReadAt.millisecondsSinceEpoch);
  }
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 7;

  @override
  DownloadStatus read(BinaryReader reader) {
    return DownloadStatus.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    writer.writeInt(obj.index);
  }
}

class DownloadInfoAdapter extends TypeAdapter<DownloadInfo> {
  @override
  final int typeId = 8;

  @override
  DownloadInfo read(BinaryReader reader) {
    return DownloadInfo(
      bookId: reader.readString(),
      status: DownloadStatus.values[reader.readInt()],
      progress: reader.readDouble(),
      localPath: reader.readBool() ? reader.readString() : null,
      downloadedAt: reader.readBool()
          ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadInfo obj) {
    writer.writeString(obj.bookId);
    writer.writeInt(obj.status.index);
    writer.writeDouble(obj.progress);
    writer.writeBool(obj.localPath != null);
    if (obj.localPath != null) writer.writeString(obj.localPath!);
    writer.writeBool(obj.downloadedAt != null);
    if (obj.downloadedAt != null) {
      writer.writeInt(obj.downloadedAt!.millisecondsSinceEpoch);
    }
  }
}
