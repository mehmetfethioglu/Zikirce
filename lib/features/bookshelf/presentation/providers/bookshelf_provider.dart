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
  final int todayMinutesRead;
  final String selectedFilter;

  const BookshelfState({
    this.books = const [],
    this.habitProfile,
    this.isLoading = true,
    this.errorMessage,
    this.searchQuery = '',
    this.todayMinutesRead = 0,
    this.selectedFilter = 'all',
  });

  List<BookEntity> get filteredBooks {
    var result = books;

    switch (selectedFilter) {
      case 'reading':
        result = result.where((b) => !b.isCompleted).toList();
      case 'completed':
        result = result.where((b) => b.isCompleted).toList();
      case 'pdf':
        result = result.where((b) => b.format == BookFormat.pdf).toList();
      case 'epub':
        result = result.where((b) => b.format == BookFormat.epub).toList();
      default:
        break;
    }

    if (searchQuery.trim().isEmpty) return result;
    final q = searchQuery.toLowerCase();
    return result
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList();
  }

  BookshelfState copyWith({
    List<BookEntity>? books,
    HabitProfileEntity? habitProfile,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    int? todayMinutesRead,
    String? selectedFilter,
  }) {
    return BookshelfState(
      books: books ?? this.books,
      habitProfile: habitProfile ?? this.habitProfile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      todayMinutesRead: todayMinutesRead ?? this.todayMinutesRead,
      selectedFilter: selectedFilter ?? this.selectedFilter,
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
    final sessionsResult = await bookRepo.getReadingSessions();

    final now = DateTime.now();
    final sessions = sessionsResult.dataOrNull ?? [];
    int todaySeconds = 0;
    for (final s in sessions) {
      if (s.sessionDate.year == now.year &&
          s.sessionDate.month == now.month &&
          s.sessionDate.day == now.day) {
        todaySeconds += s.durationSeconds;
      }
    }
    final todayMinutes = (todaySeconds / 60).round();

    if (booksResult.isSuccess) {
      state = state.copyWith(
        books: booksResult.dataOrNull ?? [],
        habitProfile: habitResult.dataOrNull,
        todayMinutesRead: todayMinutes,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        todayMinutesRead: todayMinutes,
        errorMessage: booksResult.errorOrNull?.message,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
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

  Future<void> markBookCompleted(BookEntity book) async {
    if (book.id == null) return;
    final bookRepo = _ref.read(bookRepositoryProvider);
    final habitRepo = _ref.read(habitRepositoryProvider);
    await bookRepo.markBookCompleted(book.id!);
    await habitRepo.addEarnedSeal('seal_first_book');
    await habitRepo.addEarnedSeal('seal_completed_${book.id}');
    await loadBooks();
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

