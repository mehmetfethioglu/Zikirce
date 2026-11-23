import '../domain/recipe_models.dart';
import 'catalog_breakfast_soups.dart';
import 'catalog_classic_home_dishes.dart';
import 'catalog_mains_meats.dart';
import 'catalog_regional_specialties.dart';
import 'catalog_veg_salads_snacks.dart';

export 'catalog_regional_specialties.dart' show kilerceRegionalSpecialtyRecipes;

/// Master catalog of all 100 built-in Kilerce recipes across 7 categories and 7 regions.
const List<KilerRecipe> kilerceMasterRecipes = [
  ...kilerceBreakfastAndSoupRecipes,
  ...kilerceMainsAndMeatsRecipes,
  ...kilerceVegSaladsSnacksRecipes,
  ...kilerceRegionalSpecialtyRecipes,
  ...kilerceClassicHomeRecipes,
];

final Map<String, KilerRecipe> _masterRecipeIndex = {
  for (final recipe in kilerceMasterRecipes) recipe.id: recipe,
};

/// O(1) lookup helper for built-in master recipes.
KilerRecipe? findMasterRecipeById(String id) => _masterRecipeIndex[id];
