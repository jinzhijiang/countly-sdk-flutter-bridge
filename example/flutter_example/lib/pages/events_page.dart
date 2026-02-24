import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _sdk = Countly.defaultInstance!;
  String _lastAction = '';

  @override
  void initState() {
    super.initState();
    _sdk.views.startAutoStoppedView('EventsPage');
  }

  void _showResult(String message) {
    setState(() => _lastAction = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Basic Events',
            [
              _buildButton('Record Simple Event', () async {
                await _sdk.events.record(key: 'button_click');
                _showResult('Recorded: button_click');
              }),
              _buildButton('Record Event with Count', () async {
                await _sdk.events.record(key: 'item_purchased', count: 5);
                _showResult('Recorded: item_purchased (count: 5)');
              }),
              _buildButton('Record Event with Sum', () async {
                await _sdk.events.record(key: 'purchase', sum: 29.99);
                _showResult('Recorded: purchase (sum: 29.99)');
              }),
              _buildButton('Record Event with Duration', () async {
                await _sdk.events.record(key: 'video_watched', dur: 120.5);
                _showResult('Recorded: video_watched (dur: 120.5s)');
              }),
            ],
          ),
          _buildSection(
            'Events with Segmentation',
            [
              _buildButton('String Segmentation', () async {
                await _sdk.events.record(
                  key: 'product_view',
                  segmentation: {
                    'product_id': 'SKU123',
                    'category': 'electronics',
                    'brand': 'TechBrand',
                  },
                );
                _showResult('Recorded: product_view with string values');
              }),
              _buildButton('Number Segmentation', () async {
                await _sdk.events.record(
                  key: 'game_score',
                  segmentation: {
                    'level': 5,
                    'score': 1500,
                    'accuracy': 95.5,
                    'time_spent': 120.75,
                  },
                );
                _showResult('Recorded: game_score with number values');
              }),
              _buildButton('Boolean Segmentation', () async {
                await _sdk.events.record(
                  key: 'settings_changed',
                  segmentation: {
                    'notifications_enabled': true,
                    'dark_mode': false,
                    'auto_save': true,
                  },
                );
                _showResult('Recorded: settings_changed with boolean values');
              }),
              _buildButton('List Segmentation', () async {
                await _sdk.events.record(
                  key: 'cart_checkout',
                  segmentation: {
                    'items': ['SKU001', 'SKU002', 'SKU003'],
                    'categories': ['electronics', 'books'],
                    'quantities': [1, 2, 1],
                  },
                );
                _showResult('Recorded: cart_checkout with list values');
              }),
              _buildButton('Mixed Segmentation', () async {
                await _sdk.events.record(
                  key: 'complex_event',
                  count: 1,
                  sum: 99.99,
                  dur: 30.0,
                  segmentation: {
                    'string_val': 'hello',
                    'int_val': 42,
                    'double_val': 3.14,
                    'bool_val': true,
                    'list_val': ['a', 'b', 'c'],
                    'int_list': [1, 2, 3],
                  },
                );
                _showResult('Recorded: complex_event with mixed values');
              }),
            ],
          ),
          _buildSection(
            'Full Event Examples',
            [
              _buildButton('E-commerce Purchase', () async {
                await _sdk.events.record(
                  key: 'purchase_completed',
                  count: 1,
                  sum: 149.99,
                  segmentation: {
                    'product_id': 'PROD-12345',
                    'product_name': 'Wireless Headphones',
                    'category': 'Electronics',
                    'payment_method': 'credit_card',
                    'currency': 'USD',
                    'discount_applied': true,
                    'discount_percent': 10.0,
                  },
                );
                _showResult('Recorded: purchase_completed');
              }),
              _buildButton('User Action', () async {
                await _sdk.events.record(
                  key: 'user_action',
                  count: 1,
                  dur: 2.5,
                  segmentation: {
                    'action_type': 'swipe',
                    'direction': 'left',
                    'screen': 'gallery',
                    'item_index': 3,
                  },
                );
                _showResult('Recorded: user_action');
              }),
              _buildButton('Error Event', () async {
                await _sdk.events.record(
                  key: 'app_error',
                  segmentation: {
                    'error_type': 'network_timeout',
                    'error_code': 408,
                    'endpoint': '/api/data',
                    'retry_count': 3,
                    'is_fatal': false,
                  },
                );
                _showResult('Recorded: app_error');
              }),
            ],
          ),
          _buildSection(
            'Metrics',
            [
              _buildButton('Record Device Metrics', () async {
                await _sdk.events.recordMetrics();
                _showResult('Recorded: device metrics');
              }),
              _buildButton('Record Metrics with Override', () async {
                await _sdk.events.recordMetrics(
                  metricOverride: {
                    '_app_version': '2.0.0',
                    'custom_metric': 'value',
                  },
                );
                _showResult('Recorded: metrics with override');
              }),
            ],
          ),
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Action',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(_lastAction.isEmpty ? 'No action yet' : _lastAction),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}
