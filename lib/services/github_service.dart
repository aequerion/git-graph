import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contribution.dart';
import '../models/activity_summary.dart';
import '../services/notification_service.dart';

class GitHubService {
  static const String _baseUrl = 'https://api.github.com/graphql';
  static const String _usernameKey = 'github_username';
  static const String _tokenKey = 'github_token';
  static const String _cachedDataKey = 'cached_contribution_data';
  static const String _avatarUrlKey = 'github_avatar_url';
  static const String _cachedYearlyDataKey = 'cached_yearly_contribution_data';
  static const String _cachedActivitySummaryKey = 'cached_activity_summary';

  /// GraphQL query to fetch contribution data and avatar
  static String _getContributionQuery(String username) => '''
    query {
      user(login: "$username") {
        avatarUrl
        contributionsCollection {
          contributionCalendar {
            totalContributions
            weeks {
              contributionDays {
                date
                contributionCount
                contributionLevel
              }
            }
          }
        }
      }
    }
  ''';

  /// Save GitHub credentials
  static Future<void> saveCredentials(String username, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_tokenKey, token);
  }

  /// Get saved username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Check if credentials are saved
  static Future<bool> hasCredentials() async {
    final username = await getUsername();
    final token = await getToken();
    return username != null && username.isNotEmpty && token != null && token.isNotEmpty;
  }

  /// Clear saved credentials
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_cachedDataKey);
    await prefs.remove(_avatarUrlKey);
  }

  /// Get saved avatar URL
  static Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarUrlKey);
  }

  /// Save avatar URL
  static Future<void> _saveAvatarUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarUrlKey, url);
  }

  /// Fetch contribution data from GitHub API
  static Future<ContributionData> fetchContributions({
    String? username,
    String? token,
  }) async {
    // Use provided credentials or fall back to saved ones
    final effectiveUsername = username ?? await getUsername();
    final effectiveToken = token ?? await getToken();

    if (effectiveUsername == null || effectiveUsername.isEmpty) {
      throw Exception('GitHub username is required');
    }

    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw Exception('GitHub token is required');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $effectiveToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': _getContributionQuery(effectiveUsername),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch contributions: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Check for GraphQL errors
      if (data.containsKey('errors')) {
        final errors = data['errors'] as List;
        throw Exception('GraphQL Error: ${errors.first['message']}');
      }

      // Parse the response
      final user = data['data']?['user'];
      if (user == null) {
        throw Exception('User not found: $effectiveUsername');
      }

      // Save avatar URL
      final avatarUrl = user['avatarUrl'] as String?;
      if (avatarUrl != null) {
        await _saveAvatarUrl(avatarUrl);
      }

      final calendar = user['contributionsCollection']['contributionCalendar'];
      final contributionData = ContributionData(
        totalContributions: calendar['totalContributions'] as int,
        weeks: (calendar['weeks'] as List).map((week) {
          return ContributionWeek(
            days: (week['contributionDays'] as List).map((day) {
              return ContributionDay(
                date: DateTime.parse(day['date'] as String),
                contributionCount: day['contributionCount'] as int,
                contributionLevel: _parseLevel(day['contributionLevel'] as String),
              );
            }).toList(),
          );
        }).toList(),
      );

      // Cache the data
      await _cacheData(contributionData);

      // Cancel tonight's evening reminder if the user has already contributed
      await NotificationService.cancelEveningReminderIfContributed();

      return contributionData;
    } catch (e) {
      // Try to return cached data if available
      final cachedData = await getCachedData();
      if (cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }

  /// Parse contribution level string to int
  static int _parseLevel(String level) {
    switch (level) {
      case 'NONE':
        return 0;
      case 'FIRST_QUARTILE':
        return 1;
      case 'SECOND_QUARTILE':
        return 2;
      case 'THIRD_QUARTILE':
        return 3;
      case 'FOURTH_QUARTILE':
        return 4;
      default:
        return 0;
    }
  }

  /// Cache contribution data locally
  static Future<void> _cacheData(ContributionData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedDataKey, jsonEncode(data.toJson()));
  }

  /// Get cached contribution data
  static Future<ContributionData?> getCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedDataKey);
    if (cachedJson == null) return null;

    try {
      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      return ContributionData.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get today's contribution count from cached data
  /// Returns 0 if no data is available or if today has no contributions
  static Future<int> getTodayContributions() async {
    final cachedData = await getCachedData();
    if (cachedData == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final week in cachedData.weeks) {
      for (final day in week.days) {
        final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
        if (dayDate.isAtSameMomentAs(today)) {
          return day.contributionCount;
        }
      }
    }

    return 0;
  }

  /// Check if user has made any contributions today
  static Future<bool> hasContributedToday() async {
    final contributions = await getTodayContributions();
    return contributions > 0;
  }

  /// GraphQL query to fetch contribution data for a specific year
  static String _getYearlyContributionQuery(String username, int year) => '''
    query {
      user(login: "$username") {
        contributionsCollection(from: "$year-01-01T00:00:00Z", to: "$year-12-31T23:59:59Z") {
          contributionCalendar {
            totalContributions
          }
        }
      }
    }
  ''';

  /// Fetch yearly contribution totals for multiple years
  static Future<Map<int, int>> fetchYearlyContributions({
    String? username,
    String? token,
    int yearsToFetch = 3,
  }) async {
    final effectiveUsername = username ?? await getUsername();
    final effectiveToken = token ?? await getToken();

    if (effectiveUsername == null || effectiveUsername.isEmpty) {
      throw Exception('GitHub username is required');
    }

    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw Exception('GitHub token is required');
    }

    final currentYear = DateTime.now().year;
    final yearlyData = <int, int>{};

    try {
      for (int i = 0; i < yearsToFetch; i++) {
        final year = currentYear - i;
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': 'Bearer $effectiveToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'query': _getYearlyContributionQuery(effectiveUsername, year),
          }),
        );

        if (response.statusCode != 200) {
          continue; // Skip this year if request fails
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data.containsKey('errors')) {
          continue; // Skip this year if there are GraphQL errors
        }

        final user = data['data']?['user'];
        if (user == null) continue;

        final calendar = user['contributionsCollection']?['contributionCalendar'];
        if (calendar == null) continue;

        final totalContributions = calendar['totalContributions'] as int? ?? 0;
        yearlyData[year] = totalContributions;
      }

      // Cache the data
      await _cacheYearlyData(yearlyData);

      return yearlyData;
    } catch (e) {
      // Try to return cached data if available
      final cachedData = await getCachedYearlyData();
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }
      rethrow;
    }
  }

  /// Cache yearly contribution data locally
  static Future<void> _cacheYearlyData(Map<int, int> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = data.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString(_cachedYearlyDataKey, jsonEncode(jsonData));
  }

  /// Get cached yearly contribution data
  static Future<Map<int, int>?> getCachedYearlyData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cachedYearlyDataKey);
    if (cachedJson == null) return null;

    try {
      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(int.parse(key), value as int));
    } catch (e) {
      return null;
    }
  }

  /// GraphQL query to fetch activity summary for a specific year
  static String _getActivitySummaryQuery(String username, int year) => '''
    query {
      user(login: "$username") {
        contributionsCollection(from: "$year-01-01T00:00:00Z", to: "$year-12-31T23:59:59Z") {
          totalCommitContributions
          totalRepositoriesWithContributedCommits
          totalPullRequestContributions
          totalPullRequestReviewContributions
          commitContributionsByRepository(maxRepositories: 10) {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
          pullRequestContributionsByRepository(maxRepositories: 10) {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
          pullRequestReviewContributionsByRepository(maxRepositories: 10) {
            repository {
              nameWithOwner
            }
            contributions {
              totalCount
            }
          }
        }
        repositories(first: 10, orderBy: {field: CREATED_AT, direction: DESC}, ownerAffiliations: OWNER) {
          nodes {
            name
            nameWithOwner
            description
            isPrivate
            createdAt
            primaryLanguage {
              name
              color
            }
            stargazerCount
            forkCount
          }
        }
        pullRequests(first: 50, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            title
            body
            number
            state
            additions
            deletions
            createdAt
            mergedAt
            closedAt
            url
            comments {
              totalCount
            }
            repository {
              name
              nameWithOwner
            }
          }
        }
      }
    }
  ''';

  /// Fetch activity summary for a specific year
  static Future<ActivitySummary> fetchActivitySummary({
    String? username,
    String? token,
    int? year,
  }) async {
    final effectiveUsername = username ?? await getUsername();
    final effectiveToken = token ?? await getToken();
    final effectiveYear = year ?? DateTime.now().year;

    if (effectiveUsername == null || effectiveUsername.isEmpty) {
      throw Exception('GitHub username is required');
    }

    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw Exception('GitHub token is required');
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $effectiveToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': _getActivitySummaryQuery(effectiveUsername, effectiveYear),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch activity summary: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('errors')) {
        final errors = data['errors'] as List;
        throw Exception('GraphQL Error: ${errors.first['message']}');
      }

      final user = data['data']?['user'];
      if (user == null) {
        throw Exception('User not found: $effectiveUsername');
      }

      final activitySummary = _parseActivitySummary(user, effectiveYear);
      
      // Cache the data
      await _cacheActivitySummary(activitySummary, effectiveYear);

      return activitySummary;
    } catch (e) {
      debugPrint('Error fetching activity summary: $e');
      // Try to return cached data if available
      final cachedData = await getCachedActivitySummary(effectiveYear);
      if (cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }

  /// Parse activity summary from API response
  static ActivitySummary _parseActivitySummary(Map<String, dynamic> user, int year) {
    final contributions = user['contributionsCollection'] ?? {};
    final repositories = user['repositories']?['nodes'] as List? ?? [];
    final pullRequests = user['pullRequests']?['nodes'] as List? ?? [];

    // Parse created repositories (filter by year)
    final createdRepos = repositories
        .where((repo) {
          final createdAt = DateTime.tryParse(repo['createdAt'] ?? '');
          return createdAt != null && createdAt.year == year;
        })
        .map((repo) => RepositoryInfo(
              name: repo['name'] ?? '',
              fullName: repo['nameWithOwner'] ?? '',
              description: repo['description'],
              primaryLanguage: repo['primaryLanguage']?['name'],
              languageColor: repo['primaryLanguage']?['color'],
              createdAt: DateTime.tryParse(repo['createdAt'] ?? '') ?? DateTime.now(),
              isPrivate: repo['isPrivate'] ?? false,
              starCount: repo['stargazerCount'] ?? 0,
              forkCount: repo['forkCount'] ?? 0,
            ))
        .toList();

    // Parse pull requests (filter by year)
    final yearPullRequests = pullRequests
        .where((pr) {
          final createdAt = DateTime.tryParse(pr['createdAt'] ?? '');
          return createdAt != null && createdAt.year == year;
        })
        .map((pr) => PullRequestInfo(
              title: pr['title'] ?? '',
              body: pr['body'],
              repositoryName: pr['repository']?['name'] ?? '',
              repositoryFullName: pr['repository']?['nameWithOwner'] ?? '',
              number: pr['number'] ?? 0,
              state: pr['state'] ?? 'OPEN',
              additions: pr['additions'] ?? 0,
              deletions: pr['deletions'] ?? 0,
              commentsCount: pr['comments']?['totalCount'] ?? 0,
              createdAt: DateTime.tryParse(pr['createdAt'] ?? '') ?? DateTime.now(),
              mergedAt: pr['mergedAt'] != null ? DateTime.tryParse(pr['mergedAt']) : null,
              closedAt: pr['closedAt'] != null ? DateTime.tryParse(pr['closedAt']) : null,
              url: pr['url'] ?? '',
            ))
        .toList();

    // Calculate PR stats by repository
    final prByRepo = <String, PullRequestStats>{};
    for (final pr in yearPullRequests) {
      final repoName = pr.repositoryFullName;
      final existing = prByRepo[repoName] ?? PullRequestStats();
      prByRepo[repoName] = PullRequestStats(
        opened: existing.opened + 1,
        merged: existing.merged + (pr.isMerged ? 1 : 0),
        closed: existing.closed + (pr.isClosed ? 1 : 0),
      );
    }

    // Parse reviews by repository
    final reviewsByRepo = <String, int>{};
    final reviewContributions = contributions['pullRequestReviewContributionsByRepository'] as List? ?? [];
    for (final review in reviewContributions) {
      final repoName = review['repository']?['nameWithOwner'] ?? '';
      final count = review['contributions']?['totalCount'] ?? 0;
      if (repoName.isNotEmpty && count > 0) {
        reviewsByRepo[repoName] = count;
      }
    }

    // Count PR states
    int opened = 0, merged = 0, closed = 0;
    for (final pr in yearPullRequests) {
      opened++;
      if (pr.isMerged) merged++;
      if (pr.isClosed) closed++;
    }

    return ActivitySummary(
      totalCommits: contributions['totalCommitContributions'] ?? 0,
      commitRepositoryCount: contributions['totalRepositoriesWithContributedCommits'] ?? 0,
      createdRepositories: createdRepos,
      pullRequests: yearPullRequests,
      totalPullRequestsOpened: opened,
      totalPullRequestsMerged: merged,
      totalPullRequestsClosed: closed,
      totalPullRequestsReviewed: contributions['totalPullRequestReviewContributions'] ?? 0,
      pullRequestsByRepo: prByRepo,
      reviewsByRepo: reviewsByRepo,
    );
  }

  /// Cache activity summary data locally
  static Future<void> _cacheActivitySummary(ActivitySummary data, int year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_cachedActivitySummaryKey}_$year', jsonEncode(data.toJson()));
  }

  /// Get cached activity summary data
  static Future<ActivitySummary?> getCachedActivitySummary(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('${_cachedActivitySummaryKey}_$year');
    if (cachedJson == null) return null;

    try {
      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      return ActivitySummary.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Get today's contribution count from cached data
  static Future<int> getTodayContributions() async {
    final cachedData = await getCachedData();
    if (cachedData == null) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final week in cachedData.weeks) {
      for (final day in week.days) {
        final dayDate = DateTime(day.date.year, day.date.month, day.date.day);
        if (dayDate.isAtSameMomentAs(todayDate)) {
          return day.contributionCount;
        }
      }
    }
    return 0;
  }

  /// Check if user has contributed today
  static Future<bool> hasContributedToday() async {
    final contributions = await getTodayContributions();
    return contributions > 0;
  }

  /// Validate credentials by making a test API call
  static Future<bool> validateCredentials(String username, String token) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '''
            query {
              user(login: "$username") {
                login
              }
            }
          ''',
        }),
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data']?['user'] != null;
    } catch (e) {
      return false;
    }
  }
}