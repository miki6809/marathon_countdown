import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/course_card.dart';

void main() => runApp(const MarathonApp());

class MarathonApp extends StatelessWidget {
  const MarathonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '銀河マラソンスタート音声送出システム',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          secondary: Colors.teal,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _currentTime = DateTime.now();
  late Timer _timer;

  // Audio Player Management
  final List<AudioPlayer> _activePlayers = [];
  String? _globalAudioPath;

  // Course Data
  // Initial Data:
  // 1.2km（太陽）コース 12:00:00 (12:00)
  // 5km（彗星）コース 11:00:00 (11:00)
  // 10km（銀河）コース 10:18:00 (10:18)
  // 3km（木星）コース 10:15:00 (10:15)
  // NOTE: Initializing mutable list of CourseState
  final List<CourseState> _courses = [
    CourseState(
      id: 1,
      customName: "3km（木星）コース",
      startTime: const TimeOfDay(hour: 10, minute: 15),
      initialStartTime: const TimeOfDay(hour: 10, minute: 15),
    ),
    CourseState(
      id: 2,
      customName: "10km（銀河）コース",
      startTime: const TimeOfDay(hour: 10, minute: 18),
      initialStartTime: const TimeOfDay(hour: 10, minute: 18),
    ),
    CourseState(
      id: 3,
      customName: "5km（彗星）コース",
      startTime: const TimeOfDay(hour: 11, minute: 0),
      initialStartTime: const TimeOfDay(hour: 11, minute: 0),
    ),
    CourseState(
      id: 4,
      customName: "1.2km（太陽）コース",
      startTime: const TimeOfDay(hour: 12, minute: 0),
      initialStartTime: const TimeOfDay(hour: 12, minute: 0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Update time every 100ms
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopAllAudio();
    super.dispose();
  }

  Future<void> _playAudio(String path) async {
    try {
      final player = AudioPlayer();
      // Configure audio attributes if possible in future, but default is usually fine for music/alarm
      // In mobile, might need to set mode to media or alarm.
      await player.setReleaseMode(ReleaseMode.release); // Release after finish

      // Store player to track it
      setState(() {
        _activePlayers.add(player);
      });

      // Remove from list when done
      player.onPlayerComplete.listen((event) {
        player.dispose();
        setState(() {
          _activePlayers.remove(player);
        });
      });

      await player.play(DeviceFileSource(path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("再生エラー: $e")));
      }
    }
  }

  void _stopAllAudio() {
    for (var player in _activePlayers) {
      player.stop();
      player.dispose();
    }
    setState(() {
      _activePlayers.clear();
    });
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _globalAudioPath = result.files.single.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort courses by startTime
    final sortedCourses = List<CourseState>.from(_courses)
      ..sort((a, b) {
        final double aVal = a.startTime.hour + a.startTime.minute / 60.0;
        final double bVal = b.startTime.hour + b.startTime.minute / 60.0;
        return aVal.compareTo(bVal);
      });

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 80, // Taller app bar for the clock
        title: Column(
          children: [
            const Text("現在時刻（計測業者との同期用）", style: TextStyle(fontSize: 20)),
            Text(
              DateFormat('HH:mm:ss').format(_currentTime),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Audio Settings Card
          Card(
            margin: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "カウントダウン音声",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          _globalAudioPath != null ? "設定済 ✅" : "ファイルを選択してください",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _pickAudioFile,
                    child: const Text("選択", style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 8),
                  if (_globalAudioPath != null)
                    IconButton(
                      onPressed: () => _playAudio(_globalAudioPath!),
                      icon: const Icon(Icons.play_arrow),
                      tooltip: "テスト再生",
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _stopAllAudio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("全停止", style: TextStyle(fontSize: 24)),
                  ),
                ],
              ),
            ),
          ),

          // Course List
          Expanded(
            child: ListView.builder(
              itemCount: sortedCourses.length,
              itemBuilder: (context, index) {
                final course = sortedCourses[index];
                return CourseCard(
                  key: ValueKey(course.id),
                  state: course,
                  currentTime: _currentTime,
                  onPlayRequested: () {
                    if (_globalAudioPath != null) {
                      _playAudio(_globalAudioPath!);
                    }
                  },
                  onUpdate: (newState) {
                    setState(() {
                      final idx = _courses.indexWhere((c) => c.id == course.id);
                      if (idx != -1) {
                        _courses[idx] = newState;
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
