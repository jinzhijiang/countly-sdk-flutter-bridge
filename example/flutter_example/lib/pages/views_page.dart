import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly.dart';

class ViewsPage extends StatefulWidget {
  const ViewsPage({super.key});

  @override
  State<ViewsPage> createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> {
  final _sdk = Countly.defaultInstance!;
  String _currentView = '';
  final List<String> _viewHistory = [];

  @override
  void initState() {
    super.initState();
    _startView('ViewsPage');
  }

  void _startView(String viewName) {
    _sdk.views.startAutoStoppedView(viewName, segmentation: {'source': 'demo_page'});
    setState(() {
      _currentView = viewName;
      _viewHistory.add('Started: $viewName');
    });
  }

  void _showResult(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Views'), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current View', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_currentView.isEmpty ? 'No active view' : _currentView, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection('Auto-Stopped Views', [
            _buildButton('Start "Dashboard" View', () {
              _startView('Dashboard');
              _showResult('Started Dashboard view');
            }),
            _buildButton('Start "Profile" View', () {
              _startView('Profile');
              _showResult('Started Profile view (ended Dashboard)');
            }),
            _buildButton('Start "Settings" View', () {
              _startView('Settings');
              _showResult('Started Settings view');
            }),
            _buildButton('Start "Analytics" View', () {
              _startView('Analytics');
              _showResult('Started Analytics view');
            }),
          ]),
          _buildSection('Manual View Control', [
            _buildButton('End Active View', () async {
              await _sdk.views.endActiveView(segmentation: {'exit': 'manual'});
              setState(() {
                _viewHistory.add('Ended: $_currentView');
                _currentView = '';
              });
              _showResult('Ended active view');
            }),
          ]),
          _buildSection('Simulated Navigation', [
            _buildButton('Simulate User Flow', () async {
              _startView('Home');
              await Future.delayed(const Duration(milliseconds: 500));
              _startView('Products');
              await Future.delayed(const Duration(milliseconds: 500));
              _startView('ProductDetails');
              await Future.delayed(const Duration(milliseconds: 500));
              _startView('Cart');
              await Future.delayed(const Duration(milliseconds: 500));
              _startView('Checkout');
              _showResult('Simulated navigation flow');
            }),
          ]),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('View History', style: Theme.of(context).textTheme.titleSmall),
                      TextButton(onPressed: () => setState(() => _viewHistory.clear()), child: const Text('Clear')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_viewHistory.isEmpty) const Text('No views recorded yet') else ..._viewHistory.reversed.take(10).map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(entry))),
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
          child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
