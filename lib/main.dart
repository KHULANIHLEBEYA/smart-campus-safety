import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/incident_details_screen.dart';
import 'screens/incident_history_screen.dart';
import 'screens/login_screen.dart';
import 'screens/manage_incidents_screen.dart';
import 'screens/manage_users_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/panic_button_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/report_screen.dart';
import 'screens/safe_zones_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartCampusSafetyApp());
}

class SmartCampusSafetyApp extends StatelessWidget {
  const SmartCampusSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F6E56);
    const paper = Color(0xFFF7F6F0);
    const ink = Color(0xFF182522);
    const divider = Color(0xFFDFE4DE);

    return MaterialApp(
      title: 'Smart Campus Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          secondary: const Color(0xFF1D9E75),
        ),
        scaffoldBackgroundColor: paper,
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          surfaceTintColor: paper,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 1,
          space: 1,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        // Student tabs and related destinations.
        '/home': (context) => const HomeScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/report': (context) => const ReportScreen(),
        '/incident-history': (context) => const IncidentHistoryScreen(),
        '/incident-details': (context) {
          final incident =
              ModalRoute.of(context)!.settings.arguments as Incident;
          return IncidentDetailsScreen(incident: incident);
        },
        '/notifications': (context) => const NotificationsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/safe-zones': (context) => const SafeZonesScreen(),
        '/panic': (context) => const PanicScreen(),

        // Admin/security destinations. Keep access controlled by the login flow
        // and Firestore rules; routes alone are not an authorization boundary.
        '/admin-home': (context) => const AdminHomeScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/manage-incidents': (context) => const ManageIncidentsScreen(),
        '/manage-users': (context) => const ManageUsersScreen(),
      },
    );
  }
}
