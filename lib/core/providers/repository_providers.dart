import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/database_helper.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../data/repositories/highlight_repository_impl.dart';
import '../../data/repositories/habit_repository_impl.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/highlight_repository.dart';
import '../../domain/repositories/habit_repository.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return BookRepositoryImpl(dbHelper: dbHelper);
});

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return HighlightRepositoryImpl(dbHelper: dbHelper);
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return HabitRepositoryImpl(dbHelper: dbHelper);
});

/// Notlar veya Alıntı Kartları kaydedildiğinde Notlar ekranının anında güncellenmesini sağlayan sayaç.
final highlightsRevisionProvider = StateProvider<int>((ref) => 0);

