import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dictionary_service.dart';

class DictionarySheet extends StatefulWidget {
  final String initialWord;
  final DictionaryEntry? entry;

  const DictionarySheet({
    super.key,
    this.initialWord = 'tahrir',
    this.entry,
  });

  static void show(BuildContext context, [String word = 'tahrir']) {
    final service = DictionaryService();
    final initialEntry = service.lookup(word);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DictionarySheet(
        initialWord: word,
        entry: initialEntry,
      ),
    );
  }

  @override
  State<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<DictionarySheet> {
  final DictionaryService _service = DictionaryService();
  late final TextEditingController _searchController;
  late DictionaryEntry _currentEntry;
  late List<DictionaryEntry> _relatedEntries;
  List<DictionaryEntry> _searchResults = const [];
  bool _isSearchingList = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry ?? _service.lookup(widget.initialWord);
    _relatedEntries = _service.getRelatedEntries(_currentEntry.word, limit: 5);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectWord(String word) {
    final entry = _service.lookup(word);
    setState(() {
      _currentEntry = entry;
      _relatedEntries = _service.getRelatedEntries(entry.word, limit: 5);
      _isSearchingList = false;
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearchingList = false;
        _searchResults = const [];
      });
      return;
    }

    final results = _service.search(trimmed);
    setState(() {
      _isSearchingList = true;
      _searchResults = results;
      if (results.isNotEmpty) {
        _currentEntry = results.first;
        _relatedEntries = _service.getRelatedEntries(_currentEntry.word, limit: 5);
      } else {
        _currentEntry = _service.lookup(trimmed);
        _relatedEntries = _service.getRelatedEntries(trimmed, limit: 5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Başlık
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tahrir Etimolojik & Klasik Lügat',
                    style: GoogleFonts.literata(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lügat Arama Çubuğu
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _selectWord(val.trim());
                  }
                },
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Klasik Türkçe, Osmanlıca veya felsefi kavram ara...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
              ),

              // Çok kelimeli seçim yapılmışsa her kelimeye tek tıkla geçiş çipleri
              if (!_isSearchingList)
                Builder(
                  builder: (context) {
                    final tokens = DictionaryService.extractWordsFromSelection(
                      widget.initialWord,
                    );
                    if (tokens.length <= 1) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seçimdeki Kelimeler:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tokens.take(8).map((token) {
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  token,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => _selectWord(token),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Anlık Arama Önerileri
              if (_isSearchingList && _searchResults.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _searchResults.take(8).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          item.word,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _selectWord(item.word),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Kelime Başlığı + Köken & Sözcük Türü Rozetleri
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    _currentEntry.word,
                    style: GoogleFonts.literata(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentEntry.origin,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _currentEntry.partOfSpeech,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Detaylı Anlam
              Text(
                _currentEntry.meaning,
                style: GoogleFonts.literata(
                  fontSize: 15,
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              // Edebi Beyit / Cümle Örneği Kartı
              if (_currentEntry.example != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '❝',
                        style: GoogleFonts.literata(
                          fontSize: 22,
                          height: 1.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentEntry.example!,
                          style: GoogleFonts.literata(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // İlişkili Lügat Maddeleri
              if (_relatedEntries.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'İlişkili Lügat Maddeleri',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _relatedEntries.map((rel) {
                    return ActionChip(
                      avatar: Icon(
                        Icons.bookmark_border_rounded,
                        size: 15,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        rel.word,
                        style: GoogleFonts.literata(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _selectWord(rel.word),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
