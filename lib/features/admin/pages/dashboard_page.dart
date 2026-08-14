import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/group.dart';
import '../../../shared/widgets/widgets.dart';
import '../providers/admin_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final stats = state.stats;
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading && stats == null) {
      return const Center(child: LoadingIndicator());
    }

    if (stats == null) {
      return ErrorState(
        message: state.error ?? '加载失败',
        onRetry: () => ref.read(dashboardProvider.notifier).loadStats(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardProvider.notifier).loadStats(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '实时在线',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '在线（在网站上）',
                  value: '${stats.onlineNow}',
                  icon: Icons.public,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '咨询中（已打开 Chat）',
                  value: '${stats.consultingNow}',
                  icon: Icons.chat,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '今日数据',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                title: '今日会话',
                value: '${stats.conversationsToday}',
                icon: Icons.forum,
                color: colorScheme.primary,
              ),
              _StatCard(
                title: '今日消息',
                value: '${stats.messagesToday}',
                icon: Icons.message,
                color: AppTheme.infoColor,
              ),
              _StatCard(
                title: '今日访客',
                value: '${stats.visitorsToday}',
                icon: Icons.people,
                color: AppTheme.secondaryColor,
              ),
              _StatCard(
                title: '今日转化',
                value: '${stats.conversionsToday}',
                icon: Icons.trending_up,
                color: AppTheme.warningColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.pie_chart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          '今日转化率',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${stats.conversationsToday} 会话 · ${stats.conversionsToday} 转化',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${stats.conversionRate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '近 14 天趋势',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '会话与消息数量（含今日）',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                children: [
                  _TrendLegend(
                    primaryLabel: '会话',
                    primaryColor: colorScheme.primary,
                    secondaryLabel: '消息',
                    secondaryColor: AppTheme.infoColor,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: stats.trend.isEmpty
                        ? const Center(child: Text('暂无数据'))
                        : _TrendChart(trend: stats.trend),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  final String primaryLabel;
  final Color primaryColor;
  final String secondaryLabel;
  final Color secondaryColor;

  const _TrendLegend({
    required this.primaryLabel,
    required this.primaryColor,
    required this.secondaryLabel,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _legendDot(primaryColor, primaryLabel),
        const SizedBox(width: 16),
        _legendDot(secondaryColor, secondaryLabel),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<DashboardTrendPoint> trend;

  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendChartPainter(
        trend: trend,
        conversationsColor: Theme.of(context).colorScheme.primary,
        messagesColor: AppTheme.infoColor,
        axisColor: Theme.of(context).colorScheme.outlineVariant,
        labelStyle: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<DashboardTrendPoint> trend;
  final Color conversationsColor;
  final Color messagesColor;
  final Color axisColor;
  final TextStyle labelStyle;

  _TrendChartPainter({
    required this.trend,
    required this.conversationsColor,
    required this.messagesColor,
    required this.axisColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0;
    const rightPad = 8.0;
    const topPad = 12.0;
    const bottomPad = 22.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    var maxValue = 0;
    for (final point in trend) {
      if (point.conversations > maxValue) maxValue = point.conversations;
      if (point.messages > maxValue) maxValue = point.messages;
    }
    if (maxValue == 0) maxValue = 1;

    double xFor(int index) {
      final step = trend.length > 1 ? chartWidth / (trend.length - 1) : 0.0;
      return leftPad + index * step;
    }

    double yFor(int value) {
      return topPad + chartHeight - (value / maxValue) * chartHeight;
    }

    final baseline = topPad + chartHeight;

    // Grid lines (0, mid, max).
    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = baseline - fraction * chartHeight;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + chartWidth, y),
        gridPaint,
      );
    }

    // Baseline.
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPad, baseline),
      Offset(leftPad + chartWidth, baseline),
      axisPaint,
    );

    _drawSeries(
      canvas,
      trend.map((p) => p.conversations).toList(),
      xFor,
      yFor,
      conversationsColor,
    );
    _drawSeries(
      canvas,
      trend.map((p) => p.messages).toList(),
      xFor,
      yFor,
      messagesColor,
    );

    // X-axis labels (first, middle, last).
    if (trend.isNotEmpty) {
      final indices = <int>{
        0,
        if (trend.length > 2) (trend.length / 2).floor(),
        trend.length - 1,
      };
      for (final index in indices) {
        final painter = TextPainter(
          text: TextSpan(text: _shortDate(trend[index].date), style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = (xFor(index) - painter.width / 2)
            .clamp(0.0, size.width - painter.width);
        painter.paint(canvas, Offset(dx, baseline + 6));
      }
    }
  }

  void _drawSeries(
    Canvas canvas,
    List<int> values,
    double Function(int) xFor,
    double Function(int) yFor,
    Color color,
  ) {
    if (values.isEmpty) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final offset = Offset(xFor(i), yFor(values[i]));
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(xFor(values.length - 1), yFor(0) + (yFor(values[0]) - yFor(0)))
      ..lineTo(xFor(0), yFor(0))
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(values[i])), 2.5, dotPaint);
    }
  }

  String _shortDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.trend != trend ||
        oldDelegate.conversationsColor != conversationsColor ||
        oldDelegate.messagesColor != messagesColor;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
