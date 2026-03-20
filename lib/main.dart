import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'providers/events_provider.dart';
import 'providers/participated_events_provider.dart';
import 'providers/user_accounts_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MobileAds.instance.initialize();
  final participatedProvider = ParticipatedEventsProvider();
  final userAccountsProvider = UserAccountsProvider();
  await Future.wait([
    participatedProvider.load(),
    userAccountsProvider.load(),
  ]);
  runApp(StockPickerApp(
    participatedProvider: participatedProvider,
    userAccountsProvider: userAccountsProvider,
  ));
}

class StockPickerApp extends StatelessWidget {
  final ParticipatedEventsProvider participatedProvider;
  final UserAccountsProvider userAccountsProvider;

  const StockPickerApp({
    super.key,
    required this.participatedProvider,
    required this.userAccountsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider.value(value: participatedProvider),
        ChangeNotifierProvider.value(value: userAccountsProvider),
      ],
      child: MaterialApp(
        title: '증권사 이벤트',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            margin: EdgeInsets.zero,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
