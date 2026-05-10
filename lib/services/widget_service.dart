import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contribution.dart';
import 'github_service.dart';

class WidgetService {
  static const String _widgetDataKey = 'widget_contribution_data';
  static const String _widgetLastUpdateKey = 'widget_last_update';
  static const String _widgetColorThemeKey = 'widget_color_theme';
  static const String appGroupId = 'com.github.contributions.widget';
  static const String androidWidgetName = 'GitHubContributionsWidget';

  /// Update the home screen widget with latest contribution data
  static Future<void> updateWidget() async {
    try {
      // Fetch latest contributions
      final data = await GitHubService.fetchContributions();
      
      // Prepare data for widget
      await _saveWidgetData(data);
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.github.contributions.github_contributions_widget.$androidWidgetName',
      );
    } catch (e) {
      // Try to use cached data
      final cachedData = await GitHubService.getCachedData();
      if (cachedData != null) {
        await _saveWidgetData(cachedData);
        await HomeWidget.updateWidget(
          name: androidWidgetName,
          androidName: androidWidgetName,
          qualifiedAndroidName: 'com.github.contributions.github_contributions_widget.$androidWidgetName',
        );
      }
    }
  }

  /// Save contribution data for widget consumption
  static Future<void> _saveWidgetData(ContributionData data) async {
    // Get the last 52 weeks for the widget (full year)
    final recentWeeks = data.getLastWeeks(52);
    
    // Get the current color theme from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final colorTheme = prefs.getInt('colorTheme') ?? 0; // 0=green, 1=blue, 2=yellow
    
    // Convert to a simple format for the widget
    final widgetData = {
      'totalContributions': data.totalContributions,
      'weeks': recentWeeks.map((week) {
        return week.days.map((day) => day.contributionLevel).toList();
      }).toList(),
      'lastUpdate': DateTime.now().toIso8601String(),
      'colorTheme': colorTheme,
    };

    final jsonString = jsonEncode(widgetData);
    final lastUpdateString = DateTime.now().toIso8601String();

    // Save using HomeWidget (this uses its own storage mechanism)
    await HomeWidget.saveWidgetData<String>(_widgetDataKey, jsonString);
    await HomeWidget.saveWidgetData<String>(_widgetLastUpdateKey, lastUpdateString);
    
    // ALSO save directly to SharedPreferences with flutter. prefix
    // This ensures the Kotlin widget can read it from FlutterSharedPreferences
    await prefs.setString('flutter.$_widgetDataKey', jsonString);
    await prefs.setString('flutter.$_widgetLastUpdateKey', lastUpdateString);
    await prefs.setInt('flutter.$_widgetColorThemeKey', widgetData['colorTheme'] as int);
    
    // Also save without prefix as fallback
    await prefs.setString(_widgetDataKey, jsonString);
    await prefs.setString(_widgetLastUpdateKey, lastUpdateString);
    await prefs.setInt(_widgetColorThemeKey, widgetData['colorTheme'] as int);
  }

  /// Get the last update time
  static Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString('flutter.$_widgetLastUpdateKey') ?? 
                       prefs.getString(_widgetLastUpdateKey);
    if (lastUpdate == null) return null;
    return DateTime.tryParse(lastUpdate);
  }

  /// Force refresh the widget
  static Future<void> forceRefresh() async {
    await updateWidget();
  }

  /// Initialize widget with saved data (if any)
  static Future<void> initializeWidget() async {
    final cachedData = await GitHubService.getCachedData();
    if (cachedData != null) {
      await _saveWidgetData(cachedData);
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.github.contributions.github_contributions_widget.$androidWidgetName',
      );
    }
  }
}