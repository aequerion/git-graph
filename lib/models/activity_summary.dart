/// Model for GitHub activity summary data
class ActivitySummary {
  final int totalCommits;
  final int commitRepositoryCount;
  final List<RepositoryInfo> createdRepositories;
  final List<PullRequestInfo> pullRequests;
  final int totalPullRequestsOpened;
  final int totalPullRequestsMerged;
  final int totalPullRequestsClosed;
  final int totalPullRequestsReviewed;
  final Map<String, PullRequestStats> pullRequestsByRepo;
  final Map<String, int> reviewsByRepo;
  final DateTime fetchedAt;

  ActivitySummary({
    required this.totalCommits,
    required this.commitRepositoryCount,
    required this.createdRepositories,
    required this.pullRequests,
    required this.totalPullRequestsOpened,
    required this.totalPullRequestsMerged,
    required this.totalPullRequestsClosed,
    required this.totalPullRequestsReviewed,
    required this.pullRequestsByRepo,
    required this.reviewsByRepo,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      totalCommits: json['totalCommits'] as int? ?? 0,
      commitRepositoryCount: json['commitRepositoryCount'] as int? ?? 0,
      createdRepositories: (json['createdRepositories'] as List?)
              ?.map((e) => RepositoryInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pullRequests: (json['pullRequests'] as List?)
              ?.map((e) => PullRequestInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalPullRequestsOpened: json['totalPullRequestsOpened'] as int? ?? 0,
      totalPullRequestsMerged: json['totalPullRequestsMerged'] as int? ?? 0,
      totalPullRequestsClosed: json['totalPullRequestsClosed'] as int? ?? 0,
      totalPullRequestsReviewed: json['totalPullRequestsReviewed'] as int? ?? 0,
      pullRequestsByRepo: (json['pullRequestsByRepo'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(
                  key, PullRequestStats.fromJson(value as Map<String, dynamic>))) ??
          {},
      reviewsByRepo: (json['reviewsByRepo'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value as int)) ??
          {},
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCommits': totalCommits,
      'commitRepositoryCount': commitRepositoryCount,
      'createdRepositories': createdRepositories.map((e) => e.toJson()).toList(),
      'pullRequests': pullRequests.map((e) => e.toJson()).toList(),
      'totalPullRequestsOpened': totalPullRequestsOpened,
      'totalPullRequestsMerged': totalPullRequestsMerged,
      'totalPullRequestsClosed': totalPullRequestsClosed,
      'totalPullRequestsReviewed': totalPullRequestsReviewed,
      'pullRequestsByRepo':
          pullRequestsByRepo.map((key, value) => MapEntry(key, value.toJson())),
      'reviewsByRepo': reviewsByRepo,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }
}

/// Repository information
class RepositoryInfo {
  final String name;
  final String fullName;
  final String? description;
  final String? primaryLanguage;
  final String? languageColor;
  final DateTime createdAt;
  final bool isPrivate;
  final int starCount;
  final int forkCount;

  RepositoryInfo({
    required this.name,
    required this.fullName,
    this.description,
    this.primaryLanguage,
    this.languageColor,
    required this.createdAt,
    this.isPrivate = false,
    this.starCount = 0,
    this.forkCount = 0,
  });

  factory RepositoryInfo.fromJson(Map<String, dynamic> json) {
    return RepositoryInfo(
      name: json['name'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      description: json['description'] as String?,
      primaryLanguage: json['primaryLanguage'] as String?,
      languageColor: json['languageColor'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isPrivate: json['isPrivate'] as bool? ?? false,
      starCount: json['starCount'] as int? ?? 0,
      forkCount: json['forkCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fullName': fullName,
      'description': description,
      'primaryLanguage': primaryLanguage,
      'languageColor': languageColor,
      'createdAt': createdAt.toIso8601String(),
      'isPrivate': isPrivate,
      'starCount': starCount,
      'forkCount': forkCount,
    };
  }
}

/// Pull request information
class PullRequestInfo {
  final String title;
  final String? body;
  final String repositoryName;
  final String repositoryFullName;
  final int number;
  final String state; // OPEN, MERGED, CLOSED
  final int additions;
  final int deletions;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? mergedAt;
  final DateTime? closedAt;
  final String url;

  PullRequestInfo({
    required this.title,
    this.body,
    required this.repositoryName,
    required this.repositoryFullName,
    required this.number,
    required this.state,
    this.additions = 0,
    this.deletions = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.mergedAt,
    this.closedAt,
    required this.url,
  });

  bool get isMerged => state == 'MERGED';
  bool get isClosed => state == 'CLOSED' && !isMerged;
  bool get isOpen => state == 'OPEN';

  factory PullRequestInfo.fromJson(Map<String, dynamic> json) {
    return PullRequestInfo(
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      repositoryName: json['repositoryName'] as String? ?? '',
      repositoryFullName: json['repositoryFullName'] as String? ?? '',
      number: json['number'] as int? ?? 0,
      state: json['state'] as String? ?? 'OPEN',
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      mergedAt: json['mergedAt'] != null
          ? DateTime.parse(json['mergedAt'] as String)
          : null,
      closedAt: json['closedAt'] != null
          ? DateTime.parse(json['closedAt'] as String)
          : null,
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'repositoryName': repositoryName,
      'repositoryFullName': repositoryFullName,
      'number': number,
      'state': state,
      'additions': additions,
      'deletions': deletions,
      'commentsCount': commentsCount,
      'createdAt': createdAt.toIso8601String(),
      'mergedAt': mergedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'url': url,
    };
  }
}

/// Pull request statistics per repository
class PullRequestStats {
  final int opened;
  final int merged;
  final int closed;

  PullRequestStats({
    this.opened = 0,
    this.merged = 0,
    this.closed = 0,
  });

  factory PullRequestStats.fromJson(Map<String, dynamic> json) {
    return PullRequestStats(
      opened: json['opened'] as int? ?? 0,
      merged: json['merged'] as int? ?? 0,
      closed: json['closed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opened': opened,
      'merged': merged,
      'closed': closed,
    };
  }
}

/// Language color mapping for common languages
class LanguageColors {
  static const Map<String, String> colors = {
    'Java': '#b07219',
    'JavaScript': '#f1e05a',
    'TypeScript': '#3178c6',
    'Python': '#3572A5',
    'Go': '#00ADD8',
    'Rust': '#dea584',
    'C': '#555555',
    'C++': '#f34b7d',
    'C#': '#178600',
    'Ruby': '#701516',
    'PHP': '#4F5D95',
    'Swift': '#F05138',
    'Kotlin': '#A97BFF',
    'Dart': '#00B4AB',
    'HTML': '#e34c26',
    'CSS': '#563d7c',
    'Shell': '#89e051',
    'Scala': '#c22d40',
    'Haskell': '#5e5086',
    'Lua': '#000080',
    'R': '#198CE7',
    'MATLAB': '#e16737',
    'Perl': '#0298c3',
    'Objective-C': '#438eff',
    'Vue': '#41b883',
    'Svelte': '#ff3e00',
  };

  static String getColor(String? language) {
    if (language == null) return '#8b949e';
    return colors[language] ?? '#8b949e';
  }
}