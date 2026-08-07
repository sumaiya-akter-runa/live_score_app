import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  final doc =
      FirebaseFirestore.instance.collection('matches').doc('live_match');

  // ekta key ba value change hole AnimatedSwitcher/TweenAnimationBuilder
  // notun animation trigger korbe - eta track korar jonno
  int _lastRuns = 0;
  int _lastWickets = 0;

  void addRun(int run) {
    doc.update({"runs": FieldValue.increment(run)});
  }

  void addWicket() {
    doc.update({"wickets": FieldValue.increment(1)});
  }

  void nextBall() {
    doc.update({"balls": FieldValue.increment(1)});
  }

  Future<void> resetMatch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Match?'),
        content: const Text('Runs, wickets shob 0 hoye jabe. Sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await doc.update({
        "runs": 0,
        "wickets": 0,
        "balls": 0,
        "status": "Match Reset",
      });
    }
  }

  // Chotto animated button - press korle scale down/up hoy
  Widget _animatedButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏏 Live Score'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E0), Color(0xFFFFFFFF)],
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: doc.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;

            if (data == null) {
              return const Center(
                child: Text(
                    'Match data pawa jaini. "live_match" doc ta check koro.'),
              );
            }

            final int runs = data['runs'] ?? 0;
            final int wickets = data['wickets'] ?? 0;
            final String teamA = data['teamA'] ?? 'Team A';
            final String teamB = data['teamB'] ?? 'Team B';
            final overs = data['overs'] ?? 0;
            final status = data['status'] ?? '';

            final bool runsChanged = runs != _lastRuns;
            final bool wicketChanged = wickets != _lastWickets;
            _lastRuns = runs;
            _lastWickets = wickets;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Team vs Team card
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '$teamA  vs  $teamB',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Runs/Wickets - scale + fade animation on change
                  TweenAnimationBuilder<double>(
                    key: ValueKey('$runs-$wickets'),
                    tween: Tween(begin: 0.7, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Column(
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: wicketChanged
                                ? Colors.red
                                : (runsChanged ? Colors.green : Colors.black87),
                          ),
                          child: Text('$runs / $wickets'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Overs : $overs',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Status pill - fade in/out
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(status),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _animatedButton(
                        label: '+1 Run',
                        color: Colors.blue,
                        onTap: () => addRun(1),
                      ),
                      _animatedButton(
                        label: '+2 Run',
                        color: Colors.indigo,
                        onTap: () => addRun(2),
                      ),
                      _animatedButton(
                        label: 'Four',
                        color: Colors.teal,
                        onTap: () => addRun(4),
                        icon: Icons.flash_on,
                      ),
                      _animatedButton(
                        label: 'Six',
                        color: Colors.purple,
                        onTap: () => addRun(6),
                        icon: Icons.rocket_launch,
                      ),
                      _animatedButton(
                        label: 'Wicket',
                        color: Colors.red,
                        onTap: addWicket,
                        icon: Icons.close,
                      ),
                      _animatedButton(
                        label: 'Next Ball',
                        color: Colors.orange,
                        onTap: nextBall,
                        icon: Icons.arrow_forward,
                      ),
                      _animatedButton(
                        label: 'Reset',
                        color: Colors.grey,
                        onTap: resetMatch,
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reusable widget: button press korle scale down/up animation dey.
/// Ei class ta ekhon shudhu ei file er moddhei use hocche, alada kono
/// package lagbe na.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(0.9),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
