import 'package:flutter/material.dart';
import 'package:countly_flutter_lite/countly.dart';

import 'pages/events_page.dart';
import 'pages/views_page.dart';
import 'pages/users_page.dart';
import 'pages/consent_page.dart';
import 'pages/device_id_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = CountlyConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://your.countly.server',
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    giveConsent: true,
    userProperties: {
      'name': 'Test User',
      'tier': 'free',
    },
  );

  await Countly.init(config);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countly SDK Dart Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Start tracking the home view
    Countly.defaultInstance?.views.startAutoStoppedView('HomePage');
  }

  @override
  void dispose() {
    Countly.disposeAll();
    super.dispose();
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Countly SDK Dart'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildFeatureCard(
            'Events',
            'Record custom events with various parameters',
            Icons.analytics,
            () => _navigateTo(const EventsPage()),
          ),
          _buildFeatureCard(
            'Views',
            'Track screen views and navigation',
            Icons.visibility,
            () => _navigateTo(const ViewsPage()),
          ),
          _buildFeatureCard(
            'User Profiles',
            'Set user properties and array operations',
            Icons.person,
            () => _navigateTo(const UsersPage()),
          ),
          _buildFeatureCard(
            'Consent',
            'Manage consent for data collection',
            Icons.security,
            () => _navigateTo(const ConsentPage()),
          ),
          _buildFeatureCard(
            'Device ID',
            'Change device ID with or without merge',
            Icons.devices,
            () => _navigateTo(const DeviceIdPage()),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final sdk = Countly.defaultInstance;
              // ignore: invalid_use_of_visible_for_testing_member
              await sdk?.processEventsAndRequests();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Queue flushed')),
                );
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Force Flush Queue'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final sdk = Countly.defaultInstance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SDK Info',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Device ID: ${sdk?.deviceId ?? 'N/A'}'),
            Text('Device ID Type: ${sdk?.deviceIdType == 1 ? 'Provided' : 'Generated'}'),
            Text('Disposed: ${sdk?.isDisposed ?? true}'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
