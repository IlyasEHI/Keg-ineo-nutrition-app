import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/weight_history.dart';
import 'app.dart';
import 'ui/dashboard_page.dart';
import 'state/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(WeightHistoryAdapter());
  await Hive.openBox<WeightHistory>('weight_history');

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    // Thème clair moderne inspiré des apps nutrition
    final lightColorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5), // Teal vibrant
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF7C4DFF),
          tertiary: const Color(0xFFFF6F00),
          surface: const Color(0xFFFAFAFA),
          surfaceContainerHighest: const Color(0xFFFFFFFF),
        );

    final lightTheme = ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: lightColorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        color: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );

    // Thème sombre moderne
    final darkColorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF9575FF),
          tertiary: const Color(0xFFFFAB40),
          surface: const Color(0xFF1A1D23),
          surfaceContainerHighest: const Color(0xFF2A2E35),
          background: const Color(0xFF12141A),
        );

    final darkTheme = ThemeData(
      colorScheme: darkColorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF12141A),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkColorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        color: Color(0xFF1E2229),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );

    return MaterialApp(
      title: 'KEG INEO',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const DashboardPage(),
    );
  }
}
