import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/widgets/tv_focusable.dart';
import '../../providers/prayer_providers.dart';

class CitySelectionSheet extends ConsumerStatefulWidget {
  const CitySelectionSheet({super.key});

  @override
  ConsumerState<CitySelectionSheet> createState() => _CitySelectionSheetState();
}

class _CitySelectionSheetState extends ConsumerState<CitySelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _filteredCities = PrayerTimesService.turkishCities;

  static const List<String> _quickPopularCities = <String>[
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Konya',
    'Antalya',
    'Adana',
    'Gaziantep',
    'Kayseri',
    'Şanlıurfa',
    'Diyarbakır',
    'Samsun',
    'Trabzon',
    'Erzurum',
  ];

  @override
  void initState() {
    super.initState();
    _filteredCities = List.from(PrayerTimesService.turkishCities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterCities(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredCities = List.from(PrayerTimesService.turkishCities);
      } else {
        final q = query.toLowerCase().trim();
        _filteredCities = PrayerTimesService.turkishCities
            .where((city) => city.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _selectCityAndClose(String city) {
    ref.read(selectedCityProvider.notifier).setCity(city);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentCity = ref.watch(selectedCityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWideScreen = MediaQuery.of(context).size.width >= 720;

    return Container(
      height: MediaQuery.of(context).size.height * (isWideScreen ? 0.86 : 0.78),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.secondaryTextAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title & Count + Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 Şehir Seçin',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Türkiye Geneli 81 İl • Kumanda Ok Tuşları + OK ile Seçin',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredCities.length} İl',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TvFocusable(
                        borderRadius: 12,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.pageBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.borderStroke),
                          ),
                          child: Text(
                            '✕ Kapat',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hızlı Büyük Şehirler Çipleri (Kumanda ile 1 Tıkta Seçim)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _quickPopularCities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final popCity = _quickPopularCities[index];
                  final isSelected = popCity.toLowerCase() == currentCity.toLowerCase();
                  return TvFocusable(
                    autofocus: index == 0,
                    borderRadius: 999,
                    onPressed: () => _selectCityAndClose(popCity),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent
                            : colors.pageBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.borderStroke,
                        ),
                      ),
                      child: Text(
                        isSelected ? '✓ $popCity' : popCity,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : colors.primaryText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.pageBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.borderStroke),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _filterCities,
                        style: TextStyle(fontSize: 14, color: colors.primaryText),
                        decoration: InputDecoration(
                          hintText: 'Şehir adı arayın...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.secondaryTextAlt.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.secondaryTextAlt,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: colors.secondaryTextAlt,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterCities('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  if (isWideScreen) ...[
                    const SizedBox(width: 10),
                    TvFocusable(
                      borderRadius: 14,
                      onPressed: () => _searchFocusNode.requestFocus(),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.accent.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          '⌨️ İsimle Ara',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Cities List / TV Focusable Grid
            Expanded(
              child: _filteredCities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: colors.secondaryTextAlt.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aradığınız şehir bulunamadı',
                            style: TextStyle(
                              color: colors.secondaryTextAlt,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : isWideScreen
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 3.4,
                          ),
                          itemCount: _filteredCities.length,
                          itemBuilder: (context, idx) {
                            final city = _filteredCities[idx];
                            final isSelected = city.toLowerCase() == currentCity.toLowerCase();
                            return TvFocusable(
                              borderRadius: 14,
                              onPressed: () => _selectCityAndClose(city),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accent.withValues(alpha: 0.18)
                                      : colors.pageBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? colors.accent : colors.borderStroke,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.location_city_rounded,
                                      size: 18,
                                      color: isSelected ? colors.accent : colors.secondaryTextAlt,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        city,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? colors.accent : colors.primaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredCities.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: colors.borderStroke.withValues(alpha: 0.4),
                          ),
                          itemBuilder: (context, idx) {
                            final city = _filteredCities[idx];
                            final isSelected = city.toLowerCase() == currentCity.toLowerCase();

                            return TvFocusable(
                              borderRadius: 12,
                              onPressed: () => _selectCityAndClose(city),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.accent.withValues(alpha: 0.15)
                                            : colors.pageBackground,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.location_city_rounded,
                                        size: 18,
                                        color: isSelected ? colors.accent : colors.secondaryTextAlt,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        city,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? colors.accent : colors.primaryText,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.accent,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 14),
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
