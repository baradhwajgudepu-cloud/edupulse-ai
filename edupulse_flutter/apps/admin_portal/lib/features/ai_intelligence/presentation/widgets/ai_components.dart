import 'package:flutter/material.dart';

class AIRiskBadge extends StatelessWidget {
  final String tier;
  final int? confidenceScore;

  const AIRiskBadge({
    super.key,
    required this.tier,
    this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = tier.toUpperCase() == 'HIGH';
    final isMed = tier.toUpperCase() == 'MEDIUM';

    final bgColor = isHigh ? Colors.red.shade50 : (isMed ? Colors.amber.shade50 : Colors.green.shade50);
    final borderColor = isHigh ? Colors.red.shade300 : (isMed ? Colors.amber.shade300 : Colors.green.shade300);
    final textColor = isHigh ? Colors.red.shade900 : (isMed ? Colors.amber.shade900 : Colors.green.shade900);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHigh ? Icons.crisis_alert : (isMed ? Icons.warning_amber_rounded : Icons.check_circle_outline),
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$tier RISK',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
          if (confidenceScore != null) ...[
            const SizedBox(width: 4),
            Text(
              '($confidenceScore% confidence)',
              style: TextStyle(fontSize: 10, color: textColor.withAlpha(200)),
            ),
          ],
        ],
      ),
    );
  }
}

class AITrendIndicator extends StatelessWidget {
  final String direction;
  final double delta;

  const AITrendIndicator({
    super.key,
    required this.direction,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = direction.toUpperCase() == 'IMPROVING' || delta > 0;
    final isDown = direction.toUpperCase() == 'DECLINING' || delta < 0;

    final color = isUp ? Colors.green : (isDown ? Colors.red : Colors.grey);
    final icon = isUp ? Icons.trending_up : (isDown ? Icons.trending_down : Icons.trending_flat);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }
}

class AIAlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  const AIAlertBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.psychology_outlined,
    this.color = Colors.purple,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class AIInsightCard extends StatelessWidget {
  final String title;
  final String metricLabel;
  final String metricValue;
  final String insightDescription;
  final List<Widget> actions;
  final Color accentColor;

  const AIInsightCard({
    super.key,
    required this.title,
    required this.metricLabel,
    required this.metricValue,
    required this.insightDescription,
    this.actions = const [],
    this.accentColor = Colors.purple,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(metricLabel, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text(metricValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insightDescription,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
