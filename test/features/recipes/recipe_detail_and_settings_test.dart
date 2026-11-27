import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/core/theme/app_theme.dart';
import 'package:organicscore/features/kiler/presentation/kilerce_hub_screen.dart';
import 'package:organicscore/features/monetization/presentation/paywall_screen.dart';
import 'package:organicscore/features/recipes/data/kilerce_recipe_catalog.dart';
import 'package:organicscore/features/recipes/domain/recipe_models.dart';
import 'package:organicscore/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:organicscore/features/recipes/presentation/widgets/kitchen_checkin_sheets.dart';
import 'package:organicscore/features/recipes/presentation/widgets/recipe_match_card.dart';
import 'package:organicscore/features/recipes/presentation/widgets/weekly_meal_planner_view.dart';
import 'package:organicscore/features/settings/presentation/kilerce_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  group('Full-Page Recipe Detail, Settings & Paywall Tests', () {
    testWidgets(
      'RecipeDetailScreen renders full-page SliverAppBar, scales portions, toggles step completion without overflow on 360x780',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final recipe = findMasterRecipeById('menemen')!;
        final match = EvaluatedRecipeMatch(
          recipe: recipe,
          matchedRequiredTags: const ['yumurta', 'domates'],
          missingRequiredTags: const ['biber'],
          matchedOptionalTags: const ['zeytinyagi'],
          expiringIngredientsUsed: const [],
          longWaitingIngredientsUsed: const [],
          combinedHealthScore: 95,
          profileWarnings: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => RecipeDetailScreen.open(
                      ctx,
                      match,
                      onToggleFavorite: () {},
                      onAddToMealPlan: () {},
                    ),
                    child: const Text('Open Recipe'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Recipe'));
        await tester.pumpAndSettle();

        expect(find.byType(RecipeDetailScreen), findsOneWidget);
        expect(find.byType(SliverAppBar), findsOneWidget);
        expect(find.text('Klasik Köy Menemeni'), findsOneWidget);
        expect(find.text('Evde Var'), findsNothing);

        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Malzemeler (2 Porsiyon)'),
          150,
          scrollable: scrollable,
        );
        expect(find.text('Malzemeler (2 Porsiyon)'), findsOneWidget);

        // Scroll back to portion selector and scale from 2 to 4
        await tester.scrollUntilVisible(
          find.text('4'),
          -150,
          scrollable: scrollable,
        );
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        expect(find.text('Malzemeler (4 Porsiyon)'), findsOneWidget);
        expect(find.text('Pişirdim (4 Porsiyon)'), findsOneWidget);

        // Scroll to first step and toggle completion
        final firstStep = find.text(recipe.steps.first);
        await tester.scrollUntilVisible(
          firstStep,
          200,
          scrollable: scrollable,
        );
        await tester.tap(firstStep);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KilerceSettingsScreen renders sections and opens full-page PaywallScreen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const KilerceSettingsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;

        expect(find.text('Ayarlar'), findsOneWidget);
        expect(find.text('Kilerce Pro & Reklam Ödülleri'), findsOneWidget);
        expect(find.text('Pro Planlar & Reklam Ödülleri'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Uygulama Teması'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('Uygulama Teması'), findsOneWidget);
        expect(find.text('Sabah Menü & Eksik Malzeme'), findsOneWidget);
        expect(find.text('SKT Hatırlatma Bildirimleri'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Tarif Fotoğrafı Gönder'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('Tarif Fotoğrafı Gönder'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Tam Yedek Al (JSON)'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('Tam Yedek Al (JSON)'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Kullanım Kılavuzu'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Gizlilik Politikası & Kullanım Koşulları'),
          200,
          scrollable: scrollable,
        );
        expect(
          find.text('Gizlilik Politikası & Kullanım Koşulları'),
          findsOneWidget,
        );

        // Scroll back to top and open full-page PaywallScreen
        await tester.scrollUntilVisible(
          find.text('Pro Planlar & Reklam Ödülleri'),
          -300,
          scrollable: scrollable,
        );
        await tester.ensureVisible(find.text('Pro Planlar & Reklam Ödülleri'));
        await tester.tap(find.text('Pro Planlar & Reklam Ödülleri'));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.text('23.933+ Tarifin Tamamını Açın'), findsOneWidget);
        expect(find.textContaining('3 Reklam İzle'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KilerceTopHudBar removes score/product/blacklist pills, shows profile avatar menu, and opens KilerceSettingsScreen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SafeArea(
                child: KilerceTopHudBar(
                  currentIndex: 0,
                  onTabSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Skor'), findsNothing);
        expect(find.byIcon(Icons.gpp_maybe_rounded), findsNothing);
        expect(find.byIcon(Icons.settings_rounded), findsNothing);

        final profileAvatar = find.byKey(const Key('top_bar_profile_avatar'));
        expect(profileAvatar, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(profileAvatar);
        await tester.pumpAndSettle();

        expect(find.text('Hesabım & Profil'), findsOneWidget);
        expect(find.text('Bakanlık Kara Listesi'), findsOneWidget);
        expect(find.text('Ayarlar'), findsOneWidget);
        expect(find.text('Kullanım Kılavuzu'), findsOneWidget);
        expect(find.text('Tarif Fotoğrafı Gönder'), findsOneWidget);

        await tester.tap(find.text('Ayarlar'));
        await tester.pumpAndSettle();

        expect(find.byType(KilerceSettingsScreen), findsOneWidget);
        expect(find.text('Ayarlar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RecipeMatchCard renders full-bleed minimal card without verbose badges on 360px width',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final soup = findMasterRecipeById('suzme_mercimek_corbasi')!;
        final readyMatch = EvaluatedRecipeMatch(
          recipe: soup,
          matchedRequiredTags: soup.requiredTags,
          missingRequiredTags: const [],
          matchedOptionalTags: const [],
          expiringIngredientsUsed: const [],
          longWaitingIngredientsUsed: const [],
          combinedHealthScore: 95,
          profileWarnings: const [],
        );

        bool tapped = false;
        bool addedToPlan = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: RecipeMatchCard(
                  match: readyMatch,
                  onTap: () => tapped = true,
                  onToggleFavorite: () {},
                  onQuickAddToPlan: () => addedToPlan = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(soup.title), findsOneWidget);
        expect(find.text('95'), findsOneWidget);
        expect(find.text('25 dk • 210 kcal'), findsOneWidget);
        expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byTooltip('Takvime Ekle'), findsOneWidget);

        // Ensure cluttered text badges are gone
        expect(find.text('Kilerde Hazır'), findsNothing);
        expect(find.text('Takvime Ekle'), findsNothing);
        expect(find.text('Skor 95'), findsNothing);
        expect(find.text('Çorba'), findsNothing);

        await tester.tap(find.byTooltip('Takvime Ekle'));
        await tester.pump();
        expect(addedToPlan, isTrue);
        expect(tapped, isFalse);

        await tester.tap(find.text(soup.title));
        await tester.pump();
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'WeeklyMealPlannerView renders full-bleed minimal meal cards and floating assistant bubble on 360x780',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final soup = findMasterRecipeById('suzme_mercimek_corbasi')!;
        final monday = MealDateUtils.startOfWeekMonday(DateTime(2026, 11, 23));
        final mondayIso = MealDateUtils.toIsoDate(monday);
        final plannedEntry = MealPlanEntry(
          id: 1,
          planDate: mondayIso,
          mealSlot: MealSlot.soupStarter,
          recipeId: soup.id,
          servings: 2,
          isCooked: false,
          addedAt: 1,
        );

        final prompts = [
          KitchenDailyPrompt(
            id: 'missing_1',
            type: KitchenPromptType.todayMissingIngredients,
            planDate: mondayIso,
            mealSlot: MealSlot.soupStarter,
            title: '${soup.title} eksik malzemeleri',
            subtitle: 'Alışverişe ekleyin.',
            recipe: soup,
            missingTags: const ['limon'],
          ),
          KitchenDailyPrompt(
            id: 'cook_1',
            type: KitchenPromptType.plannedMealCookCheck,
            planDate: mondayIso,
            mealSlot: MealSlot.mainCourse,
            title: '${soup.title} pişirildi mi?',
            subtitle: 'Kiler stoklarınız güncellensin.',
            recipe: soup,
            plannedEntry: plannedEntry,
          ),
        ];

        final state = MealModuleState(
          currentWeekMondayIso: mondayIso,
          selectedDateIso: mondayIso,
          weekEntries: [plannedEntry],
          recipeById: {soup.id: soup},
          activePrompts: prompts,
        );

        int openCount = 0;
        int cookCount = 0;
        int removeCount = 0;
        int shoppingCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SafeArea(
                child: WeeklyMealPlannerView(
                  state: state,
                  pantryTags: soup.requiredTags.toSet(),
                  onPreviousWeek: () {},
                  onNextWeek: () {},
                  onPresetChanged: (_) {},
                  onServingsChanged: (_) {},
                  onGenerateSmartWeek: () {},
                  onTransferMissingToShopping: () {},
                  onShareWeek: () {},
                  onClearWeek: () {},
                  onSelectDate: (_) {},
                  onToggleOverview: (_) {},
                  onAddMealToSlot: (_, _) {},
                  onMarkEntryCooked: (_) => cookCount++,
                  onRemoveEntry: (_) => removeCount++,
                  onOpenRecipe: (_) => openCount++,
                  onAddPromptMissingToShopping: (_) => shoppingCount++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inline banner should not be in the main list view; FAB bubble should be visible.
        expect(find.text('Günlük Mutfak Asistanı'), findsNothing);
        expect(find.byType(KitchenDailyAssistantFab), findsOneWidget);
        expect(find.text('2'), findsWidgets);

        final cardTitle = find.text(soup.title);
        await tester.scrollUntilVisible(
          cardTitle,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(cardTitle, findsOneWidget);
        expect(
          find.text(
            '2 kişilik • ${soup.totalMinutes} dk • ${soup.scaledCalories(2)} kcal',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.text('${soup.baseHealthScore}'), findsOneWidget);
        expect(find.byTooltip('Pişirdim'), findsOneWidget);
        expect(find.byTooltip('Planlanan Öğünü Sil'), findsOneWidget);

        // Old verbose labels removed
        expect(find.text('✅ Kilerde Tam'), findsNothing);
        expect(find.text('Kilerde Tam'), findsNothing);
        expect(find.text('Pişirdim'), findsNothing);

        await tester.tap(find.byTooltip('Pişirdim'));
        await tester.pump();
        expect(cookCount, 1);
        expect(openCount, 0);

        await tester.tap(find.byTooltip('Planlanan Öğünü Sil'));
        await tester.pump();
        expect(removeCount, 1);
        expect(openCount, 0);

        await tester.tap(cardTitle);
        await tester.pump();
        expect(openCount, 1);

        // Open assistant sheet from corner bubble
        await tester.tap(find.byType(KitchenDailyAssistantFab));
        await tester.pumpAndSettle();

        expect(find.text('Günlük Mutfak Asistanı'), findsOneWidget);
        expect(find.text('2 aktif yoklama'), findsOneWidget);

        await tester.tap(find.text('Alışverişe Ekle'));
        await tester.pump();
        expect(shoppingCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KitchenDailyAssistantFab updates reactively and auto-closes sheet when prompts clear',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final soup = findMasterRecipeById('suzme_mercimek_corbasi')!;
        final initialPrompts = [
          KitchenDailyPrompt(
            id: 'p1',
            type: KitchenPromptType.todayMissingIngredients,
            planDate: '2026-11-27',
            mealSlot: MealSlot.soupStarter,
            title: 'Birinci yoklama',
            subtitle: 'Eksik kontrolü',
            recipe: soup,
            missingTags: const ['limon'],
          ),
          KitchenDailyPrompt(
            id: 'p2',
            type: KitchenPromptType.unplannedSlotPantryCheck,
            planDate: '2026-11-27',
            mealSlot: MealSlot.mainCourse,
            title: 'İkinci yoklama',
            subtitle: 'Kiler kontrolü',
          ),
        ];

        late void Function(List<KitchenDailyPrompt>) setHostPrompts;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: _ReactiveFabHost(
              initialPrompts: initialPrompts,
              onBindSetter: (setter) => setHostPrompts = setter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(KitchenDailyAssistantFab), findsOneWidget);
        await tester.tap(find.byType(KitchenDailyAssistantFab));
        await tester.pumpAndSettle();

        expect(find.text('Günlük Mutfak Asistanı'), findsOneWidget);
        expect(find.text('2 aktif yoklama'), findsOneWidget);

        setHostPrompts([initialPrompts.last]);
        await tester.pumpAndSettle();
        expect(find.text('1 aktif yoklama'), findsOneWidget);

        setHostPrompts(const []);
        await tester.pumpAndSettle();

        expect(find.text('Günlük Mutfak Asistanı'), findsNothing);
        expect(find.byIcon(Icons.assistant_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _ReactiveFabHost extends StatefulWidget {
  final List<KitchenDailyPrompt> initialPrompts;
  final void Function(void Function(List<KitchenDailyPrompt>) setter)
      onBindSetter;

  const _ReactiveFabHost({
    required this.initialPrompts,
    required this.onBindSetter,
  });

  @override
  State<_ReactiveFabHost> createState() => _ReactiveFabHostState();
}

class _ReactiveFabHostState extends State<_ReactiveFabHost> {
  late List<KitchenDailyPrompt> _prompts;

  @override
  void initState() {
    super.initState();
    _prompts = widget.initialPrompts;
    widget.onBindSetter(_updatePrompts);
  }

  void _updatePrompts(List<KitchenDailyPrompt> next) {
    setState(() => _prompts = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(),
          if (_prompts.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: KitchenDailyAssistantFab(prompts: _prompts),
            ),
        ],
      ),
    );
  }
}
