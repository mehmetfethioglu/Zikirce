import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
    // Eğer başında timestamp_ varsa temizle
    final withoutTimestamp = rawName.replaceFirst(RegExp(r'^\d{10,}_'), '');
    final cleaned = withoutTimestamp
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isNotEmpty ? cleaned : rawName;
  }

  Future<Result<BookEntity?>> pickAndImportBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'md', 'markdown', 'html', 'htm'],
      );

      if (result == null || result.files.isEmpty) {
        return const Result.success(null);
      }

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null || filePath.trim().isEmpty) {
        return const Result.failure(GeneralError('Dosya yolu okunamadı'));
      }

      return await importBookFromPath(filePath);
    } catch (e, st) {
      return Result.failure(
        StorageError('Dosya seçilemedi: $e', cause: e, stackTrace: st),
      );
    }
  }

  static const Set<String> _allowedExtensions = {
    'pdf',
    'epub',
    'txt',
    'md',
    'markdown',
    'html',
    'htm',
  };
  static const int _maxBinaryBookBytes = 150 * 1024 * 1024;
  static const int _maxTextBookBytes = 25 * 1024 * 1024;

  /// Seçilen veya "Birlikte Aç" (ACTION_VIEW) ile gelen dosyayı kalıcı uygulama dizinine
  /// (`tahrir_books/`) kopyalar ve SQLite veritabanına kalıcı yoluyla kaydeder.
  Future<Result<BookEntity?>> importBookFromPath(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return const Result.failure(GeneralError('Seçilen dosya bulunamadı'));
      }

      final rawExt =
          p.extension(sourcePath).toLowerCase().replaceFirst('.', '').trim();
      if (!_allowedExtensions.contains(rawExt)) {
        return const Result.failure(
          GeneralError('Desteklenmeyen dosya uzantısı. Yalnızca PDF, EPUB ve metin dosyaları açılabilir.'),
        );
      }

      final sourceLength = await sourceFile.length();
      final maxBytes =
          (rawExt == 'pdf' || rawExt == 'epub') ? _maxBinaryBookBytes : _maxTextBookBytes;
      if (sourceLength <= 0 || sourceLength > maxBytes) {
        return const Result.failure(
          GeneralError('Dosya boyutu geçersiz veya güvenli üst sınırı (150 MB) aşıyor.'),
        );
      }

      final originalFileName = p.basename(sourcePath);
      final strippedPrefix =
          originalFileName.replaceFirst(RegExp(r'^(?:shared_book_)?\d{10,}_'), '');
      final cleanOriginalName = strippedPrefix
          .replaceAll('..', '_')
          .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
          .trim();
      if (cleanOriginalName.isEmpty) {
        return const Result.failure(GeneralError('Geçersiz dosya adı'));
      }

      // Aynı dosya adı ve boyutu zaten kütüphanede varsa mevcut kitabı döndür
      final existingBooksRes = await _bookRepository.getAllBooks();
      final existingBooks = existingBooksRes.dataOrNull ?? const <BookEntity>[];
      for (final existing in existingBooks) {
        if (existing.filePath.startsWith('sample://')) continue;
        final existingFile = File(existing.filePath);
        if (await existingFile.exists()) {
          final existingBase = p
              .basename(existing.filePath)
              .replaceFirst(RegExp(r'^(?:shared_book_)?\d{10,}_'), '');
          if (existingBase.toLowerCase() == cleanOriginalName.toLowerCase()) {
            final existingLen = await existingFile.length();
            if (existingLen == sourceLength) {
              return Result.success(existing);
            }
          }
        }
      }

      // Kalıcı tahrir_books/ klasörünü hazırla ve dosyayı kopyala
      final docsDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(docsDir.path, 'tahrir_books'));
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentFileName = '${timestamp}_$cleanOriginalName';
      final permanentPath = p.normalize(p.join(booksDir.path, permanentFileName));
      if (!p.isWithin(p.normalize(booksDir.path), permanentPath)) {
        return const Result.failure(GeneralError('Güvenli olmayan hedef dosya yolu'));
      }

      final File diskFile;
      if (p.equals(p.dirname(sourcePath), booksDir.path)) {
        diskFile = sourceFile;
      } else {
        diskFile = await sourceFile.copy(permanentPath);
      }

      final savedFilePath = diskFile.path;
      final fileNameNoExt = p.basenameWithoutExtension(cleanOriginalName);
      final cleanName = _cleanFileName(fileNameNoExt);
      final ext = p.extension(savedFilePath).toLowerCase().replaceFirst('.', '');

      BookFormat format = BookFormat.pdf;
      int totalPages = 1;
      String bookTitle = cleanName;
      String bookAuthor = 'Bilinmeyen Yazar';

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
      } else if (ext == 'md' ||
          ext == 'markdown' ||
          ext == 'txt' ||
          ext == 'html' ||
          ext == 'htm') {
        format =
            (ext == 'md' || ext == 'markdown') ? BookFormat.markdown : BookFormat.txt;
        try {
          final content = await diskFile.readAsString();
          final firstHeading =
              RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
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
      final validPages = totalPages > 0 ? totalPages : 1;
      final newBook = BookEntity(
        title: bookTitle,
        author: bookAuthor,
        filePath: savedFilePath,
        format: format,
        totalPages: validPages,
        currentPage: 1,
        estimatedRemainingMinutes: (validPages * 1.5).round().clamp(1, 9999),
        addedDate: now,
        lastReadDate: now,
      );

      final insertResult = await _bookRepository.insertBook(newBook);
      if (insertResult.isFailure) {
        return Result.failure(insertResult.errorOrNull!);
      }

      final created = newBook.copyWith(id: insertResult.dataOrNull);
      return Result.success(created);
    } catch (e, st) {
      return Result.failure(
        StorageError('Dosya içe aktarılamadı: $e', cause: e, stackTrace: st),
      );
    }
  }
}
