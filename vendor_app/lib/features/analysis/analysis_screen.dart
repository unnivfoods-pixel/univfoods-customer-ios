import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  List<double> _revenueTrend = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _topSellers = [];
  Map<String, dynamic> _feedback = {
    'rating': 5.0,
    'reviews': 0,
    'returning': '0%',
    'prep': '0m'
  };
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
    _subscribeToSales();

    // FAILSAFE
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });
  }

  void _subscribeToSales() {
    SupabaseConfig.client
        .channel('analysis_updates')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) => _fetchAnalysisData())
        .subscribe();
  }

  Future<void> _fetchAnalysisData() async {
    final user = SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _revenueTrend = [1200, 1500, 800, 2100, 1900, 3200, 2800];
          _topSellers = [
            {'name': 'Royal Saffron Biryani', 'count': 45, 'revenue': 11250},
            {'name': 'Gourmet Butter Chicken', 'count': 32, 'revenue': 10240},
            {'name': 'Signature Garlic Naan', 'count': 28, 'revenue': 5040},
          ];
          _feedback = {
            'rating': 4.9,
            'reviews': 124,
            'returning': '72%',
            'prep': '14m'
          };
          _walletBalance = 12450.50;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final vendorRes = await SupabaseConfig.client
          .from('vendors')
          .select('id, rating, review_count, wallet_balance')
          .eq('owner_id', user.id)
          .single()
          .timeout(const Duration(seconds: 5));

      final vendorId = vendorRes['id'];
      final walletBalance = (vendorRes['wallet_balance'] ?? 0.0).toDouble();

      final sevenDaysAgo =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final orderRes = await SupabaseConfig.client
          .from('orders')
          .select('total, created_at, items')
          .eq('vendor_id', vendorId)
          .gte('created_at', sevenDaysAgo);

      final orders = List<Map<String, dynamic>>.from(orderRes);

      List<double> trend = [0, 0, 0, 0, 0, 0, 0];
      Map<String, int> productCounts = {};
      Map<String, double> productRevenue = {};

      for (var o in orders) {
        final date = DateTime.parse(o['created_at']);
        final dayDiff = DateTime.now().difference(date).inDays;
        if (dayDiff >= 0 && dayDiff < 7) {
          trend[6 - dayDiff] += (o['total'] ?? 0).toDouble();
        }

        final items = o['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          final name = item['name'] as String;
          productCounts[name] =
              (productCounts[name] ?? 0) + (item['qty'] as int);
          productRevenue[name] = (productRevenue[name] ?? 0) +
              (item['price'] * item['qty']).toDouble();
        }
      }

      var sortedKeys = productCounts.keys.toList()
        ..sort((a, b) => productCounts[b]!.compareTo(productCounts[a]!));

      List<Map<String, dynamic>> topArr = [];
      for (var i = 0; i < sortedKeys.length && i < 3; i++) {
        final key = sortedKeys[i];
        topArr.add({
          'name': key,
          'count': productCounts[key],
          'revenue': productRevenue[key],
        });
      }

      if (mounted) {
        setState(() {
          _revenueTrend = trend;
          _topSellers = topArr;
          _feedback = {
            'rating': vendorRes['rating'] ?? 5.0,
            'reviews': vendorRes['review_count'] ?? 0,
            'returning': orders.isEmpty ? '0%' : '65%',
            'prep': '14m'
          };
          _walletBalance = walletBalance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeletonAnalysis();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TODAY'S PULSE", style: ProTheme.label),
              IconButton(
                  onPressed: _downloadReport,
                  icon: const Icon(LucideIcons.downloadCloud,
                      color: ProTheme.primary, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTodaySummary(),
          const SizedBox(height: 32),
          _buildBalanceCard(),
          const SizedBox(height: 32),
          _buildRevenueChart(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ASSET PERFORMANCE", style: ProTheme.label),
              Text("Last 7 Days",
                  style: ProTheme.label.copyWith(color: ProTheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          if (_topSellers.isEmpty)
            _emptyState("Awaiting operational data for mapping.")
          else
            ..._topSellers.map((item) => _buildTopItem(item)),
          const SizedBox(height: 32),
          Text("OPERATIONAL QUALITY", style: ProTheme.label),
          const SizedBox(height: 16),
          _buildMetricsCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _downloadReport() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Generating Settlement CSV...")));
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ProTheme.cardDecor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("₹${_revenueTrend.last.toInt()}", "TODAY SALES"),
          _statItem("${_topSellers.length}", "NEW ORDERS"),
          _statItem("4.8", "SLA"),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val,
            style: ProTheme.header
                .copyWith(fontSize: 20, color: ProTheme.primary)),
        Text(label, style: ProTheme.label.copyWith(fontSize: 8)),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ProTheme.dark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: ProTheme.intenseShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SETTLED CAPITAL",
                      style: ProTheme.label
                          .copyWith(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 8),
                  Text("₹${_walletBalance.toStringAsFixed(2)}",
                      style: ProTheme.header
                          .copyWith(color: Colors.white, fontSize: 32)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ProTheme.primary.withOpacity(0.1),
                  border: Border.all(color: ProTheme.primary.withOpacity(0.3)),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.wallet,
                    color: ProTheme.primary, size: 24),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ProTheme.secondaryButton,
              child: Text("REQUEST SETTLEMENT",
                  style: ProTheme.button.copyWith(fontSize: 12)),
            ),
          )
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1, end: 0);
  }

  Widget _buildRevenueChart() {
    final maxRev = _revenueTrend.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 280,
      padding: const EdgeInsets.all(28),
      decoration: ProTheme.cardDecor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("REVENUE TRAJECTORY", style: ProTheme.label),
              const Icon(LucideIcons.barChart3, size: 16, color: ProTheme.gray),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final height =
                  maxRev > 0 ? (140 * (_revenueTrend[i] / maxRev)) : 5.0;
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: height < 5 ? 5 : height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ProTheme.primary,
                          ProTheme.primary.withOpacity(0.5)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ).animate().scaleY(delay: (i * 100).ms, begin: 0, end: 1),
                  const SizedBox(height: 12),
                  Text(
                    [
                      "M",
                      "T",
                      "W",
                      "T",
                      "F",
                      "S",
                      "S"
                    ][(DateTime.now().weekday - 7 + i) % 7],
                    style: ProTheme.label.copyWith(fontSize: 10),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildTopItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: ProTheme.cardDecor,
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: ProTheme.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.flame,
                color: ProTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'],
                    style: ProTheme.title.copyWith(fontSize: 16)),
                Text("${item['count']} Units Mission",
                    style: ProTheme.body.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text("₹${item['revenue'].toInt()}",
              style: ProTheme.header
                  .copyWith(fontSize: 18, color: ProTheme.secondary)),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildMetricsCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ProTheme.dark.withOpacity(0.02),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ProTheme.dark.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                    color: ProTheme.dark, shape: BoxShape.circle),
                child: const Icon(LucideIcons.star,
                    color: ProTheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${_feedback['rating']}",
                      style: ProTheme.header.copyWith(fontSize: 32)),
                  Text("GLOBAL USER RATING",
                      style: ProTheme.label.copyWith(fontSize: 9)),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricTile(_feedback['returning'], "LOYALTY", LucideIcons.users),
              _metricTile(_feedback['prep'], "PULSE", LucideIcons.timer),
              _metricTile("4.9", "TASTE", LucideIcons.utensils),
            ],
          )
        ],
      ),
    );
  }

  Widget _metricTile(String val, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: ProTheme.gray.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text(val, style: ProTheme.title.copyWith(fontSize: 18)),
        Text(label,
            style: ProTheme.label.copyWith(fontSize: 8, color: ProTheme.gray)),
      ],
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(LucideIcons.activity,
                color: ProTheme.gray.withOpacity(0.2), size: 48),
            const SizedBox(height: 16),
            Text(msg, style: ProTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonAnalysis() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: Column(
        children: List.generate(
                4,
                (i) => Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ))
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1500.ms),
      ),
    );
  }
}
