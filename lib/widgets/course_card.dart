import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CourseState {
  final int id;
  String customName;
  TimeOfDay startTime; // 出走予定時刻（正時）
  final TimeOfDay initialStartTime; // 案内用
  bool isRunning;

  CourseState({
    required this.id,
    required this.customName,
    required this.startTime,
    required this.initialStartTime,
    this.isRunning = false,
  });

  CourseState copyWith({
    int? id,
    String? customName,
    TimeOfDay? startTime,
    TimeOfDay? initialStartTime,
    bool? isRunning,
  }) {
    return CourseState(
      id: id ?? this.id,
      customName: customName ?? this.customName,
      startTime: startTime ?? this.startTime,
      initialStartTime: initialStartTime ?? this.initialStartTime,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class CourseCard extends StatefulWidget {
  final CourseState state;
  final DateTime currentTime;
  final VoidCallback onPlayRequested;
  final ValueChanged<CourseState> onUpdate;

  const CourseCard({
    super.key,
    required this.state,
    required this.currentTime,
    required this.onPlayRequested,
    required this.onUpdate,
  });

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.customName);
  }

  @override
  void didUpdateWidget(covariant CourseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.customName != oldWidget.state.customName) {
      _nameController.text = widget.state.customName;
    }
    _checkAutoPlay();
  }

  // 自動再生のチェック
  void _checkAutoPlay() {
    if (!widget.state.isRunning) return;

    final now = widget.currentTime;
    // 出走予定時刻（正時）をDateTimeオブジェクトに変換
    final DateTime startTimeDate = DateTime(
      now.year,
      now.month,
      now.day,
      widget.state.startTime.hour,
      widget.state.startTime.minute,
    );

    // 再生開始時刻を算出（50秒前）
    final playbackStartTime = startTimeDate.subtract(
      const Duration(seconds: 50),
    );

    // カウントダウン実行中で、かつ現在時刻が再生開始時刻に達している場合
    if (!now.isBefore(playbackStartTime)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (widget.state.isRunning) {
          // メイン画面（Home）に音声再生を要求
          widget.onPlayRequested();
          // 再生が始まったら自動的に「停止」状態（isRunning = false）にする
          widget.onUpdate(widget.state.copyWith(isRunning: false));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.currentTime;
    final DateTime startTimeDate = DateTime(
      now.year,
      now.month,
      now.day,
      widget.state.startTime.hour,
      widget.state.startTime.minute,
    );
    final playbackStartTime = startTimeDate.subtract(
      const Duration(seconds: 50),
    );

    // 再生開始時刻までの秒数を算出（小数精度の差分を切り上げ）
    final preciseDiff =
        playbackStartTime.difference(now).inMilliseconds / 1000.0;
    final displayDiff = preciseDiff.ceil().clamp(0, double.infinity).toInt();

    // 60秒前からの進捗率（プログレスバー表示用）
    double progress = 1.0;
    if (widget.state.isRunning) {
      if (preciseDiff > 0 && preciseDiff <= 60) {
        progress = (preciseDiff) / 60.0;
      } else if (preciseDiff <= 0) {
        progress = 0.0;
      }
    }

    final color = displayDiff <= 10
        ? Colors.red
        : Theme.of(context).primaryColor;
    final progressColor = displayDiff <= 10
        ? Colors.red
        : Theme.of(context).primaryColor;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Name
            Row(
              children: [
                if (_isEditingName)
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      widget.state.customName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(_isEditingName ? Icons.save : Icons.edit),
                  onPressed: () {
                    if (_isEditingName) {
                      widget.onUpdate(
                        widget.state.copyWith(customName: _nameController.text),
                      );
                    }
                    setState(() {
                      _isEditingName = !_isEditingName;
                    });
                  },
                ),
              ],
            ),
            // const SizedBox(height: 16),

            // Time Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "案内: ${_formatTimeOfDay(widget.state.initialStartTime)}",
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 20),
                ),
                Text(
                  "設定(正時): ${_formatTimeOfDay(widget.state.startTime)}",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),

            // const SizedBox(height: 8),
            const Text(
              "動作時刻(50秒前)",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    DateFormat('HH:mm:ss').format(playbackStartTime),
                    style: const TextStyle(
                      fontSize:
                          48, // Slightly smaller than 58sp to fit standard width
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                      height: 1.0,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: widget.state.startTime,
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      widget.onUpdate(widget.state.copyWith(startTime: picked));
                    }
                  },
                  child: const Text("変更", style: TextStyle(fontSize: 24)),
                ),
              ],
            ),

            //const SizedBox(height: 16), //16
            // Status & Progress
            if (widget.state.isRunning) ...[
              Row(
                children: [
                  // 1. テキスト（幅を固定しないならそのまま）
                  Text(
                    displayDiff > 0 ? "待機中（再生まで $displayDiff秒）" : "再生中",
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(width: 12), // テキストとバーの間の隙間
                  // 2. プログレスバー（Expandedで残りの横幅をすべて使う）
                  Expanded(
                    child: ClipRRect(
                      // 角を丸くするときれいに見えます
                      borderRadius: BorderRadius.circular(8),
                      child: Transform.flip(
                        flipX: true, // 横方向を反転
                        child: LinearProgressIndicator(
                          value: progress, // 右に向かって減算されるイメージに修正
                          minHeight: 16,
                          color: progressColor,
                          backgroundColor: Colors.grey[200],
                          // 中のバーの先端を丸くする（Flutterの比較的新しいバージョンで利用可能）
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 32),
            // カウント開始/停止ボタン
            SizedBox(
              width: double.infinity,
              height: 48, //60
              child: ElevatedButton(
                // 以下の条件でボタンを無効化（nullを設定）
                // 1. 名前を編集中の場合
                // 2. 現在時刻がカウントダウン開始時刻（50秒前）に達している場合（誤操作・二重再生防止）
                onPressed: (_isEditingName || !now.isBefore(playbackStartTime))
                    ? null
                    : () {
                        widget.onUpdate(
                          widget.state.copyWith(
                            isRunning: !widget.state.isRunning,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.state.isRunning
                      ? Colors.red
                      : Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white, // Text color
                ),
                child: Text(
                  widget.state.isRunning ? "■ 停止" : "▶ カウント開始",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dt);
  }
}
