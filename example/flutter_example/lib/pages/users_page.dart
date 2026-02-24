import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly_flutter_lite.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _sdk = Countly.defaultInstance!;
  final List<String> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    _sdk.views.startAutoStoppedView('UsersPage');
  }

  void _addAction(String action) {
    setState(() {
      _actionHistory.insert(0, action);
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
        title: const Text('User Profiles'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Named User Properties',
            [
              _buildButton('Set Basic Info', () async {
                await _sdk.users.setProperties({
                  NamedUserProperty.name: 'John Doe',
                  NamedUserProperty.username: 'johndoe',
                  NamedUserProperty.email: 'john@example.com',
                });
                _addAction('Set: name, username, email');
              }),
              _buildButton('Set Contact Info', () async {
                await _sdk.users.setProperties({
                  NamedUserProperty.phone: '+1234567890',
                  NamedUserProperty.organization: 'Acme Inc.',
                });
                _addAction('Set: phone, organization');
              }),
              _buildButton('Set Demographics', () async {
                await _sdk.users.setProperties({
                  NamedUserProperty.gender: 'M',
                  NamedUserProperty.byear: 1990,
                });
                _addAction('Set: gender, byear');
              }),
              _buildButton('Set Picture URL', () async {
                await _sdk.users.setProperties({
                  NamedUserProperty.picture: 'https://example.com/avatar.jpg',
                });
                _addAction('Set: picture');
              }),
              _buildButton('Set All Named Properties', () async {
                await _sdk.users.setProperties({
                  NamedUserProperty.name: 'Jane Smith',
                  NamedUserProperty.username: 'janesmith',
                  NamedUserProperty.email: 'jane@example.com',
                  NamedUserProperty.phone: '+0987654321',
                  NamedUserProperty.organization: 'Tech Corp',
                  NamedUserProperty.picture: 'https://example.com/jane.jpg',
                  NamedUserProperty.gender: 'F',
                  NamedUserProperty.byear: 1985,
                });
                _addAction('Set all named properties');
              }),
            ],
          ),
          _buildSection(
            'Custom User Properties',
            [
              _buildButton('Set String Properties', () async {
                await _sdk.users.setProperties({
                  'tier': 'premium',
                  'country': 'USA',
                  'language': 'en',
                });
                _addAction('Set: string properties');
              }),
              _buildButton('Set Number Properties', () async {
                await _sdk.users.setProperties({
                  'points': 1500,
                  'level': 5,
                  'rating': 4.5,
                });
                _addAction('Set: number properties');
              }),
              _buildButton('Set Boolean Properties', () async {
                await _sdk.users.setProperties({
                  'verified': true,
                  'newsletter': false,
                  'premium': true,
                });
                _addAction('Set: boolean properties');
              }),
              _buildButton('Set Mixed Properties', () async {
                await _sdk.users.setProperties({
                  'subscription': 'annual',
                  'credits': 100,
                  'discount_rate': 0.15,
                  'active': true,
                });
                _addAction('Set: mixed properties');
              }),
            ],
          ),
          _buildSection(
            'Array Operations',
            [
              _buildButton('Push to Array (Duplicates OK)', () async {
                await _sdk.users.pushToArray(
                  'viewed_products',
                  ['SKU001', 'SKU002', 'SKU003'],
                );
                _addAction('Pushed to viewed_products');
              }),
              _buildButton('Push Numbers to Array', () async {
                await _sdk.users.pushToArray(
                  'scores',
                  [100, 95, 88, 92],
                );
                _addAction('Pushed to scores');
              }),
              _buildButton('Push Mixed Values', () async {
                await _sdk.users.pushToArray(
                  'activity_log',
                  ['login', 42, true, 3.14],
                );
                _addAction('Pushed mixed values');
              }),
              _buildButton('Add to Set (Unique Only)', () async {
                await _sdk.users.addToSet(
                  'categories',
                  ['electronics', 'books', 'clothing'],
                );
                _addAction('Added to categories set');
              }),
              _buildButton('Add More to Set', () async {
                await _sdk.users.addToSet(
                  'categories',
                  ['electronics', 'sports', 'home'],
                );
                _addAction('Added more to categories (no duplicates)');
              }),
              _buildButton('Pull from Array', () async {
                await _sdk.users.pullFromArray(
                  'viewed_products',
                  ['SKU001'],
                );
                _addAction('Pulled SKU001 from viewed_products');
              }),
              _buildButton('Pull Multiple Values', () async {
                await _sdk.users.pullFromArray(
                  'categories',
                  ['books', 'clothing'],
                );
                _addAction('Pulled books, clothing from categories');
              }),
            ],
          ),
          _buildSection(
            'Complete User Profile',
            [
              _buildButton('Set Complete Profile', () async {
                // Set named properties
                await _sdk.users.setProperties({
                  NamedUserProperty.name: 'Alex Johnson',
                  NamedUserProperty.email: 'alex@company.com',
                  NamedUserProperty.organization: 'Company Ltd',
                  NamedUserProperty.gender: 'M',
                  NamedUserProperty.byear: 1988,
                  // Custom properties
                  'tier': 'enterprise',
                  'employee_id': 'EMP-12345',
                  'department': 'Engineering',
                  'hire_date': '2020-01-15',
                });

                // Add array values
                await _sdk.users.addToSet('skills', ['dart', 'flutter', 'kotlin']);
                await _sdk.users.pushToArray('completed_trainings', ['onboarding', 'security']);

                _addAction('Set complete user profile');
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
                        'Action History',
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
                            child: Text('• $entry'),
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
