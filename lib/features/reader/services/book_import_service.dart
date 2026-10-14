import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/errors/app_error.dart';
import '../../../domain/entities/book_entity.dart';
import '../../../domain/repositories/book_repository.dart';

class BookImportService {
  final BookRepository _bookRepository;

  BookImportService(this._bookRepository);

  Future<Result<BookEntity?>> pickAndImportBook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'md'],
      );

      if (result == null || result.files.isEmpty) {
        return Result.success(null);
      }

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) {
        return Result.failure(GeneralError('Dosya yolu okunamadı'));
      }

      final fileName = p.basenameWithoutExtension(filePath);
      final extension = p.extension(filePath).toLowerCase();

      BookFormat format = BookFormat.pdf;
      int totalPages = 1;

      if (extension == '.pdf') {
        format = BookFormat.pdf;
        try {
          final bytes = await File(filePath).readAsBytes();
          final doc = PdfDocument(inputBytes: bytes);
          totalPages = doc.pages.count;
          doc.dispose();
        } catch (_) {
          totalPages = 10;
        }
      } else if (extension == '.epub') {
        format = BookFormat.epub;
        totalPages = 50; // Approximated
      } else if (extension == '.md') {
        format = BookFormat.markdown;
        totalPages = 20;
      } else {
        format = BookFormat.txt;
        totalPages = 15;
      }

      final now = DateTime.now();
      final newBook = BookEntity(
        title: fileName,
        author: 'Bilinmeyen Yazar',
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
