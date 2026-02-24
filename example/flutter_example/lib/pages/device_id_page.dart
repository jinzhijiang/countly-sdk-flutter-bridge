import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly.dart';

class DeviceIdPage extends StatefulWidget {
  const DeviceIdPage({super.key});

  @override
  State<DeviceIdPage> createState() => _DeviceIdPageState();
}

class _DeviceIdPageState extends State<DeviceIdPage> {
  final _sdk = Countly.defaultInstance!;
  final _deviceIdController = TextEditingController();
  final List<String> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    _sdk.views.startAutoStoppedView('DeviceIdPage');
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  void _addAction(String action) {
    setState(() {
      _actionHistory.insert(0, '${DateTime.now().toString().substring(11, 19)}: $action');
      if (_actionHistory.length > 20) {
        _actionHistory.removeLast();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(action)),
    );
  }

  String _getDeviceIdTypeName(int? type) {
    switch (type) {
      case 1:
        return 'Provided (Developer)';
      case 2:
        return 'Generated (SDK)';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device ID'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Device ID',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _sdk.deviceId ?? 'Not available',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type: ${_getDeviceIdTypeName(_sdk.deviceIdType)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Important',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.amber.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Change with Merge: Use when the same user gets a new ID (e.g., login)\n'
                    '• Change without Merge: Use for a completely new user (e.g., logout)\n'
                    '• Without merge enters unknown consent state - call giveConsent() to resume',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Change Device ID',
            [
              TextField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'New Device ID',
                  hintText: 'Enter a new device ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newId = _deviceIdController.text.trim();
                        if (newId.isEmpty) {
                          _addAction('Error: Device ID cannot be empty');
                          return;
                        }
                        await _sdk.id.changeWithMerge(newId);
                        setState(() {});
                        _addAction('Changed with merge to: $newId');
                      },
                      icon: const Icon(Icons.merge),
                      label: const Text('With Merge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newId = _deviceIdController.text.trim();
                        if (newId.isEmpty) {
                          _addAction('Error: Device ID cannot be empty');
                          return;
                        }
                        await _sdk.id.changeWithoutMerge(newId);
                        setState(() {});
                        _addAction('Changed without merge to: $newId');
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Without Merge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildSection(
            'Quick Actions',
            [
              _buildButton('Change to User ID (with merge)', () async {
                await _sdk.id.changeWithMerge('user_12345');
                setState(() {});
                _addAction('Merged to: user_12345');
              }),
              _buildButton('Change to Anonymous (without merge)', () async {
                final anonId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
                await _sdk.id.changeWithoutMerge(anonId);
                setState(() {});
                _addAction('New anonymous: $anonId');
              }),
              _buildButton('Give Consent (after without merge)', () async {
                await _sdk.consents.giveConsent();
                _addAction('Consent granted');
              }),
            ],
          ),
          _buildSection(
            'Simulate Login/Logout Flow',
            [
              _buildButton('Simulate User Login', () async {
                // User logs in - change to their user ID with merge
                await _sdk.id.changeWithMerge('user_john_doe');

                // Set user properties
                await _sdk.users.setProperties({
                  'name': 'John Doe',
                  'email': 'john@example.com',
                });

                // Track login event
                await _sdk.events.record(
                  key: 'user_login',
                  segmentation: {'method': 'email'},
                );

                setState(() {});
                _addAction('User logged in as john_doe');
              }),
              _buildButton('Simulate User Logout', () async {
                // Track logout event first
                await _sdk.events.record(key: 'user_logout');
                // ignore: invalid_use_of_visible_for_testing_member
                await _sdk.processEventsAndRequests();

                // Change to new anonymous ID
                final anonId = 'anon_${DateTime.now().millisecondsSinceEpoch}';
                await _sdk.id.changeWithoutMerge(anonId);

                // Give consent to continue tracking anonymous user
                await _sdk.consents.giveConsent();

                setState(() {});
                _addAction('User logged out - new anonymous session');
              }),
            ],
          ),
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
                      Text(
                        'Action Log',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _actionHistory.clear()),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_actionHistory.isEmpty)
                    const Text('No actions yet')
                  else
                    ..._actionHistory.take(10).map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(entry),
                          ),
                        ),
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
