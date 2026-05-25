import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/home_screen.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';

const String appGroupId = 'com.github.contributions.widget';
const String widgetName = 'GitHubContributionsWidget';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize home widget
  await HomeWidget.setAppGroupId(appGroupId);
  
  // Initialize widget with cached data if available
  await WidgetService.initializeWidget();
  
  // Initialize notification service
  await NotificationService.initialize();
  
  // Reschedule any existing reminders (e.g., after app update or reboot)
  await NotificationService.rescheduleReminderIfEnabled();
  
  runApp(const GitHubContributionsApp());
}

class GitHubContributionsApp extends StatelessWidget {
  const GitHubContributionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Contributions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0d1117),
        primaryColor: const Color(0xFF238636),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          secondary: Color(0xFF39d353),
          surface: Color(0xFF161b22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161b22),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0d1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363d)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF238636)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}