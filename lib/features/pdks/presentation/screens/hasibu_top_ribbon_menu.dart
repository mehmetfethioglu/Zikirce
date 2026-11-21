import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/accounting_models.dart';
import '../../domain/pdks_models.dart';
import '../providers/accounting_providers.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_settings_view.dart';

enum HasibuRibbonCategory {
  islemler('İşlemler', Icons.apps_rounded),
  raporlar('Raporlar', Icons.analytics_outlined),
  parametreler('Parametreler', Icons.tune_rounded),
  magazalar('Mağazalar', Icons.storefront_outlined),
  resmiIslemler('Resmi İşlemler', Icons.gavel_outlined);

  final String label;
  final IconData icon;
  const HasibuRibbonCategory(this.label, this.icon);
}

class _RibbonCmd {
  final String label;
  final IconData icon;
  final Color color;
  final bool isCompact;
  final bool hasDropdown;
  final PreAccountingOperationModule? opModule;
  final HasibuModule? targetModule;
  final int? targetTabIndex;
  final bool isLogout;

  const _RibbonCmd({
    required this.label,
    required this.icon,
    required this.color,
    this.isCompact = false,
    this.hasDropdown = false,
    this.opModule,
    this.targetModule,
    this.targetTabIndex,
    this.isLogout = false,
  });
}

class _RibbonGroup {
  final String title;
  final List<_RibbonCmd> commands;

  const _RibbonGroup(this.title, this.commands);
}

class HasibuAutoCadTopRibbon extends ConsumerStatefulWidget {
  final List<HasibuModule> allowedModules;
  final HasibuModule activeModule;
  final ValueChanged<HasibuModule> onSelectModule;
  final void Function(HasibuModule module, int tabIndex) onNavigateModuleTab;

  const HasibuAutoCadTopRibbon({
    super.key,
    required this.allowedModules,
    required this.activeModule,
    required this.onSelectModule,
    required this.onNavigateModuleTab,
  });

  @override
  ConsumerState<HasibuAutoCadTopRibbon> createState() =>
      _HasibuAutoCadTopRibbonState();
}

class _HasibuAutoCadTopRibbonState
    extends ConsumerState<HasibuAutoCadTopRibbon> {
  HasibuRibbonCategory _selectedCategory = HasibuRibbonCategory.islemler;
  bool _isRibbonExpanded = true;

  @override
  void didUpdateWidget(covariant HasibuAutoCadTopRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeModule != oldWidget.activeModule) {
      _isRibbonExpanded = widget.activeModule == HasibuModule.preAccounting;
    }
  }

  IconData _iconForModule(HasibuModule m) {
    return switch (m) {
      HasibuModule.pdksHr => Icons.fingerprint_rounded,
      HasibuModule.leanProduction => Icons.precision_manufacturing_rounded,
      HasibuModule.preAccounting => Icons.account_balance_wallet_rounded,
      HasibuModule.branchStore => Icons.storefront_rounded,
      HasibuModule.employeePortal => Icons.badge_rounded,
      HasibuModule.systemSettings => Icons.tune_rounded,
    };
  }

  List<_RibbonGroup> _groupsForCategory(HasibuRibbonCategory cat) {
    switch (cat) {
      case HasibuRibbonCategory.islemler:
        return const <_RibbonGroup>[
          _RibbonGroup('Cari İşlemler', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Cari\nTanımları',
              icon: Icons.contact_page_rounded,
              color: Color(0xFF0284C7),
              opModule: PreAccountingOperationModule.cariTanimlari,
            ),
            _RibbonCmd(
              label: 'Kasa\nİşlemleri',
              icon: Icons.point_of_sale_rounded,
              color: Color(0xFF0D9488),
              opModule: PreAccountingOperationModule.kasaIslemleri,
            ),
            _RibbonCmd(
              label: 'Banka\nİşlemleri',
              icon: Icons.account_balance_rounded,
              color: Color(0xFFD97706),
              opModule: PreAccountingOperationModule.bankaIslemleri,
            ),
            _RibbonCmd(
              label: 'Çek\nİşlemleri',
              icon: Icons.request_quote_rounded,
              color: Color(0xFF059669),
              opModule: PreAccountingOperationModule.cekIslemleri,
            ),
            _RibbonCmd(
              label: 'Senet\nİşlemleri',
              icon: Icons.description_rounded,
              color: Color(0xFF4F46E5),
              opModule: PreAccountingOperationModule.senetIslemleri,
            ),
            _RibbonCmd(
              label: 'Dekont\nİşlemleri',
              icon: Icons.receipt_long_rounded,
              color: Color(0xFF7C3AED),
              opModule: PreAccountingOperationModule.dekontIslemleri,
            ),
            _RibbonCmd(
              label: 'Virmanlar',
              icon: Icons.swap_horiz_rounded,
              color: Color(0xFFEA580C),
              hasDropdown: true,
              opModule: PreAccountingOperationModule.virmanlar,
            ),
          ]),
          _RibbonGroup('Fatura', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Siparişler',
              icon: Icons.shopping_bag_rounded,
              color: Color(0xFFE11D48),
              opModule: PreAccountingOperationModule.siparisler,
            ),
            _RibbonCmd(
              label: 'Faturalar',
              icon: Icons.receipt_rounded,
              color: Color(0xFF0284C7),
              hasDropdown: true,
              opModule: PreAccountingOperationModule.faturalar,
            ),
            _RibbonCmd(
              label: 'Dondurma\nSatışlar',
              icon: Icons.icecream_rounded,
              color: Color(0xFFDB2777),
              opModule: PreAccountingOperationModule.dondurmaSatislar,
            ),
          ]),
          _RibbonGroup('Stok İşlemleri', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Stok\nTanımları',
              icon: Icons.inventory_2_rounded,
              color: Color(0xFF2563EB),
              opModule: PreAccountingOperationModule.stokTanimlari,
            ),
            _RibbonCmd(
              label: 'Stok\nFişleri',
              icon: Icons.fact_check_rounded,
              color: Color(0xFF16A34A),
              opModule: PreAccountingOperationModule.stokFisleri,
            ),
            _RibbonCmd(
              label: 'Tepsi ve\nKöşebent İade',
              icon: Icons.layers_rounded,
              color: Color(0xFF0D9488),
              opModule: PreAccountingOperationModule.tepsiKosebentIade,
            ),
            _RibbonCmd(
              label: 'Depo Sevk\nFişleri',
              icon: Icons.local_shipping_rounded,
              color: Color(0xFFD97706),
              opModule: PreAccountingOperationModule.depoSevkFisleri,
            ),
            _RibbonCmd(
              label: 'Üretim\nFişleri',
              icon: Icons.precision_manufacturing_rounded,
              color: Color(0xFFEA580C),
              opModule: PreAccountingOperationModule.uretimFisleri,
            ),
            _RibbonCmd(
              label: 'Üretim Listesi\nve Hammaddeler',
              icon: Icons.schema_rounded,
              color: Color(0xFF0891B2),
              opModule: PreAccountingOperationModule.uretimListesiVeHammaddeler,
            ),
          ]),
          _RibbonGroup('Personel', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Personel Kart',
              icon: Icons.badge_rounded,
              color: Color(0xFF0284C7),
              isCompact: true,
              opModule: PreAccountingOperationModule.personelKart,
            ),
            _RibbonCmd(
              label: 'Puantaj',
              icon: Icons.calendar_month_rounded,
              color: Color(0xFF059669),
              isCompact: true,
              opModule: PreAccountingOperationModule.puantaj,
            ),
            _RibbonCmd(
              label: 'Personel Girişler',
              icon: Icons.payments_rounded,
              color: Color(0xFF7C3AED),
              isCompact: true,
              opModule: PreAccountingOperationModule.personelGirisler,
            ),
          ]),
          _RibbonGroup('Yardımcılar', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Özel Tablolar',
              icon: Icons.table_chart_rounded,
              color: Color(0xFF0D9488),
              isCompact: true,
              opModule: PreAccountingOperationModule.ozelTablolar,
            ),
            _RibbonCmd(
              label: 'Ajanda',
              icon: Icons.event_note_rounded,
              color: Color(0xFF2563EB),
              isCompact: true,
              opModule: PreAccountingOperationModule.ajanda,
            ),
            _RibbonCmd(
              label: 'Ödeme Emirleri',
              icon: Icons.send_time_extension_rounded,
              color: Color(0xFFD97706),
              isCompact: true,
              opModule: PreAccountingOperationModule.odemeEmirleri,
            ),
            _RibbonCmd(
              label: 'Notlar',
              icon: Icons.sticky_note_2_rounded,
              color: Color(0xFFCA8A04),
              isCompact: true,
              opModule: PreAccountingOperationModule.notlar,
            ),
            _RibbonCmd(
              label: 'Kayan Yazı',
              icon: Icons.campaign_rounded,
              color: Color(0xFF16A34A),
              isCompact: true,
              opModule: PreAccountingOperationModule.kayanYazi,
            ),
            _RibbonCmd(
              label: 'Bulut Yedek',
              icon: Icons.cloud_sync_rounded,
              color: Color(0xFF0284C7),
              isCompact: true,
              opModule: PreAccountingOperationModule.donemDevirVeBulutYedek,
            ),
            _RibbonCmd(
              label: 'Çıkış',
              icon: Icons.cancel_rounded,
              color: Color(0xFFDC2626),
              isLogout: true,
            ),
          ]),
        ];

      case HasibuRibbonCategory.raporlar:
        return const <_RibbonGroup>[
          _RibbonGroup('Finans & Defter Raporları', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Gün Sonu &\nNakit Akışı',
              icon: Icons.assessment_rounded,
              color: Color(0xFF0284C7),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 1,
            ),
            _RibbonCmd(
              label: 'Raporlar &\nÖzel Tablo',
              icon: Icons.analytics_rounded,
              color: Color(0xFF0D9488),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 3,
            ),
            _RibbonCmd(
              label: 'Cari, Kasa &\nEmanet Kap',
              icon: Icons.account_balance_wallet_rounded,
              color: Color(0xFFD97706),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 5,
            ),
          ]),
          _RibbonGroup('İK, Puantaj & Üretim Raporları', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Otomatik Puantaj\n& Hakediş',
              icon: Icons.grid_on_rounded,
              color: Color(0xFF059669),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 4,
            ),
            _RibbonCmd(
              label: 'Günlük Yoklama\nBordro Özeti',
              icon: Icons.fact_check_rounded,
              color: Color(0xFF7C3AED),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 6,
            ),
            _RibbonCmd(
              label: '27 İstasyon\nÜretim KPI',
              icon: Icons.leaderboard_rounded,
              color: Color(0xFFEA580C),
              targetModule: HasibuModule.leanProduction,
              targetTabIndex: 1,
            ),
          ]),
        ];

      case HasibuRibbonCategory.parametreler:
        return const <_RibbonGroup>[
          _RibbonGroup('Kurumsal & Cihaz Parametreleri', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Şirket, Şube\n& Cihazlar',
              icon: Icons.business_rounded,
              color: Color(0xFF0284C7),
              targetModule: HasibuModule.systemSettings,
              targetTabIndex: 0,
            ),
            _RibbonCmd(
              label: 'Mesai Saatleri\n& Tolerans',
              icon: Icons.schedule_rounded,
              color: Color(0xFF0D9488),
              targetModule: HasibuModule.systemSettings,
              targetTabIndex: 1,
            ),
            _RibbonCmd(
              label: 'Personel &\nBölüm Yönetimi',
              icon: Icons.manage_accounts_rounded,
              color: Color(0xFF7C3AED),
              targetModule: HasibuModule.systemSettings,
              targetTabIndex: 2,
            ),
            _RibbonCmd(
              label: 'Veri Göç &\nSaaS Lisans',
              icon: Icons.rocket_launch_rounded,
              color: Color(0xFFD97706),
              targetModule: HasibuModule.systemSettings,
              targetTabIndex: 3,
            ),
            _RibbonCmd(
              label: 'Terminal &\nGoogle Bulut',
              icon: Icons.cloud_sync_rounded,
              color: Color(0xFF059669),
              targetModule: HasibuModule.systemSettings,
              targetTabIndex: 4,
            ),
          ]),
        ];

      case HasibuRibbonCategory.magazalar:
        return const <_RibbonGroup>[
          _RibbonGroup('Mağaza POS & Şube Operasyonları', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Dokunmatik POS\n& Terazi',
              icon: Icons.point_of_sale_rounded,
              color: Color(0xFF0284C7),
              targetModule: HasibuModule.branchStore,
              targetTabIndex: 0,
            ),
            _RibbonCmd(
              label: 'Canlı Mağazalar\n& Sevkiyat',
              icon: Icons.storefront_rounded,
              color: Color(0xFF059669),
              targetModule: HasibuModule.branchStore,
              targetTabIndex: 1,
            ),
            _RibbonCmd(
              label: 'Gün Sonu &\nKutu Dara',
              icon: Icons.fact_check_rounded,
              color: Color(0xFFD97706),
              targetModule: HasibuModule.branchStore,
              targetTabIndex: 2,
            ),
            _RibbonCmd(
              label: 'Stok Sayım &\nSarf Gider',
              icon: Icons.inventory_2_rounded,
              color: Color(0xFF7C3AED),
              targetModule: HasibuModule.branchStore,
              targetTabIndex: 3,
            ),
            _RibbonCmd(
              label: '360° Şube\nDenetim',
              icon: Icons.verified_user_rounded,
              color: Color(0xFFE11D48),
              targetModule: HasibuModule.branchStore,
              targetTabIndex: 4,
            ),
          ]),
        ];

      case HasibuRibbonCategory.resmiIslemler:
        return const <_RibbonGroup>[
          _RibbonGroup('Resmi Muhasebe & Mevzuat', <_RibbonCmd>[
            _RibbonCmd(
              label: 'Resmi Alış\nFatura & Reçete',
              icon: Icons.gavel_rounded,
              color: Color(0xFF0284C7),
              opModule: PreAccountingOperationModule.resmiAlisFaturaVeRecete,
            ),
            _RibbonCmd(
              label: 'Sipariş, İrsaliye\n& e-Fatura',
              icon: Icons.receipt_long_rounded,
              color: Color(0xFF059669),
              targetModule: HasibuModule.preAccounting,
              targetTabIndex: 2,
            ),
            _RibbonCmd(
              label: 'Bulgur & Buğday\nÜretim',
              icon: Icons.agriculture_rounded,
              color: Color(0xFFD97706),
              opModule: PreAccountingOperationModule.bulgurVeBugdayUretim,
            ),
            _RibbonCmd(
              label: 'Bayi Sözleşme\n& Bölge Fiyat',
              icon: Icons.handshake_rounded,
              color: Color(0xFF7C3AED),
              opModule: PreAccountingOperationModule.bayiSozlesmeVeBolgeFiyat,
            ),
            _RibbonCmd(
              label: 'İK Talep &\n4857 Md.53 Uyum',
              icon: Icons.policy_rounded,
              color: Color(0xFF0D9488),
              targetModule: HasibuModule.pdksHr,
              targetTabIndex: 4,
            ),
          ]),
        ];
    }
  }

  void _handleCommandTap(_RibbonCmd cmd) {
    if (cmd.isLogout) {
      ref.read(pdksDashboardProvider.notifier).logout();
      return;
    }
    if (cmd.opModule != null) {
      ref
          .read(accountingProvider.notifier)
          .selectOperationModule(cmd.opModule!);
      if (cmd.opModule == PreAccountingOperationModule.personelKart) {
        widget.onNavigateModuleTab(HasibuModule.systemSettings, 2);
      } else if (cmd.opModule == PreAccountingOperationModule.puantaj) {
        widget.onNavigateModuleTab(HasibuModule.preAccounting, 4);
      } else if (cmd.opModule == PreAccountingOperationModule.ozelTablolar) {
        widget.onNavigateModuleTab(HasibuModule.preAccounting, 3);
      } else if (cmd.opModule ==
          PreAccountingOperationModule.donemDevirVeBulutYedek) {
        showGmailDriveSyncDialog(context, ref);
      } else {
        widget.onNavigateModuleTab(HasibuModule.preAccounting, 0);
      }
      return;
    }
    if (cmd.targetModule != null) {
      widget.onNavigateModuleTab(cmd.targetModule!, cmd.targetTabIndex ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final selectedOp = ref.watch(
      accountingProvider.select((s) => s.selectedOperationModule),
    );
    final groups = _groupsForCategory(_selectedCategory);

    final ribbonHeaderBg = pal.isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final ribbonBodyBg = pal.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final groupFooterBg = pal.isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFD8E1EB);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ribbonBodyBg,
        border: Border(
          bottom: BorderSide(color: pal.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SATIR 1 (EN ÜST): Ana Modül Sekmeleri (PDKS & İK satırı İşlemler satırının üstünde)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pal.bg,
              border: Border(
                bottom: BorderSide(color: pal.border.withValues(alpha: 0.6)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in widget.allowedModules.where(
                    (m) => m != HasibuModule.systemSettings,
                  )) ...[
                    _RibbonCoreModuleTab(
                      module: m,
                      isSelected: m == widget.activeModule,
                      icon: _iconForModule(m),
                      pal: pal,
                      onTap: () {
                        setState(() {
                          _isRibbonExpanded = m == HasibuModule.preAccounting;
                        });
                        widget.onSelectModule(m);
                      },
                    ),
                    const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
          // SATIR 2: Üst Şerit Sekme Başlığı + Okunmamış Mesaj
          Container(
            color: ribbonHeaderBg,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              children: [
                // Üst Şerit Kategorileri
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final cat in HasibuRibbonCategory.values) ...[
                          _RibbonCategoryTab(
                            cat: cat,
                            isSelected: _selectedCategory == cat,
                            pal: pal,
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                                _isRibbonExpanded = true;
                              });
                              if (cat == HasibuRibbonCategory.islemler &&
                                  widget.activeModule == HasibuModule.preAccounting) {
                                widget.onNavigateModuleTab(HasibuModule.preAccounting, 0);
                              }
                            },
                          ),
                          const SizedBox(width: 2),
                        ],
                        const SizedBox(width: 6),
                        InkWell(
                          key: const ValueKey('appbar_unread_messages_button'),
                          borderRadius: BorderRadius.circular(5),
                          onTap: () => widget.onNavigateModuleTab(
                            HasibuModule.pdksHr,
                            4,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: pal.card,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 12,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Okunmamış Mesaj Yok',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 14,
                                  color: pal.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // SATIR 3: AutoCAD / DevExpress Grup Bölmeli Büyük & Kompakt Komut Şeridi
          if (_isRibbonExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
              decoration: BoxDecoration(
                color: ribbonBodyBg,
                border: Border(
                  top: BorderSide(color: pal.border.withValues(alpha: 0.7)),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      _RibbonGroupBox(
                        group: groups[i],
                        selectedOp: selectedOp,
                        pal: pal,
                        groupFooterBg: groupFooterBg,
                        isPreAccounting:
                            widget.activeModule == HasibuModule.preAccounting,
                        onCommandTap: _handleCommandTap,
                      ),
                      if (i < groups.length - 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RibbonCategoryTab extends StatelessWidget {
  final HasibuRibbonCategory cat;
  final bool isSelected;
  final HasibuPalette pal;
  final VoidCallback onTap;

  const _RibbonCategoryTab({
    required this.cat,
    required this.isSelected,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? pal.card : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: isSelected ? Border.all(color: pal.border) : null,
        ),
        child: Text(
          cat.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0284C7) : pal.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _RibbonCoreModuleTab extends StatelessWidget {
  final HasibuModule module;
  final bool isSelected;
  final IconData icon;
  final HasibuPalette pal;
  final VoidCallback onTap;

  const _RibbonCoreModuleTab({
    required this.module,
    required this.isSelected,
    required this.icon,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF10B981);
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? accent : pal.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              module.title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? pal.textPrimary : pal.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonLargeButton extends StatelessWidget {
  final _RibbonCmd cmd;
  final bool isSelected;
  final HasibuPalette pal;
  final VoidCallback onTap;

  const _RibbonLargeButton({
    required this.cmd,
    required this.isSelected,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? cmd.color.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: cmd.color.withValues(alpha: 0.45))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: cmd.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: cmd.color.withValues(alpha: 0.35)),
              ),
              child: Icon(cmd.icon, size: 18, color: cmd.color),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cmd.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
                if (cmd.hasDropdown)
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 13,
                    color: pal.textSecondary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonCompactButton extends StatelessWidget {
  final _RibbonCmd cmd;
  final bool isSelected;
  final HasibuPalette pal;
  final VoidCallback onTap;

  const _RibbonCompactButton({
    required this.cmd,
    required this.isSelected,
    required this.pal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          color: isSelected
              ? cmd.color.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cmd.icon, size: 13, color: cmd.color),
            const SizedBox(width: 5),
            Text(
              cmd.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonGroupBox extends StatelessWidget {
  final _RibbonGroup group;
  final PreAccountingOperationModule selectedOp;
  final HasibuPalette pal;
  final Color groupFooterBg;
  final bool isPreAccounting;
  final ValueChanged<_RibbonCmd> onCommandTap;

  const _RibbonGroupBox({
    required this.group,
    required this.selectedOp,
    required this.pal,
    required this.groupFooterBg,
    required this.isPreAccounting,
    required this.onCommandTap,
  });

  @override
  Widget build(BuildContext context) {
    final largeCmds =
        group.commands.where((c) => !c.isCompact && !c.isLogout).toList();
    final compactCmds = group.commands.where((c) => c.isCompact).toList();
    final logoutCmds = group.commands.where((c) => c.isLogout).toList();

    final List<List<_RibbonCmd>> compactColumns = <List<_RibbonCmd>>[];
    for (var i = 0; i < compactCmds.length; i += 3) {
      final end = (i + 3 < compactCmds.length) ? i + 3 : compactCmds.length;
      compactColumns.add(compactCmds.sublist(i, end));
    }

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pal.border),
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 68,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final cmd in largeCmds)
                      _RibbonLargeButton(
                        cmd: cmd,
                        isSelected: cmd.opModule != null &&
                            isPreAccounting &&
                            selectedOp == cmd.opModule,
                        pal: pal,
                        onTap: () => onCommandTap(cmd),
                      ),
                    for (final col in compactColumns)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final cmd in col)
                              _RibbonCompactButton(
                                cmd: cmd,
                                isSelected: cmd.opModule != null &&
                                    isPreAccounting &&
                                    selectedOp == cmd.opModule,
                                pal: pal,
                                onTap: () => onCommandTap(cmd),
                              ),
                          ],
                        ),
                      ),
                    for (final cmd in logoutCmds)
                      _RibbonLargeButton(
                        cmd: cmd,
                        isSelected: cmd.opModule != null &&
                            isPreAccounting &&
                            selectedOp == cmd.opModule,
                        pal: pal,
                        onTap: () => onCommandTap(cmd),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: groupFooterBg,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(5),
                ),
              ),
              child: Text(
                group.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pal.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
