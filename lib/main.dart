import 'package:build_masterpro/features/auth/screens/forgot_password_screen.dart';
import 'package:build_masterpro/features/auth/screens/register_screen.dart';
import 'package:build_masterpro/features/projects/screens/about_my_app_screen.dart';
import 'package:build_masterpro/features/projects/screens/capture_photos_screen.dart';
import 'package:build_masterpro/features/projects/screens/checklists_screen.dart';
import 'package:build_masterpro/features/projects/screens/daily_logs_screen.dart';
import 'package:build_masterpro/features/projects/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/projects/screens/biometric_clock_in_out_screen.dart';
import 'features/projects/screens/home_screen.dart';
import 'features/projects/screens/incident_reporting_page.dart';
import 'features/projects/screens/overtime_tracking_screen.dart';
import 'features/projects/screens/project_management_screen.dart';
import 'features/projects/screens/document_management_screen.dart';
import 'features/projects/screens/communication_tools_screen.dart';
import 'features/projects/screens/field_reporting_screen.dart';
import 'features/projects/screens/resource_management_screen.dart';
import 'features/projects/screens/financial_management_screen.dart';
import 'features/projects/screens/time_tracking_screen.dart';
import 'features/projects/screens/safety_management_screen.dart';
import 'features/projects/screens/user_management_screen.dart';
import 'features/projects/screens/analytics_reporting_screen.dart';
import 'features/projects/screens/video_call_screen.dart';
import 'features/projects/screens/messaging_screen.dart';
import 'core/services/auth_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
    // Optionally handle Firebase init failure (e.g., show error screen)
  }

  // Load .env file with error handling
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
      prefs.setBool('darkMode', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'BuildMaster',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006D77),
            primary: const Color(0xFF006D77),
            secondary: const Color(0xFF83C5BE),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          iconTheme: const IconThemeData(
            color: Color(0xFF006D77),
          ),
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006D77),
            primary: const Color(0xFF006D77),
            secondary: const Color(0xFF83C5BE),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.grey[900],
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[850],
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.grey[800],
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          iconTheme: const IconThemeData(
            color: Color(0xFF83C5BE),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
            titleLarge: TextStyle(color: Colors.white),
          ),
        ),
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => SettingsScreen(
                isDarkMode: _isDarkMode,
                onThemeChanged: _toggleTheme,
              ),
          '/project_management': (context) => const ProjectManagementScreen(),
          '/document_management': (context) => const DocumentManagementScreen(),
          '/communication_tools': (context) => const CommunicationToolsScreen(),
          '/field_reporting': (context) => const FieldReportingScreen(),
          '/resource_management': (context) => const ResourceManagementScreen(),
          '/financial_management': (context) => const FinancialManagementScreen(),
          '/time_tracking': (context) => const TimeTrackingScreen(),
          '/safety_management': (context) => const SafetyManagementScreen(),
          '/user_management': (context) => const UserManagementScreen(),
          '/analytics_reporting': (context) => const AnalyticsReportingScreen(),
          '/profile': (context) => ProfileScreen(
                username: 'User123', // Replace with dynamic data if available
                email: FirebaseAuth.instance.currentUser?.email ?? 'user@example.com',
                onLogout: () async {
                  await Provider.of<AuthService>(context, listen: false).signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
          '/fieldReport': (context) => const FieldReportingScreen(),
          '/dailyLogs': (context) => const DailyLogsScreen(),
          '/capturePhotos': (context) => const CapturePhotosScreen(),
          '/checklists': (context) => const ChecklistsScreen(),
          '/submitReports': (context) => const IncidentReportingPage(),
          '/about_app': (context) => const AboutMyAppScreen(),
          '/biometric_clock_in_out': (context) => const BiometricClockInOutScreen(),
          '/overtime_tracking': (context) => const OvertimeTrackingScreen(),
          '/messaging': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return MessagingScreen(
              contactName: args?['contactName'],
              contactId: args?['contactId'],
            );
          },
          '/video_call': (context) {
            final user = FirebaseAuth.instance.currentUser;
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            return VideoCallScreen(
              callId: args?['callId'] ?? '${user?.uid}_${DateTime.now().millisecondsSinceEpoch}',
              receiverId: args?['receiverId'] ?? '',
              receiverName: args?['receiverName'] ?? 'Unknown',
              isInitiator: args?['isInitiator'] ?? true,
            );
          },
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        final User? user = snapshot.data;
        return user == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Toggle between light and dark theme'),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) {
                  onThemeChanged(value);
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Clock In/Out'),
              subtitle: const Text('Manage your clock-in and clock-out times'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/biometric_clock_in_out'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Overtime Tracking'),
              subtitle: const Text('Track your overtime hours'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/overtime_tracking'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Incident Reporting'),
              subtitle: const Text('Report incidents'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/submitReports'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Profile'),
              subtitle: const Text('View and edit your profile'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.pushNamed(context, '/profile'),
            ),
          ),
        ],
      ),
    );
  }
}