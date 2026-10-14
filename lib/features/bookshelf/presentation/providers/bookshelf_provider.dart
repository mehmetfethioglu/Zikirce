import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../domain/entities/book_entity.dart';
import '../../../../domain/entities/habit_profile_entity.dart';
import '../../../reader/services/book_import_service.dart';

class BookshelfState {
  final List<BookEntity> books;
  final HabitProfileEntity? habitProfile;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const BookshelfState({
    this.books = const [],
    this.habitProfile,
    this.isLoading = true,
    this.errorMessage,
    this.searchQuery = '',
  });

  List<BookEntity> get filteredBooks {
    if (searchQuery.trim().isEmpty) return books;
    final q = searchQuery.toLowerCase();
    return books.where((b) => b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
  }

  BookshelfState copyWith({
    List<BookEntity>? books,
    HabitProfileEntity? habitProfile,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return BookshelfState(
      books: books ?? this.books,
      habitProfile: habitProfile ?? this.habitProfile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class BookshelfNotifier extends StateNotifier<BookshelfState> {
  final Ref _ref;

  BookshelfNotifier(this._ref) : super(const BookshelfState()) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final bookRepo = _ref.read(bookRepositoryProvider);
    final habitRepo = _ref.read(habitRepositoryProvider);

    final booksResult = await bookRepo.getAllBooks();
    final habitResult = await habitRepo.getHabitProfile();

    if (booksResult.isSuccess) {
      state = state.copyWith(
        books: booksResult.dataOrNull ?? [],
        habitProfile: habitResult.dataOrNull,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: booksResult.errorOrNull?.message,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<BookEntity?> importBook() async {
    final bookRepo = _ref.read(bookRepositoryProvider);
    final service = BookImportService(bookRepo);
    final res = await service.pickAndImportBook();

    if (res.isSuccess && res.dataOrNull != null) {
      await loadBooks();
      return res.dataOrNull;
    }
    return null;
  }

  Future<void> deleteBook(int id) async {
    final bookRepo = _ref.read(bookRepositoryProvider);
    await bookRepo.deleteBook(id);
    await loadBooks();
  }
}

final bookshelfProvider = StateNotifierProvider<BookshelfNotifier, BookshelfState>((ref) {
  return BookshelfNotifier(ref);
});
