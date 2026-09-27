import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/surah_data_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../providers/ezber_providers.dart';
import '../../../kuran/presentation/screens/mushaf_screen.dart';
import '../../../kuran/presentation/widgets/talim_page_selection_bottom_sheet.dart';
import '../../../kuran/presentation/widgets/talim_selection_bottom_sheet.dart';
import 'interactive_talim_screen.dart';
import 'kelime_takipli_dinleme_screen.dart';

class MemorizationScreen extends ConsumerStatefulWidget {
  const MemorizationScreen({super.key});

  @override
  ConsumerState<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends ConsumerState<MemorizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _manualSelectedPage = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openKelimeTakipliDinleme() async {
    final result = await TalimSelectionBottomSheet.show(
      context,
      modeKey: 'KelimeTakip',
      modeTitle: 'Kelime Takipli Dinleme',
      modeIcon: '🎧',
      modeColor: const Color(0xFF0D9488),
      initialPage: _manualSelectedPage,
      isAudioSyncListening: true,
    );

    if (result != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => KelimeTakipliDinlemeScreen(
            targetType: result.type,
            targetId: result.id,
            startAyah: result.startAyah,
            endAyah: result.endAyah,
            customTitle: result.customTitle,
          ),
        ),
      );
    }
  }

  void _openTalimMode(String modeKey, {int? pageNumber}) async {
    final targetPage = pageNumber ??
        await showModalBottomSheet<int>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TalimPageSelectionBottomSheet(
            modeKey: modeKey,
            modeTitle: _getModeTitle(modeKey),
            modeIcon: _getModeIcon(modeKey),
            modeColor: _getModeColor(modeKey),
            initialPage: _manualSelectedPage,
          ),
        );

    if (targetPage != null && targetPage >= 1 && targetPage <= 604) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => InteractiveTalimScreen(
              modeKey: modeKey,
              pageNumber: targetPage,
            ),
          ),
        );
      }
    }
  }

  String _getModeTitle(String modeKey) {
    switch (modeKey) {
      case 'Yazarak':
      case 'Bulmaca':
        return 'Kelime Bulmaca';
      case 'Bosluk':
        return 'Boşluk Doldurma';
      case 'Baglama':
      case 'Sonraki Ayet':
        return 'Sonraki Ayeti Bulma';
      case 'Talim':
      default:
        return 'Seslendirme & Tilavet';
    }
  }

  String _getModeIcon(String modeKey) {
    switch (modeKey) {
      case 'Yazarak':
      case 'Bulmaca':
        return '🧩';
      case 'Bosluk':
        return '✍️';
      case 'Baglama':
      case 'Sonraki Ayet':
        return '🔗';
      case 'Talim':
      default:
        return '🎙️';
    }
  }

  Color _getModeColor(String modeKey) {
    switch (modeKey) {
      case 'Yazarak':
      case 'Bulmaca':
        return const Color(0xFF10B981);
      case 'Bosluk':
        return const Color(0xFFF59E0B);
      case 'Baglama':
      case 'Sonraki Ayet':
        return const Color(0xFF0284C7);
      case 'Talim':
      default:
        return const Color(0xFFA855F7);
    }
  }

  void _showAddPageDialog(BuildContext context, EzberNotifier notifier) {
    int selectedPage = _manualSelectedPage;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Yeni Ezber Sayfası', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ezber planına eklemek istediğiniz sayfa numarasını seçin:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: selectedPage > 1
                        ? () => setDialogState(() => selectedPage--)
                        : null,
                  ),
                  Text(
                    'Sayfa $selectedPage',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D7D76)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: selectedPage < 604
                        ? () => setDialogState(() => selectedPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7D76),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                notifier.addPageToPlan(selectedPage, null);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sayfa $selectedPage ezber planına eklendi.')),
                );
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDersCetveliDialog(List<MemorizationPlan> plans) {
    final plansMap = {for (var p in plans) p.pageId: p.state};

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2622) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Text('📊 ', style: TextStyle(fontSize: 20)),
              Text('30x20 Ders Cetveli', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: Column(
              children: [
                const Text(
                  '30 Cüz x 20 Sayfa Osmanlı İlerleme Haritası',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 20,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: 600,
                    itemBuilder: (c, idx) {
                      final page = idx + 1;
                      final state = plansMap[page] ?? 0;
                      Color cellColor = isDark ? const Color(0xFF2C3933) : const Color(0xFFE2ECE8);
                      if (state == 1) cellColor = const Color(0xFFEF4444); // Ham
                      if (state == 2) cellColor = const Color(0xFFF59E0B); // Pismis
                      if (state >= 3) cellColor = const Color(0xFF10B981); // Has

                      return Tooltip(
                        message: 'Sayfa $page',
                        child: Container(
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem('Boş', isDark ? const Color(0xFF2C3933) : const Color(0xFFE2ECE8)),
                    _buildLegendItem('Ham', const Color(0xFFEF4444)),
                    _buildLegendItem('Pişmiş', const Color(0xFFF59E0B)),
                    _buildLegendItem('Has', const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pageBg = isDark ? const Color(0xFF121916) : const Color(0xFFF4F8F6);
    final cardBg = isDark ? const Color(0xFF1C2722) : Colors.white;
    final primaryTextColor = isDark ? const Color(0xFFE8DDD0) : const Color(0xFF1E2B27);
    final secondaryTextColor = isDark ? const Color(0xFFA89888) : const Color(0xFF506861);
    final accentColor = isDark ? const Color(0xFF3EA388) : const Color(0xFF2D7D76);
    final borderStroke = isDark ? const Color(0xFF2C3C35) : const Color(0xFFDCE7E3);

    final plansAsync = ref.watch(memorizationPlansStreamProvider);
    final ezberNotifier = ref.read(ezberNotifierProvider);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hafızlık ve Talim Merkezi',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: accentColor, size: 28),
            tooltip: 'Ezber Sayfası Ekle',
            onPressed: () => _showAddPageDialog(context, ezberNotifier),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: secondaryTextColor,
          indicatorColor: accentColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          tabs: const [
            Tab(text: 'Serbest Okuma'),
            Tab(text: 'SM-2 Aralıklı Tekrar'),
            Tab(text: 'Osmanlı Hafızlık & Talim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ------------------------------------------
          // TAB 1: SERBEST OKUMA
          // ------------------------------------------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Cüzler ve Hızlı Gezinim',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 30,
                itemBuilder: (context, idx) {
                  final juzNo = idx + 1;
                  final startPage = SurahDataProvider.getJuzStartPage(juzNo);
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MushafScreen(initialPage: startPage)),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderStroke),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$juzNo.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: accentColor)),
                          Text('Cüz', style: TextStyle(fontSize: 9.5, color: secondaryTextColor)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // ------------------------------------------
          // TAB 2: SM-2 ARALIKLI TEKRAR
          // ------------------------------------------
          plansAsync.when(
            data: (plans) {
              if (plans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_rounded, size: 56, color: accentColor),
                      const SizedBox(height: 14),
                      Text(
                        'Henüz ezber planı eklenmedi.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aralıklı tekrar algoritması için sayfa ekleyin.',
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Sayfa Ekle'),
                        onPressed: () => _showAddPageDialog(context, ezberNotifier),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final plan = plans[idx];
                  final isDue = plan.scheduledReviewDate.isBefore(DateTime.now().add(const Duration(hours: 1)));

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDue ? const Color(0xFFEF4444) : borderStroke,
                        width: isDue ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Page Badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDue ? const Color(0xFFEF4444).withOpacity(0.15) : accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${plan.pageId}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDue ? const Color(0xFFEF4444) : accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sayfa ${plan.pageId}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDue ? '⚠️ Tekrar Vakti Geldi!' : 'Aralık: ${plan.intervalDays} Gün · Tekrar: ${plan.timesReviewed}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDue ? const Color(0xFFEF4444) : secondaryTextColor,
                                  fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Drill Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDue ? const Color(0xFFEF4444) : accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openTalimMode('Talim', pageNumber: plan.pageId),
                          child: const Text('Çalış', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Hata: $err')),
          ),

          // ------------------------------------------
          // TAB 3: OSMANLI USULÜ HAFIZLIK & TALİM MERKEZİ
          // ------------------------------------------
          plansAsync.when(
            data: (plans) {
              final hamCount = plans.where((p) => p.state == 1).length;
              final pismisCount = plans.where((p) => p.state == 2).length;
              final hasCount = plans.where((p) => p.state >= 3).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // 1. Stats Summary Pills (Ham, Pişmiş, Has)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatPill(
                          label: '🔴 Ham',
                          count: hamCount,
                          color: const Color(0xFFD32F2F),
                          bg: isDark ? const Color(0xFF422222) : const Color(0xFFFFEBEE),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatPill(
                          label: '🟡 Pişmiş',
                          count: pismisCount,
                          color: const Color(0xFFD97706),
                          bg: isDark ? const Color(0xFF423E22) : const Color(0xFFFFFDE7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatPill(
                          label: '🟢 Has',
                          count: hasCount,
                          color: const Color(0xFF2E7D32),
                          bg: isDark ? const Color(0xFF224222) : const Color(0xFFE8F5E9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Müderris Tavsiyesi & Unvan Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF33291F) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Unvanınız: Taleb-i Ulûm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF241E18) : const Color(0xFFFFF8E7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🛡️ Asgarî Vird',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB25E00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '“Rahleyi kur, zihnini pak eyle Hâfız namzedi.”',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: primaryTextColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Bugünün Üçlü Osmanlı Vazifeleri
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugünün Osmanlı Usulü Dersleri',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Ham Ders
                        _buildVazifeRow(
                          iconEmoji: '🔴',
                          title: 'Yeni Ders (Ham)',
                          subtitle: 'Sayfa $_manualSelectedPage',
                          btnText: 'Dersi Çalış',
                          btnColor: const Color(0xFF10B981),
                          onTap: () => _openTalimMode('Talim', pageNumber: _manualSelectedPage),
                          primaryText: primaryTextColor,
                          secondaryText: secondaryTextColor,
                        ),
                        Divider(height: 20, color: borderStroke),

                        // Pişmiş Tekrar
                        _buildVazifeRow(
                          iconEmoji: '🟡',
                          title: 'Yakın Tekrar (Pişmiş)',
                          subtitle: 'Son 5 Sayfa',
                          btnText: 'Tekrar Et',
                          btnColor: const Color(0xFFF59E0B),
                          onTap: () => _openTalimMode('Bosluk', pageNumber: (_manualSelectedPage > 1 ? _manualSelectedPage - 1 : 1)),
                          primaryText: primaryTextColor,
                          secondaryText: secondaryTextColor,
                        ),
                        Divider(height: 20, color: borderStroke),

                        // Has Tekrar
                        _buildVazifeRow(
                          iconEmoji: '🟢',
                          title: 'Uzak Tekrar (Haslar)',
                          subtitle: 'Cüz Virdi',
                          btnText: 'Muhafaza Et',
                          btnColor: const Color(0xFF0284C7),
                          onTap: () => _openTalimMode('Baglama', pageNumber: 582),
                          primaryText: primaryTextColor,
                          secondaryText: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Gelişmiş Talim Modları (4 Oyunlaştırma Kartı)
                  Text(
                    'Hafızlık ve Talim Çalışmaları',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Card 0: Kelime Takipli Dinleme
                      _buildTalimGridCard(
                        iconEmoji: '🎧',
                        title: 'Kelime Takipli Dinleme',
                        desc: 'Sayfa, Sûre, Cüz, Aşr Dinle',
                        color: const Color(0xFF0D9488),
                        cardBg: cardBg,
                        borderStroke: borderStroke,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        onTap: () => _openKelimeTakipliDinleme(),
                      ),

                      // Card 1: Kelime Bulmaca
                      _buildTalimGridCard(
                        iconEmoji: '🧩',
                        title: 'Kelime Bulmaca',
                        desc: 'Dizilim & Sıralama',
                        color: const Color(0xFF10B981),
                        cardBg: cardBg,
                        borderStroke: borderStroke,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        onTap: () => _openTalimMode('Yazarak'),
                      ),

                      // Card 2: Boşluk Doldurma
                      _buildTalimGridCard(
                        iconEmoji: '✍️',
                        title: 'Boşluk Doldurma',
                        desc: 'Dikkat & Hafıza',
                        color: const Color(0xFFF59E0B),
                        cardBg: cardBg,
                        borderStroke: borderStroke,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        onTap: () => _openTalimMode('Bosluk'),
                      ),

                      // Card 3: Sonraki Ayet
                      _buildTalimGridCard(
                        iconEmoji: '🔗',
                        title: 'Sonraki Ayeti Bulma',
                        desc: 'Ayet Sonu & Ulama',
                        color: const Color(0xFF0284C7),
                        cardBg: cardBg,
                        borderStroke: borderStroke,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        onTap: () => _openTalimMode('Baglama'),
                      ),

                      // Card 4: Seslendirme & Tilavet
                      _buildTalimGridCard(
                        iconEmoji: '🎙️',
                        title: 'Seslendirme & Tilavet',
                        desc: 'Dinle & Tekrar Et',
                        color: const Color(0xFFA855F7),
                        cardBg: cardBg,
                        borderStroke: borderStroke,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        onTap: () => _openTalimMode('Talim'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. 30x20 Ders Cetveli Butonu
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF004D40) : const Color(0xFFE0F2F1),
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text(
                      '📊 30x20 Geleneksel Ders Cetveli (Grid Harita)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () => _showDersCetveliDialog(plans),
                  ),
                  const SizedBox(height: 16),

                  // 6. Serbest Sayfa Başlatma Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderStroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serbest Sayfa Başlatma',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _manualSelectedPage > 1
                                  ? () => setState(() => _manualSelectedPage--)
                                  : null,
                            ),
                            Text(
                              'Sayfa $_manualSelectedPage',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _manualSelectedPage < 604
                                  ? () => setState(() => _manualSelectedPage++)
                                  : null,
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accentColor,
                            inactiveTrackColor: accentColor.withOpacity(0.2),
                            thumbColor: accentColor,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _manualSelectedPage.toDouble(),
                            min: 1,
                            max: 604,
                            onChanged: (val) => setState(() => _manualSelectedPage = val.round()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          onPressed: () => _openTalimMode('Talim', pageNumber: _manualSelectedPage),
                          child: Text(
                            '🕌 Sayfa $_manualSelectedPage İçin Talim Başlat',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Hata: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String label,
    required int count,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildVazifeRow({
    required String iconEmoji,
    required String title,
    required String subtitle,
    required String btnText,
    required Color btnColor,
    required VoidCallback onTap,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Row(
      children: [
        Text(iconEmoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: primaryText)),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: secondaryText)),
            ],
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onTap,
          child: Text(btnText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTalimGridCard({
    required String iconEmoji,
    required String title,
    required String desc,
    required Color color,
    required Color cardBg,
    required Color borderStroke,
    required Color primaryText,
    required Color secondaryText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderStroke),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(iconEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
