import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lab_personal/features/home/home_screen.dart';

const _testSupabaseUrl = String.fromEnvironment(
  'SUPABASE_TEST_URL',
  defaultValue: 'https://your-lab-project.supabase.co',
);
const _testSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_TEST_ANON_KEY',
  defaultValue: 'public-anon-key',
);

Future<void> _ensureSupabaseInitialized() => Supabase.initialize(
      url: _testSupabaseUrl,
      anonKey: _testSupabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryAsyncStorage(),
      ),
    );

class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async => _storage[key];

  @override
  Future<void> removeItem({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> setItem({
    required String key,
    required String value,
  }) async {
    _storage[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_ensureSupabaseInitialized);

  // This test documents that each tap updates the selected index and page.
  testWidgets('tapping bottom navigation items updates the visible page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final navBarFinder = find.byType(BottomNavigationBar);
    final navBar = tester.widget<BottomNavigationBar>(navBarFinder);
    expect(navBar.items.length, 4);

    final tabs = [
      ('Dashboard', 'Dashboard Principal'),
      ('Modify', 'Modify Page'),
      ('History', 'History Page'),
    ];

    for (var index = 0; index < tabs.length; index++) {
      final (label, expectedText) = tabs[index];

      if (index > 0) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      final navBar =
          tester.widget<BottomNavigationBar>(navBarFinder);

      expect(navBar.currentIndex, index);
      expect(find.text(expectedText), findsOneWidget);
    }

    // Verify that the Devices tab label is present without triggering its
    // asynchronous loading logic in tests.
    expect(find.text('Devices'), findsOneWidget);
  });
}
