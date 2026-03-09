import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableOrders();
    _subscribeToOrders();
  }

  Future<void> _fetchAvailableOrders() async {
    try {
      final data = await SupabaseConfig.client
          .from('orders')
          .select('*, vendors(name, address)')
          .eq('status', 'READY_FOR_PICKUP')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToOrders() {
    SupabaseConfig.client
        .channel('delivery_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'READY_FOR_PICKUP',
          ),
          callback: (payload) {
            _fetchAvailableOrders();
          },
        )
        .subscribe();
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await SupabaseConfig.client.from('orders').update({
        'status': 'RIDER_ASSIGNED',
        'rider_id': SupabaseConfig.client.auth.currentUser?.id
      }).eq('id', orderId);

      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order Accepted!')));
      _fetchAvailableOrders();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Deliveries')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No deliveries available right now.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final vendor = order['vendors'];
                    // Supabase join returns vendor as a map if single, depends on query.
                    // Using basic fetch logic earlier, here assuming simple structure.

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Order #${order['id'].toString().substring(0, 6)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('Ready for Pickup',
                                      style: TextStyle(color: Colors.green)),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.store,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                    vendor != null
                                        ? vendor['name']
                                        : 'Unknown Vendor',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (vendor != null && vendor['address'] != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 24, top: 4),
                                child: Text(vendor['address'],
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Earning',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                    Text(
                                        '₹${(order['total'] * 0.1).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => _acceptOrder(order['id']),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00B894)),
                                  child: const Text('Accept Delivery'),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
