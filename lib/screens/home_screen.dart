import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contribution.dart';
import '../models/activity_summary.dart';
import '../services/github_service.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../widgets/contribution_graph.dart';
import '../widgets/shimmer_skeleton.dart';
import '../widgets/year_comparison.dart';
import '../widgets/reminder_settings.dart';
import '../widgets/activity_summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _usernameController = TextEditingController();
  final _tokenController = TextEditingController();
  
  bool _isLoading = false;
  bool _isConfigured = false;
  bool _isInitialLoad = true;
  bool _obscureToken = true;
  String? _errorMessage;
  ContributionData? _contributionData;
  Map<int, int>? _yearlyData;
  bool _isLoadingYearlyData = false;
  String? _currentUsername;
  String? _avatarUrl;
  ColorTheme _colorTheme = ColorTheme.green;
  ActivitySummary? _activitySummary;
  bool _isLoadingActivitySummary = false;
  int _selectedActivityYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadColorTheme();
    _loadSavedData();
  }

  Future<void> _loadColorTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('colorTheme') ?? 0;
    setState(() {
      _colorTheme = ColorTheme.values[themeIndex.clamp(0, ColorTheme.values.length - 1)];
    });
  }

  Future<void> _saveColorTheme(ColorTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorTheme', theme.index);
    HapticFeedback.lightImpact();
    setState(() {
      _colorTheme = theme;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    setState(() => _isLoading = true);
    
    try {
      final hasCredentials = await GitHubService.hasCredentials();
      if (hasCredentials) {
        final username = await GitHubService.getUsername();
        final avatarUrl = await GitHubService.getAvatarUrl();
        _currentUsername = username;
        _avatarUrl = avatarUrl;
        _usernameController.text = username ?? '';
        
        // Mark as configured to show shimmer
        setState(() {
          _isConfigured = true;
        });
        
        // Try to load cached data first
        final cachedData = await GitHubService.getCachedData();
        if (cachedData != null) {
          setState(() {
            _contributionData = cachedData;
            _isInitialLoad = false;
          });
        }
        
        // Then fetch fresh data
        await _fetchContributions();
        
        // Fetch yearly data for year-over-year comparison
        await _fetchYearlyContributions();
        
        // Fetch activity summary
        await _fetchActivitySummary();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  Future<void> _fetchContributions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await GitHubService.fetchContributions();
      final avatarUrl = await GitHubService.getAvatarUrl();
      setState(() {
        _contributionData = data;
        _avatarUrl = avatarUrl;
        _isConfigured = true;
      });
      
      // Update the widget
      await WidgetService.updateWidget();
      
      // Update evening notification based on today's contributions
      // If user has already contributed today, cancel the evening reminder
      await NotificationService.updateEveningNotificationBasedOnContributions();
      
      _fetchYearlyContributions();
      _fetchActivitySummary();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchYearlyContributions() async {
    if (_isLoadingYearlyData) return;
    
    setState(() => _isLoadingYearlyData = true);
    
    try {
      final yearlyData = await GitHubService.fetchYearlyContributions(yearsToFetch: 3);
      setState(() {
        _yearlyData = yearlyData;
      });
    } catch (e) {
      // Silently fail for yearly data - it's not critical
      debugPrint('Failed to fetch yearly data: $e');
    } finally {
      setState(() => _isLoadingYearlyData = false);
    }
  }

  Future<void> _fetchActivitySummary({int? year}) async {
    if (_isLoadingActivitySummary) return;
    
    final targetYear = year ?? _selectedActivityYear;
    
    setState(() {
      _isLoadingActivitySummary = true;
      if (year != null) {
        _selectedActivityYear = year;
      }
    });
    
    try {
      final activitySummary = await GitHubService.fetchActivitySummary(year: targetYear);
      setState(() {
        _activitySummary = activitySummary;
      });
    } catch (e) {
      // Silently fail for activity summary - it's not critical
      debugPrint('Failed to fetch activity summary: $e');
    } finally {
      setState(() => _isLoadingActivitySummary = false);
    }
  }

  Future<void> _saveCredentials() async {
    final username = _usernameController.text.trim();
    final token = _tokenController.text.trim();

    if (username.isEmpty || token.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username and token');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate credentials
      final isValid = await GitHubService.validateCredentials(username, token);
      if (!isValid) {
        setState(() => _errorMessage = 'Invalid credentials. Please check your username and token.');
        return;
      }

      // Save credentials
      await GitHubService.saveCredentials(username, token);
      _currentUsername = username;
      _tokenController.clear();

      // Mark as configured to show shimmer while fetching
      setState(() {
        _isConfigured = true;
        _contributionData = null; // Clear any old data to show shimmer
      });

      // Fetch contributions
      await _fetchContributions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credentials saved successfully!'),
            backgroundColor: Color(0xFF238636),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161b22),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout? This will clear your saved credentials.',
          style: TextStyle(color: Color(0xFF8b949e)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await GitHubService.clearCredentials();
      setState(() {
        _isConfigured = false;
        _contributionData = null;
        _yearlyData = null;
        _activitySummary = null;
        _currentUsername = null;
        _avatarUrl = null;
        _usernameController.clear();
        _tokenController.clear();
      });
    }
  }

  Future<void> _onPullToRefresh() async {
    if (!_isConfigured || _isLoading) return;
    
    HapticFeedback.mediumImpact();
    await _fetchContributions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contributions refreshed!'),
          backgroundColor: Color(0xFF238636),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GitGraph',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchContributions,
              tooltip: 'Refresh',
            ),
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onPullToRefresh,
        color: const Color(0xFF238636),
        backgroundColor: const Color(0xFF161b22),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isConfigured) ...[
                _buildSetupCard(),
              ] else if (_isLoading && _contributionData == null) ...[
                // Show shimmer skeleton during initial load
                const LoadingSkeleton(),
                const SizedBox(height: 16),
                _buildWidgetInstructions(),
              ] else ...[
                _buildUserCard(),
                const SizedBox(height: 16),
                _buildContributionCard(),
                const SizedBox(height: 16),
                _buildYearComparisonCard(),
                const SizedBox(height: 16),
                _buildActivitySummaryCard(),
                const SizedBox(height: 16),
                const ReminderSettingsCard(),
                const SizedBox(height: 16),
                _buildWidgetInstructions(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupCard() {
    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF8b949e)),
                SizedBox(width: 8),
                Text(
                  'Setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your GitHub credentials to fetch your contribution data.',
              style: TextStyle(color: Color(0xFF8b949e)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'GitHub Username',
                labelStyle: TextStyle(color: Color(0xFF8b949e)),
                prefixIcon: Icon(Icons.person, color: Color(0xFF8b949e)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: 'Personal Access Token',
                labelStyle: const TextStyle(color: Color(0xFF8b949e)),
                prefixIcon: const Icon(Icons.key, color: Color(0xFF8b949e)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureToken ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF8b949e),
                  ),
                  onPressed: () => setState(() => _obscureToken = !_obscureToken),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            _buildTokenHelp(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  HapticFeedback.mediumImpact();
                  _saveCredentials();
                },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save & Fetch Contributions'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenHelp() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to create a Personal Access Token:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Go to GitHub Settings → Developer settings\n'
            '2. Click "Personal access tokens" → "Tokens (classic)"\n'
            '3. Generate new token with "read:user" scope\n'
            '4. Copy and paste the token here',
            style: TextStyle(color: Color(0xFF8b949e), fontSize: 12),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(const ClipboardData(
                text: 'https://github.com/settings/tokens/new',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copied to clipboard!')),
              );
            },
            child: const Text(
              'https://github.com/settings/tokens/new',
              style: TextStyle(
                color: Color(0xFF58a6ff),
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final currentStreak = _contributionData?.currentStreak ?? 0;
    final longestStreak = _contributionData?.longestStreak ?? 0;
    
    // Get theme-aware streak colors
    final currentStreakColor = GitHubColors.getCurrentStreakColor(_colorTheme);
    final longestStreakColor = GitHubColors.getLongestStreakColor(_colorTheme);
    
    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _avatarUrl != null
                ? CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(_avatarUrl!),
                    backgroundColor: const Color(0xFF238636),
                    onBackgroundImageError: (_, __) {},
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF238636),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUsername ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_contributionData != null) ...[
                    Text(
                      '${_contributionData!.totalContributions} contributions in the last year',
                      style: const TextStyle(color: Color(0xFF8b949e)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Current Streak
                        Icon(
                          currentStreak > 0 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                          size: 16,
                          color: currentStreak > 0 ? currentStreakColor : const Color(0xFF8b949e),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          currentStreak > 0 
                              ? '$currentStreak day${currentStreak == 1 ? '' : 's'}'
                              : 'No streak',
                          style: TextStyle(
                            color: currentStreak > 0 ? currentStreakColor : const Color(0xFF8b949e),
                            fontSize: 12,
                            fontWeight: currentStreak > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Longest Streak
                        Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: longestStreak > 0 ? longestStreakColor : const Color(0xFF8b949e),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          longestStreak > 0 
                              ? '$longestStreak day${longestStreak == 1 ? '' : 's'} best'
                              : 'No best',
                          style: TextStyle(
                            color: longestStreak > 0 ? longestStreakColor : const Color(0xFF8b949e),
                            fontSize: 12,
                            fontWeight: longestStreak > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionCard() {
    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.grid_view, color: Color(0xFF8b949e)),
                SizedBox(width: 8),
                Text(
                  'Contribution Graph',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ContributionGraph(
              data: _contributionData,
              weeksToShow: 52,
              cellSize: 10,
              cellSpacing: 3,
              borderRadius: 2,
              colorTheme: _colorTheme,
            ),
            if (_contributionData != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last updated: ${_formatDateTime(_contributionData!.fetchedAt)}',
                style: const TextStyle(
                  color: Color(0xFF8b949e),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildThemePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Theme:',
          style: TextStyle(
            color: Color(0xFF8b949e),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        _buildThemeCircle(ColorTheme.green, GitHubColors.greenLevel4),
        const SizedBox(width: 8),
        _buildThemeCircle(ColorTheme.blue, GitHubColors.blueLevel4),
        const SizedBox(width: 8),
        _buildThemeCircle(ColorTheme.yellow, GitHubColors.yellowLevel4),
      ],
    );
  }

  Widget _buildThemeCircle(ColorTheme theme, Color color) {
    final isSelected = _colorTheme == theme;
    return GestureDetector(
      onTap: () => _saveColorTheme(theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : null,
      ),
    );
  }

  Widget _buildYearComparisonCard() {
    return YearComparisonCard(
      yearlyData: _yearlyData,
      isLoading: _isLoadingYearlyData,
      colorTheme: _colorTheme,
    );
  }

  Widget _buildActivitySummaryCard() {
    final currentYear = DateTime.now().year;
    final availableYears = List.generate(5, (i) => currentYear - i);
    
    return ActivitySummaryCard(
      activitySummary: _activitySummary,
      isLoading: _isLoadingActivitySummary,
      selectedYear: _selectedActivityYear,
      availableYears: availableYears,
      onYearChanged: (year) {
        HapticFeedback.lightImpact();
        _fetchActivitySummary(year: year);
      },
    );
  }

  Widget _buildWidgetInstructions() {
    return Card(
      color: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF30363d)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.widgets, color: Color(0xFF8b949e)),
                SizedBox(width: 8),
                Text(
                  'Add Home Screen Widget',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'To add the contribution graph to your home screen:',
              style: TextStyle(color: Color(0xFF8b949e)),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Long press on your home screen\n'
              '2. Tap "Widgets"\n'
              '3. Find "GitGraph"\n'
              '4. Drag the widget to your home screen',
              style: TextStyle(color: Color(0xFF8b949e), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () async {
                  HapticFeedback.lightImpact();
                  await WidgetService.updateWidget();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Widget updated!')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Update Widget Now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF58a6ff),
                  side: const BorderSide(color: Color(0xFF30363d)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: const Color(0xFF490202),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFf85149)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFf85149)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Color(0xFFf85149)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFFf85149)),
              onPressed: () => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}