import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../diag/breadcrumbs.dart';
import 'camera_probe_screen.dart';
import 'pose_spike_screen.dart';

/// Opens without touching the camera, so the app always starts. Each test
/// below adds one more risky part, so a crash points at the part that caused it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Shown on screen so we know which build is installed.
  static const String buildLabel = 'S2 diagnostic 1';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _lines = Breadcrumbs.instance.recentLines(30);

  Future<void> _openTest(String name, Widget screen) async {
    Breadcrumbs.instance.add('home: opening $name');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext _) => screen),
    );
    Breadcrumbs.instance.add('home: back from $name');
    if (!mounted) return;
    setState(() => _lines = Breadcrumbs.instance.recentLines(30));
  }

  Future<void> _copyLog() async {
    final text = Breadcrumbs.instance.recentLines(60).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log copied')),
    );
  }

  void _clearLog() {
    Breadcrumbs.instance.clear();
    setState(() => _lines = Breadcrumbs.instance.recentLines(30));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Pose Runner', style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Build: ${HomeScreen.buildLabel}'),
            const SizedBox(height: 16),
            const Text(
              'Run the tests in order. If the app closes during a test, '
              'open it again: the log below shows the last step that ran.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _openTest(
                'test 1',
                const CameraProbeScreen(stream: false),
              ),
              child: const Text('Test 1: camera preview only'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _openTest(
                'test 2',
                const CameraProbeScreen(stream: true),
              ),
              child: const Text('Test 2: camera + frame stream'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _openTest('test 3', const PoseSpikeScreen()),
              child: const Text('Test 3: camera + pose (full test)'),
            ),
            const SizedBox(height: 24),
            Text('Log (kept even if the app crashes)',
                style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: SelectableText(
                _lines.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: _copyLog,
                  child: const Text('Copy log'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearLog,
                  child: const Text('Clear log'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
