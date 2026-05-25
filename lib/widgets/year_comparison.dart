import 'package:flutter/material.dart';
import 'contribution_graph.dart';

/// Widget that displays year-over-year contribution comparison
class YearComparisonCard extends StatelessWidget {
  final Map<int, int>? yearlyData;
  final bool isLoading;
  final ColorTheme colorTheme;

  const YearComparisonCard({
    super.key,
    this.yearlyData,
    this.isLoading = false,
    this.colorTheme = ColorTheme.green,
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
            const Row(
              children: [
                Icon(Icons.calendar_month, color: Color(0xFF8b949e)),
                SizedBox(width: 8),
                Text(
                  'Year-over-Year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              _buildLoadingState()
            else if (yearlyData == null || yearlyData!.isEmpty)
              _buildEmptyState()
            else
              _buildComparisonContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No yearly data available',
          style: TextStyle(color: Color(0xFF8b949e)),
        ),
      ),
    );
  }

  Widget _buildComparisonContent() {
    // Sort years in descending order (most recent first)
    final sortedYears = yearlyData!.keys.toList()..sort((a, b) => b.compareTo(a));
    
    // Find the maximum contribution for scaling
    final maxContributions = yearlyData!.values.reduce((a, b) => a > b ? a : b);
    
    // Calculate growth percentage
    final growthInfo = _calculateGrowth(sortedYears);

    return Column(
      children: [
        // Bar chart
        ...sortedYears.map((year) => _buildYearBar(
          year: year,
          contributions: yearlyData![year]!,
          maxContributions: maxContributions,
          isCurrentYear: year == sortedYears.first,
        )),
        
        const SizedBox(height: 16),
        
        // Growth indicator
        if (growthInfo != null) _buildGrowthIndicator(growthInfo),
      ],
    );
  }

  Widget _buildYearBar({
    required int year,
    required int contributions,
    required int maxContributions,
    required bool isCurrentYear,
  }) {
    final percentage = maxContributions > 0 ? contributions / maxContributions : 0.0;
    final barColor = _getBarColor(isCurrentYear);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Year label
          SizedBox(
            width: 50,
            child: Text(
              year.toString(),
              style: TextStyle(
                color: isCurrentYear ? Colors.white : const Color(0xFF8b949e),
                fontWeight: isCurrentYear ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          
          // Bar
          Expanded(
            child: Stack(
              children: [
                // Background bar
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262d),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Filled bar
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          barColor.withOpacity(0.8),
                          barColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Contribution count
          SizedBox(
            width: 60,
            child: Text(
              _formatNumber(contributions),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isCurrentYear ? Colors.white : const Color(0xFF8b949e),
                fontWeight: isCurrentYear ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(bool isCurrentYear) {
    if (!isCurrentYear) {
      return const Color(0xFF484f58);
    }
    
    switch (colorTheme) {
      case ColorTheme.green:
        return GitHubColors.greenLevel4;
      case ColorTheme.blue:
        return GitHubColors.blueLevel4;
      case ColorTheme.yellow:
        return GitHubColors.yellowLevel4;
    }
  }

  Widget _buildGrowthIndicator(GrowthInfo growthInfo) {
    final isPositive = growthInfo.percentage >= 0;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final color = isPositive ? const Color(0xFF3fb950) : const Color(0xFFf85149);
    final sign = isPositive ? '+' : '';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$sign${growthInfo.percentage.toStringAsFixed(1)}% from ${growthInfo.comparedYear}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  GrowthInfo? _calculateGrowth(List<int> sortedYears) {
    if (sortedYears.length < 2) return null;
    
    final currentYear = sortedYears[0];
    final previousYear = sortedYears[1];
    
    final currentContributions = yearlyData![currentYear]!;
    final previousContributions = yearlyData![previousYear]!;
    
    if (previousContributions == 0) {
      return GrowthInfo(
        percentage: currentContributions > 0 ? 100.0 : 0.0,
        comparedYear: previousYear,
      );
    }
    
    final percentage = ((currentContributions - previousContributions) / previousContributions) * 100;
    
    return GrowthInfo(
      percentage: percentage,
      comparedYear: previousYear,
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}

/// Helper class to hold growth information
class GrowthInfo {
  final double percentage;
  final int comparedYear;

  GrowthInfo({
    required this.percentage,
    required this.comparedYear,
  });
}