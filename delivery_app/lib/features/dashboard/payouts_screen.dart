import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  String? _riderId;

  @override
  void initState() {
    super.initState();
    _riderId = SupabaseConfig.client.auth.currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    if (_riderId == null)
      return const Center(child: Text("AUTHENTICATION_REQUIRED"));

    return Scaffold(
      backgroundColor: ProTheme.bg,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseConfig.client
            .from('wallets')
            .stream(primaryKey: ['id'])
            .eq('user_id', _riderId!)
            .limit(1),
        builder: (context, walletSnapshot) {
          final wallet = walletSnapshot.data?.firstOrNull;
          final balance = (wallet?['balance'] ?? 0.0).toDouble();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseConfig.client
                .from('delivery_riders')
                .stream(primaryKey: ['id'])
                .eq('id', _riderId!)
                .limit(1),
            builder: (context, riderSnapshot) {
              final rider = riderSnapshot.data?.firstOrNull;
              final codHeld = (rider?['cod_held'] ?? 0.0).toDouble();

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                backgroundColor: ProTheme.primary,
                color: ProTheme.dark,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 250),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildCapitalHero(balance, codHeld),
                            const SizedBox(height: 24),
                            _buildDebtCard(codHeld),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("TRANSACTION LOG", style: ProTheme.label),
                                TextButton(
                                  onPressed: () {},
                                  child: Text("VIEW ARCHIVE",
                                      style: ProTheme.label.copyWith(
                                          color: ProTheme.primary,
                                          fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildWithdrawalLogs(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCapitalHero(double balance, double codHeld) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ProTheme.slate,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: ProTheme.slate.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("LIQUID CAPITAL",
                  style: ProTheme.label
                      .copyWith(color: Colors.white54, fontSize: 10)),
              const Icon(LucideIcons.landmark,
                  color: ProTheme.primary, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text("₹${balance.toInt()}",
              style: ProTheme.header.copyWith(
                  fontSize: 48, color: ProTheme.pureWhite, letterSpacing: -2)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (balance >= 500 && codHeld == 0)
                  ? () => _withdraw(balance)
                  : null,
              style: ProTheme.ctaButton.copyWith(
                backgroundColor: WidgetStatePropertyAll(
                    (balance >= 500 && codHeld == 0)
                        ? ProTheme.primary
                        : ProTheme.gray.withOpacity(0.2)),
              ),
              child: Text(
                  (codHeld > 0) ? "CLEAR DEBT TO DISPATCH" : "DISPATCH TO BANK",
                  style: ProTheme.button),
            ),
          ),
          if (balance < 500 || codHeld > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                  codHeld > 0
                      ? "MISSION ALERT: Clear COD debt to enable withdrawal"
                      : "Min. ₹500 required for manual dispatch",
                  textAlign: TextAlign.center,
                  style: ProTheme.body.copyWith(
                      fontSize: 10,
                      color: codHeld > 0 ? ProTheme.error : Colors.white38)),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDebtCard(double codHeld) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ProTheme.cardDecor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ProTheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.alertTriangle,
                color: ProTheme.error, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CASH DEBT (COD)",
                    style: ProTheme.label.copyWith(fontSize: 10)),
                Text("₹${codHeld.toInt()}",
                    style: ProTheme.title.copyWith(color: ProTheme.error)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: codHeld > 0 ? () => _depositCash(codHeld) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ProTheme.dark,
              foregroundColor: ProTheme.pureWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text("CLEAR",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildWithdrawalLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client
          .from('withdrawal_requests')
          .stream(primaryKey: ['id'])
          .eq('user_id', _riderId!)
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty) return _buildEmptyState();
        return Column(
          children: list.map((s) => _buildLogTile(s)).toList(),
        );
      },
    );
  }

  Widget _buildLogTile(Map<String, dynamic> s) {
    final status = s['status'].toString().toUpperCase();
    final isComplete = status == 'COMPLETE';
    final isFailed = status == 'FAIL';
    final date = DateTime.parse(s['created_at']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: ProTheme.cardDecor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isComplete
                      ? ProTheme.secondary
                      : (isFailed ? ProTheme.error : Colors.orange))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                isComplete
                    ? LucideIcons.checkCircle
                    : (isFailed ? LucideIcons.xCircle : LucideIcons.timer),
                color: isComplete
                    ? ProTheme.secondary
                    : (isFailed ? ProTheme.error : Colors.orange),
                size: 18),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CAPITAL DISPATCH",
                    style: ProTheme.title.copyWith(fontSize: 14)),
                Text(
                    "${date.day}/${date.month} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                    style: ProTheme.body.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹${s['amount']}",
                  style: ProTheme.header.copyWith(fontSize: 16)),
              Text(status,
                  style: ProTheme.label.copyWith(
                      fontSize: 8,
                      color: isComplete
                          ? ProTheme.secondary
                          : (isFailed ? ProTheme.error : Colors.orange))),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(LucideIcons.database,
              color: ProTheme.gray.withOpacity(0.2), size: 48),
          const SizedBox(height: 16),
          Text("NO LOGS DETECTED", style: ProTheme.body),
        ],
      ),
    );
  }

  void _withdraw(double amount) async {
    try {
      await SupabaseConfig.client.from('withdrawal_requests').insert({
        'user_id': _riderId,
        'user_type': 'RIDER',
        'amount': amount,
        'status': 'PENDING'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("DISPATCH INITIATED: PROCESSING..."),
            backgroundColor: ProTheme.secondary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("DISPATCH FAULT: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _depositCash(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("CLEAR COD DEBT?", style: ProTheme.title),
        content: Text(
            "Proceed to clear cash debt of ₹${amount.toInt()}?\nEnsure physical deposit is completed."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseConfig.client.rpc('driver_deposit_cod', params: {
                'p_driver_id': _riderId,
                'p_amount': amount,
              });
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: ProTheme.dark, foregroundColor: Colors.white),
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }
}
