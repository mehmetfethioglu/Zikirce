import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../monetization/domain/subscription_service.dart';
import '../domain/bio_rpg_models.dart';
import '../domain/bio_rpg_service.dart';
import 'widgets/pixar_3d_renderer.dart';

class BioArenaScreen extends StatefulWidget {
  const BioArenaScreen({super.key});

  @override
  State<BioArenaScreen> createState() => _BioArenaScreenState();
}

class _BioArenaScreenState extends State<BioArenaScreen> {
  bool _isGuardianAttacking = false;
  bool _isGuardianShielding = false;
  bool _isBossHit = false;
  String _combatLog = '⚔️ Barkoddan yakalanan Toksik Boss\'a karşı hamleni seç! (Karakterleri 3D çevirmek için parmağınla sürükle)';
  int? _lastDamagePop;

  Future<void> _performMove(String bossId, String moveType) async {
    setState(() {
      _isGuardianAttacking = moveType != 'willpower_shield';
      _isGuardianShielding = moveType == 'willpower_shield';
      _isBossHit = true;
    });

    final result = await BioRpgService.instance.executeDuelTurn(
      bossId: bossId,
      moveType: moveType,
    );

    if (!mounted) return;
    setState(() {
      _combatLog = result.combatLog;
      _lastDamagePop = result.playerDamageDealt;
    });

    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() {
      _isGuardianAttacking = false;
      _isGuardianShielding = false;
      _isBossHit = false;
    });
  }

  Future<void> _watchAdForDoubleArenaBonus() async {
    final bool shown = await SubscriptionService.instance.showRewardedAd(
      onRewardGranted: () {
        BioRpgService.instance.grantRewardedAdBonus(crystals: 60, energy: 4);
      },
    );
    if (!shown) {
      // Offline / Test fallback grants bonus directly so gameplay never stalls
      await BioRpgService.instance.grantRewardedAdBonus(crystals: 60, energy: 4);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 +60 Biyo-Kristal ve +4 Biyo-Enerji Şarjı hesabına yüklendi!'),
        backgroundColor: AppColors.primaryEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalOrganicScoreState>(
      valueListenable: BioRpgService.instance,
      builder: (context, state, _) {
        final BioCharacter guardian = state.activeGuardian;
        final List<ToxicBoss> activeBosses = state.activeBosses;
        final ToxicBoss? currentBoss = activeBosses.isNotEmpty ? activeBosses.first : null;
        final bool isSuperEffective = currentBoss != null &&
            BioRpgService.instance.isElementSuperEffective(guardian.element, currentBoss.element);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arena Header & Elemental Matchup Banner
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚔️ 3D BIO-ARENA & DÜELLO',
                          style: TextStyle(
                            color: AppColors.toxicPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Katkı Canavarlarına Karşı Muhafızın',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSuperEffective)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryEmerald),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: AppColors.primaryEmerald, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '2x Element Üstünlüğü!',
                            style: TextStyle(
                              color: AppColors.primaryEmerald,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // 3D PIXAR BATTLE STAGE
              if (currentBoss != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0F172A),
                        currentBoss.primaryColor.withValues(alpha: 0.25),
                        guardian.primaryColor.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: currentBoss.primaryColor.withValues(alpha: 0.55), width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: currentBoss.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Boss Source Product Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_2_rounded, color: AppColors.cautionGold, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kaynak Barkod: ${currentBoss.sourceProductName} • ${currentBoss.chemicalCode}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (currentBoss.willpowerBonusApplied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryEmerald.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '🛡️ İrade Kalkanı (-%50 HP)',
                                  style: TextStyle(
                                    color: AppColors.primaryEmerald,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Side-by-side 3D Pixar Combatants
                      Row(
                        children: [
                          // Player Guardian Column
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${guardian.name} (Sv.${guardian.level})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: guardian.hpRatio,
                                    minHeight: 8,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(guardian.primaryColor),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'HP: ${guardian.currentHp}/${guardian.maxHp} • ATK: ${guardian.attack}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                ),
                                const SizedBox(height: 8),
                                Pixar3DGuardianStage(
                                  guardian: guardian,
                                  size: 135,
                                  isAttacking: _isGuardianAttacking,
                                  isShielding: _isGuardianShielding,
                                ),
                              ],
                            ),
                          ),

                          // VS Badge & Damage Pop
                          Column(
                            children: [
                              if (_lastDamagePop != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerRed,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '-$_lastDamagePop',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Text(
                                  'VS',
                                  style: TextStyle(
                                    color: AppColors.cautionGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Toxic Boss Column
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${currentBoss.name} (Sv.${currentBoss.level})',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: currentBoss.hpRatio,
                                    minHeight: 8,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(currentBoss.secondaryColor),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'HP: ${currentBoss.currentHp}/${currentBoss.maxHp}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                ),
                                const SizedBox(height: 8),
                                Pixar3DBossStage(
                                  boss: currentBoss,
                                  size: 135,
                                  isHit: _isBossHit,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _combatLog,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3 Combat Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _performMove(currentBoss.id, 'strike'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: guardian.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.flash_on_rounded, size: 17),
                              label: const Text(
                                'Biyo-Darbe',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _performMove(currentBoss.id, 'bio_burst'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.toxicPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                              label: const Text(
                                'Süper Patlama',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _performMove(currentBoss.id, 'willpower_shield'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryMint,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.shield_rounded, size: 17),
                              label: const Text(
                                '+HP Kalkan',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                // All Bosses Defeated Celebration Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.primaryEmerald, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Pixar3DGuardianStage(guardian: guardian, size: 140),
                      const SizedBox(height: 12),
                      Text(
                        '🏆 Arena Temizlendi! Tüm Toksik Boss\'ları Yendin!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimaryColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Yeni katkı canavarları yakalamak için markette barkod okut veya antrenman Boss\'larını çağır!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.textSecondaryColor, fontSize: 12.5),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => BioRpgService.instance.spawnPracticeBossIfEmpty(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Yeni Toksik Boss Dalgası Çağır'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Rewarded Ad 2x Loot Chest Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cautionGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cautionGold.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.cautionGold, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎁 2x Biyo-Kristal & Arena Enerji Sandığı',
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            'Kısa ödüllü destek videosuyla +60 Kristal ve +4 Enerji kazan.',
                            style: TextStyle(color: context.textSecondaryColor, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _watchAdForDoubleArenaBonus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cautionGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '+60 💎 Al',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // BIO-DEX: 3D PIXAR GUARDIANS COLLECTION
              Text(
                '🧬 BIO-DEX: 3D BİYO-MUHAFIZ KOLEKSİYONU (${state.guardians.where((g) => g.isUnlocked).length}/${state.guardians.length})',
                style: TextStyle(
                  color: context.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sağlıklı barkodlar tarayarak veya Biyo-Kristal ile yeni 3D Pixar Muhafızları uyandır!',
                style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.guardians.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.76,
                ),
                itemBuilder: (context, index) {
                  final item = state.guardians[index];
                  final bool isSelected = item.id == guardian.id;

                  return GestureDetector(
                    onTap: () async {
                      if (item.isUnlocked) {
                        await BioRpgService.instance.selectGuardian(item.id);
                      } else {
                        final ok = await BioRpgService.instance.unlockGuardianWithCrystals(item.id, 120);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? '🎉 ${item.name} uyandırıldı ve aktif Muhafızın olarak seçildi!'
                                  : '🔒 ${item.name} kilidini açmak için 120 Biyo-Kristal (💎) veya OrganicPass gerekli!',
                            ),
                            backgroundColor: ok ? AppColors.primaryEmerald : AppColors.cautionGold,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? item.primaryColor
                              : context.cardBorderColor,
                          width: isSelected ? 2.2 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.primaryColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Sv.${item.level}',
                                  style: TextStyle(
                                    color: item.primaryColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                item.isUnlocked
                                    ? (isSelected ? Icons.check_circle_rounded : Icons.lock_open_rounded)
                                    : Icons.lock_rounded,
                                color: item.isUnlocked ? item.primaryColor : context.textSecondaryColor,
                                size: 17,
                              ),
                            ],
                          ),
                          Expanded(
                            child: Opacity(
                              opacity: item.isUnlocked ? 1.0 : 0.55,
                              child: Pixar3DGuardianStage(
                                guardian: item,
                                size: 95,
                              ),
                            ),
                          ),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.textSecondaryColor, fontSize: 10.5),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: item.isUnlocked
                                  ? (isSelected
                                      ? item.primaryColor
                                      : item.primaryColor.withValues(alpha: 0.15))
                                  : AppColors.toxicPurple.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.isUnlocked
                                  ? (isSelected ? '⚡ Aktif Muhafız' : 'Seç')
                                  : '🔓 120 💎 Aç',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected ? Colors.white : context.textPrimaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
