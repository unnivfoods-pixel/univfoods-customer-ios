import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/pro_theme.dart';
import '../../core/supabase_config.dart';

class SettlementsScreen extends StatefulWidget {
  final String vendorId;
  const SettlementsScreen({super.key, required this.vendorId});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  double _walletBalance = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFinancials();
  }

  Future<void> _fetchFinancials() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final walletRes = await SupabaseConfig.client
          .from('wallets')
          .select('balance')
          .eq('user_id', user.id)
          .eq('role', 'VENDOR')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _walletBalance = (walletRes?['balance'] ?? 0.0).toDouble();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    if (_walletBalance < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Protocol Error: Minimum capital threshold for settlement is ₹500."),
          backgroundColor: ProTheme.error,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Text("Initiate Settlement?", style: ProTheme.title),
        content: Text(
            "A capital transfer of ₹${_walletBalance.toStringAsFixed(2)} will be dispatched to your linked node account.",
            style: ProTheme.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("ABORT",
                  style: ProTheme.label.copyWith(color: ProTheme.gray))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ProTheme.ctaButton.copyWith(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
            child: const Text("EXECUTE TRANSFER"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseConfig.client.from('withdrawal_requests').insert({
        'user_id': user.id,
        'user_type': 'VENDOR',
        'amount': _walletBalance,
        'status': 'PENDING'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Settlement sequence initiated."),
              backgroundColor: ProTheme.secondary),
        );
        _fetchFinancials();
      }
    } catch (e) {
      debugPrint("Payout error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = SupabaseConfig.client.auth.currentUser;

    return Scaffold(
      backgroundColor: ProTheme.bg,
      appBar: AppBar(
        title: Text("CAPITAL PORTAL",
            style: ProTheme.header.copyWith(fontSize: 20)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFinancials,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCapitalHero(),
              const SizedBox(height: 40),
              Text("TRANSACTION REPOSITORY",
                  style: ProTheme.label
                      .copyWith(fontSize: 10, color: ProTheme.gray)),
              const SizedBox(height: 16),
              if (user != null)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseConfig.client
                      .from('withdrawal_requests')
                      .stream(primaryKey: ['id'])
                      .eq('user_id', user.id)
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    final withdrawals = snapshot.data ?? [];
                    if (withdrawals.isEmpty) return _buildEmptyState();
                    return Column(
                      children: withdrawals
                          .map((s) => _buildSettlementTile(s))
                          .toList(),
                    );
                  },
                )
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapitalHero() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: ProTheme.dark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: ProTheme.intenseShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: ProTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: const Icon(LucideIcons.landmark,
                color: ProTheme.primary, size: 28),
          ),
          const SizedBox(height: 24),
          Text("SETTLED LIQUIDITY",
              style: ProTheme.label.copyWith(
                  color: Colors.white54, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text("₹${_walletBalance.toStringAsFixed(2)}",
              style:
                  ProTheme.header.copyWith(color: Colors.white, fontSize: 44)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _requestPayout,
              style: ProTheme.secondaryButton,
              child: Text("DISPATCH TO BANK", style: ProTheme.button),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.refreshCw,
                  size: 12, color: Colors.white24),
              const SizedBox(width: 8),
              Text("PROTOCOL CYCLE: DAILY (T+1)",
                  style: ProTheme.label
                      .copyWith(color: Colors.white24, fontSize: 9)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: ProTheme.cardDecor,
      child: Column(
        children: [
          Icon(LucideIcons.folderX,
              color: ProTheme.gray.withOpacity(0.2), size: 48),
          const SizedBox(height: 20),
          Text("No prior capital movements detected.",
              style: ProTheme.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSettlementTile(Map<String, dynamic> s) {
    final status = s['status'].toString().toUpperCase();
    final date = DateTime.parse(s['created_at']).toLocal();
    final isProcessed = status == 'COMPLETE';
    final isFailed = status == 'FAIL';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: ProTheme.cardDecor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isProcessed
                  ? ProTheme.secondary.withOpacity(0.1)
                  : isFailed
                      ? ProTheme.error.withOpacity(0.1)
                      : ProTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isProcessed
                  ? LucideIcons.checkCircle2
                  : (isFailed ? LucideIcons.xCircle : LucideIcons.clock8),
              color: isProcessed
                  ? ProTheme.secondary
                  : (isFailed ? ProTheme.error : ProTheme.warning),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Capital Transfer",
                    style: ProTheme.title.copyWith(fontSize: 15)),
                Text(
                    "${date.day}/${date.month} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                    style: ProTheme.label
                        .copyWith(fontSize: 9, color: ProTheme.gray)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹${s['amount']}",
                  style: ProTheme.header
                      .copyWith(fontSize: 18, color: ProTheme.dark)),
              Text(status,
                  style: ProTheme.label.copyWith(
                    fontSize: 8,
                    color: isProcessed
                        ? ProTheme.secondary
                        : (isFailed ? ProTheme.error : ProTheme.warning),
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05, end: 0);
  }
}
