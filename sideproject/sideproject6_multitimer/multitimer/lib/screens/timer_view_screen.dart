import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharetime/providers/timer_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TimerViewScreen extends StatelessWidget {
  const TimerViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F5F5)],
          ),
        ),
        child: SafeArea(
          child: Consumer<TimerProvider>(
            builder: (context, timerProvider, child) {
              if (timerProvider.currentTimer == null) {
                return const Center(
                  child: Text('No timer available'),
                );
              }

              final timer = timerProvider.currentTimer!;
              
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // 타이머 정보
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            timer.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (timer.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              timer.description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 타이머 디스플레이
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: timer.isFinished 
                            ? Colors.red.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: timer.isFinished 
                              ? Colors.red.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            timer.isFinished ? Icons.timer_off : Icons.timer,
                            size: 60,
                            color: timer.isFinished ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            timer.formattedTime,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: timer.isFinished ? Colors.red : Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            timer.isFinished ? 'Timer Complete!' : 'Time Remaining',
                            style: TextStyle(
                              fontSize: 18,
                              color: timer.isFinished ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 컨트롤 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: timerProvider.toggleTimer,
                            icon: Icon(timer.isActive ? Icons.pause : Icons.play_arrow),
                            label: Text(timer.isActive ? 'Pause' : 'Start'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: timer.isActive ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: timerProvider.resetTimer,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 홈으로 돌아가기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          timerProvider.clearTimer();
                          Navigator.pushNamedAndRemoveUntil(
                            context, 
                            '/', 
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Home'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // 진행률 표시
                    if (!timer.isFinished) ...[
                      LinearProgressIndicator(
                        value: (timer.totalSeconds - timer.remainingSeconds) / timer.totalSeconds,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${((timer.totalSeconds - timer.remainingSeconds) / timer.totalSeconds * 100).toStringAsFixed(1)}% Complete',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final timer = timerProvider.currentTimer;
    
    if (timer == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this timer with others'),
            const SizedBox(height: 20),
            // QR 코드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: timer.id,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            // 공유 코드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Share Code',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timer.id,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 