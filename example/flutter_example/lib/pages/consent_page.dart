import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  final _sdk = Countly.defaultInstance!;
  final List<String> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    _sdk.views.startAutoStoppedView('ConsentPage');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consent Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'About Consent',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.blue.shade700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consent controls whether the SDK collects and sends data. '
                    'When consent is revoked, all queued data is cleared.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Consent Actions',
            [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _sdk.consents.giveConsent();
                            _addAction('Consent GRANTED');
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Give Consent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _sdk.consents.revokeConsent();
                            _addAction('Consent REVOKED - Data cleared');
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Revoke Consent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            'Test Consent Behavior',
            [
              _buildButton('Try Recording Event', () async {
                await _sdk.events.record(key: 'consent_test_event');
                _addAction('Attempted to record event');
              }),
              _buildButton('Try Setting User Property', () async {
                await _sdk.users.setProperties({'test_key': 'test_value'});
                _addAction('Attempted to set user property');
              }),
              _buildButton('Try Starting View', () async {
                await _sdk.views.startAutoStoppedView('TestView');
                _addAction('Attempted to start view');
              }),
            ],
          ),
          _buildSection(
            'Consent Flow Examples',
            [
              _buildButton('Simulate GDPR Accept', () async {
                // User accepts privacy policy
                await _sdk.consents.giveConsent();

                // Now we can track
                await _sdk.events.record(
                  key: 'gdpr_accepted',
                  segmentation: {'version': '2.0'},
                );
                await _sdk.users.setProperties({
                  'gdpr_consent_date': DateTime.now().toIso8601String(),
                });

                _addAction('GDPR consent flow completed');
              }),
              _buildButton('Simulate User Logout', () async {
                // User logs out - revoke consent
                await _sdk.consents.revokeConsent();
                _addAction('User logged out - consent revoked');
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
