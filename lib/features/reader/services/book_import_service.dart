import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/errors/app_error.dart';
import '../../../domain/entities/book_entity.dart';
import '../../../domain/repositories/book_repository.dart';

class BookImportService {
  final BookRepository _bookRepository;

  BookImportService(this._bookRepository);

  int _countEpubChapters(List<EpubChapter>? chapters) {
    if (chapters == null || chapters.isEmpty) return 0;
    int count = 0;
    for (final ch in chapters) {
      if ((ch.HtmlContent ?? '').trim().isNotEmpty) {
        count++;
      }
      final sub = ch.SubChapters;
      if (sub != null && sub.isNotEmpty) {
        count += _countEpubChapters(sub);
      }
    }
    return count;
  }

  String _cleanFileName(String rawName) {
    final cleaned = rawName.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : rawName;
  }

  Future<Result<BookEntity?>> pickAndImportBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'md'],
      );

      if (result == null || result.files.isEmpty) {
        return Result.success(null);
      }

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null) {
        return Result.failure(GeneralError('Dosya yolu okunamadı'));
      }

      final fileName = p.basenameWithoutExtension(filePath);
      final cleanName = _cleanFileName(fileName);
      final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');

      BookFormat format = BookFormat.pdf;
      int totalPages = 1;
      String bookTitle = cleanName;
      String bookAuthor = 'Bilinmeyen Yazar';

      final diskFile = File(filePath);

      if (ext == 'pdf') {
        format = BookFormat.pdf;
        try {
          final bytes = await diskFile.readAsBytes();
          final doc = PdfDocument(inputBytes: bytes);
          totalPages = doc.pages.count > 0 ? doc.pages.count : 1;

          final docTitle = doc.documentInformation.title.trim();
          final docAuthor = doc.documentInformation.author.trim();
          if (docTitle.isNotEmpty) {
            bookTitle = docTitle;
          }
          if (docAuthor.isNotEmpty) {
            bookAuthor = docAuthor;
          }
          doc.dispose();
        } catch (_) {
          totalPages = 1;
        }
      } else if (ext == 'epub') {
        format = BookFormat.epub;
        try {
          final bytes = await diskFile.readAsBytes();
          final epubBook = await EpubReader.readBook(bytes);
          final epubTitle = (epubBook.Title ?? '').trim();
          final epubAuthor = (epubBook.Author ?? '').trim();
          if (epubTitle.isNotEmpty) {
            bookTitle = epubTitle;
          }
          if (epubAuthor.isNotEmpty) {
            bookAuthor = epubAuthor;
          }
          final chapterCount = _countEpubChapters(epubBook.Chapters);
          totalPages = chapterCount > 0 ? chapterCount : 1;
        } catch (_) {
          totalPages = 1;
        }
      } else if (ext == 'md' || ext == 'txt') {
        format = ext == 'md' ? BookFormat.markdown : BookFormat.txt;
        try {
          final content = await diskFile.readAsString();
          final firstHeading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
          if (firstHeading != null) {
            final headingTitle = firstHeading.group(1)!.trim();
            if (headingTitle.isNotEmpty) {
              bookTitle = headingTitle;
            }
          }
          totalPages = (content.length / 1800).ceil().clamp(1, 9999);
        } catch (_) {
          totalPages = 1;
        }
      }

      final now = DateTime.now();
      final newBook = BookEntity(
        title: bookTitle,
        author: bookAuthor,
        filePath: filePath,
        format: format,
        totalPages: totalPages > 0 ? totalPages : 1,
        currentPage: 1,
        addedDate: now,
        lastReadDate: now,
      );

      final insertResult = await _bookRepository.insertBook(newBook);
      if (insertResult.isFailure) return Result.failure(insertResult.errorOrNull!);

      final created = newBook.copyWith(id: insertResult.dataOrNull);
      return Result.success(created);
    } catch (e, st) {
      return Result.failure(StorageError('Dosya içe aktarılamadı: $e', cause: e, stackTrace: st));
    }
  }
}
