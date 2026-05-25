import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity_summary.dart';
import 'package:intl/intl.dart';

/// Widget to display GitHub activity summary
class ActivitySummaryCard extends StatelessWidget {
  final ActivitySummary? activitySummary;
  final bool isLoading;
  final int selectedYear;
  final Function(int) onYearChanged;
  final List<int> availableYears;

  const ActivitySummaryCard({
    super.key,
    this.activitySummary,
    this.isLoading = false,
    required this.selectedYear,
    required this.onYearChanged,
    required this.availableYears,
  });

  @override
  Widget build(BuildContext context) {
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
            // Header with year selector
            Row(
              children: [
                const Icon(Icons.timeline, color: Color(0xFF8b949e)),
                const SizedBox(width: 8),
                const Text(
                  'Contribution Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _buildYearSelector(),
              ],
            ),
            const SizedBox(height: 16),
            
            if (isLoading)
              _buildLoadingState()
            else if (activitySummary == null)
              _buildEmptyState()
            else
              _buildActivityContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedYear,
          isDense: true,
          dropdownColor: const Color(0xFF21262d),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8b949e), size: 20),
          items: availableYears.map((year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text('$year'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onYearChanged(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No activity data available',
          style: TextStyle(color: Color(0xFF8b949e)),
        ),
      ),
    );
  }

  Widget _buildActivityContent() {
    final summary = activitySummary!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Commits section
        if (summary.totalCommits > 0)
          _CommitsSummarySection(
            totalCommits: summary.totalCommits,
            repositoryCount: summary.commitRepositoryCount,
          ),
        
        // Created repositories section
        if (summary.createdRepositories.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CreatedRepositoriesSection(
            repositories: summary.createdRepositories,
          ),
        ],
        
        // Pull requests section
        if (summary.totalPullRequestsOpened > 0) ...[
          const SizedBox(height: 16),
          _PullRequestsSection(
            pullRequests: summary.pullRequests,
            totalOpened: summary.totalPullRequestsOpened,
            totalMerged: summary.totalPullRequestsMerged,
            totalClosed: summary.totalPullRequestsClosed,
            prByRepo: summary.pullRequestsByRepo,
          ),
        ],
        
        // Reviews section
        if (summary.totalPullRequestsReviewed > 0) ...[
          const SizedBox(height: 16),
          _ReviewsSection(
            totalReviews: summary.totalPullRequestsReviewed,
            reviewsByRepo: summary.reviewsByRepo,
          ),
        ],
        
        // Empty state if no activity
        if (summary.totalCommits == 0 &&
            summary.createdRepositories.isEmpty &&
            summary.totalPullRequestsOpened == 0 &&
            summary.totalPullRequestsReviewed == 0)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No activity for this year',
                style: TextStyle(color: Color(0xFF8b949e)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Commits summary section
class _CommitsSummarySection extends StatelessWidget {
  final int totalCommits;
  final int repositoryCount;

  const _CommitsSummarySection({
    required this.totalCommits,
    required this.repositoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return _ActivityItem(
      icon: Icons.commit,
      iconColor: const Color(0xFF238636),
      title: 'Created $totalCommits commits in $repositoryCount ${repositoryCount == 1 ? 'repository' : 'repositories'}',
    );
  }
}

/// Created repositories section
class _CreatedRepositoriesSection extends StatefulWidget {
  final List<RepositoryInfo> repositories;

  const _CreatedRepositoriesSection({required this.repositories});

  @override
  State<_CreatedRepositoriesSection> createState() => _CreatedRepositoriesSectionState();
}

class _CreatedRepositoriesSectionState extends State<_CreatedRepositoriesSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, color: Color(0xFF8b949e), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Created ${widget.repositories.length} ${widget.repositories.length == 1 ? 'repository' : 'repositories'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF8b949e),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.repositories.map((repo) => _RepositoryItem(repository: repo)),
        ],
      ],
    );
  }
}

/// Repository item
class _RepositoryItem extends StatelessWidget {
  final RepositoryInfo repository;

  const _RepositoryItem({required this.repository});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 8),
      child: Row(
        children: [
          Icon(
            repository.isPrivate ? Icons.lock_outline : Icons.folder_outlined,
            color: const Color(0xFF8b949e),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              repository.fullName,
              style: const TextStyle(
                color: Color(0xFF58a6ff),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (repository.primaryLanguage != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _parseColor(repository.languageColor ?? LanguageColors.getColor(repository.primaryLanguage)),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              repository.primaryLanguage!,
              style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
            ),
          ],
          const SizedBox(width: 12),
          Text(
            dateFormat.format(repository.createdAt),
            style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF8b949e);
    }
  }
}

/// Pull requests section
class _PullRequestsSection extends StatefulWidget {
  final List<PullRequestInfo> pullRequests;
  final int totalOpened;
  final int totalMerged;
  final int totalClosed;
  final Map<String, PullRequestStats> prByRepo;

  const _PullRequestsSection({
    required this.pullRequests,
    required this.totalOpened,
    required this.totalMerged,
    required this.totalClosed,
    required this.prByRepo,
  });

  @override
  State<_PullRequestsSection> createState() => _PullRequestsSectionState();
}

class _PullRequestsSectionState extends State<_PullRequestsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Get the most significant PR (most lines changed)
    final featuredPR = widget.pullRequests.isNotEmpty
        ? widget.pullRequests.reduce((a, b) =>
            (a.additions + a.deletions) > (b.additions + b.deletions) ? a : b)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Featured PR
        if (featuredPR != null && featuredPR.additions + featuredPR.deletions > 50) ...[
          _ActivityItem(
            icon: Icons.call_merge,
            iconColor: const Color(0xFF8957e5),
            title: 'Created a pull request in ${featuredPR.repositoryFullName}',
            subtitle: featuredPR.commentsCount > 0
                ? 'that received ${featuredPR.commentsCount} ${featuredPR.commentsCount == 1 ? 'comment' : 'comments'}'
                : null,
          ),
          const SizedBox(height: 8),
          _FeaturedPullRequest(pullRequest: featuredPR),
          const SizedBox(height: 12),
        ],
        
        // Summary
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.call_merge, color: Color(0xFF8b949e), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Opened ${widget.totalOpened} pull ${widget.totalOpened == 1 ? 'request' : 'requests'} in ${widget.prByRepo.length} ${widget.prByRepo.length == 1 ? 'repository' : 'repositories'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF8b949e),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.prByRepo.entries.map((entry) => _PullRequestRepoItem(
            repoName: entry.key,
            stats: entry.value,
          )),
        ],
      ],
    );
  }
}

/// Featured pull request card
class _FeaturedPullRequest extends StatelessWidget {
  final PullRequestInfo pullRequest;

  const _FeaturedPullRequest({required this.pullRequest});

  void _copyUrl(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PR link copied to clipboard'),
        backgroundColor: Color(0xFF238636),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262d),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pullRequest.isMerged
                    ? Icons.merge
                    : pullRequest.isClosed
                        ? Icons.close
                        : Icons.call_merge,
                color: pullRequest.isMerged
                    ? const Color(0xFF8957e5)
                    : pullRequest.isClosed
                        ? const Color(0xFFf85149)
                        : const Color(0xFF238636),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _copyUrl(context, pullRequest.url),
                  child: Text(
                    pullRequest.title,
                    style: const TextStyle(
                      color: Color(0xFF58a6ff),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (pullRequest.body != null && pullRequest.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pullRequest.body!.length > 150
                  ? '${pullRequest.body!.substring(0, 150)}...'
                  : pullRequest.body!,
              style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '+${pullRequest.additions}',
                style: const TextStyle(color: Color(0xFF238636), fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                '-${pullRequest.deletions}',
                style: const TextStyle(color: Color(0xFFf85149), fontSize: 12),
              ),
              const SizedBox(width: 8),
              _buildChangeIndicator(),
              const SizedBox(width: 8),
              const Text(
                'lines changed',
                style: TextStyle(color: Color(0xFF8b949e), fontSize: 12),
              ),
              if (pullRequest.commentsCount > 0) ...[
                const Spacer(),
                const Icon(Icons.comment_outlined, color: Color(0xFF8b949e), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${pullRequest.commentsCount} ${pullRequest.commentsCount == 1 ? 'comment' : 'comments'}',
                  style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeIndicator() {
    final total = pullRequest.additions + pullRequest.deletions;
    final addRatio = total > 0 ? pullRequest.additions / total : 0.5;
    
    return SizedBox(
      width: 50,
      height: 8,
      child: Row(
        children: [
          Expanded(
            flex: (addRatio * 100).round(),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF238636),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            flex: ((1 - addRatio) * 100).round(),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFf85149),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(2),
                  bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pull request repository item
class _PullRequestRepoItem extends StatelessWidget {
  final String repoName;
  final PullRequestStats stats;

  const _PullRequestRepoItem({
    required this.repoName,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              repoName,
              style: const TextStyle(color: Color(0xFF8b949e), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (stats.merged > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8957e5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${stats.merged} merged',
                style: const TextStyle(color: Color(0xFF8957e5), fontSize: 11),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (stats.closed > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFf85149).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${stats.closed} closed',
                style: const TextStyle(color: Color(0xFFf85149), fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reviews section
class _ReviewsSection extends StatefulWidget {
  final int totalReviews;
  final Map<String, int> reviewsByRepo;

  const _ReviewsSection({
    required this.totalReviews,
    required this.reviewsByRepo,
  });

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: Color(0xFF8b949e), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reviewed ${widget.totalReviews} pull ${widget.totalReviews == 1 ? 'request' : 'requests'} in ${widget.reviewsByRepo.length} ${widget.reviewsByRepo.length == 1 ? 'repository' : 'repositories'}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF8b949e),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.reviewsByRepo.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(left: 32, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Color(0xFF8b949e), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.value} pull ${entry.value == 1 ? 'request' : 'requests'}',
                  style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

/// Generic activity item
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: Color(0xFF8b949e), fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }
}