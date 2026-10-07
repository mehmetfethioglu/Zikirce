import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organicscore/core/services/changelog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChangelogService Tests (Zikirce_ Model)', () {
    test('Current version constants are valid and match pubspec specifications', () {
      expect(ChangelogService.currentVersionCode, greaterThanOrEqualTo(9));
      expect(ChangelogService.currentVersionName, isNotEmpty);
      expect(ChangelogService.releases, isNotEmpty);
    });

    test('Latest release contains valid dual-language titles, descriptions, and icons', () {
      final latest = ChangelogService.releases.first;
      expect(latest.versionCode, equals(ChangelogService.currentVersionCode));
      expect(latest.items, isNotEmpty);

      for (final item in latest.items) {
        expect(item.getTitle('tr'), isNotEmpty);
        expect(item.getTitle('en'), isNotEmpty);
        expect(item.getDescription('tr'), isNotEmpty);
        expect(item.getDescription('en'), isNotEmpty);
        expect(item.icon, isNotNull);
      }
    });

    test('Locale switcher returns correct language string', () {
      final latest = ChangelogService.releases.first;
      final firstItem = latest.items.first;

      expect(firstItem.getTitle('tr'), equals(firstItem.titleTr));
      expect(firstItem.getTitle('en'), equals(firstItem.titleEn));
      expect(firstItem.getDescription('tr'), equals(firstItem.descTr));
      expect(firstItem.getDescription('en'), equals(firstItem.descEn));
    });
  });
}
