import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharetime/providers/timer_provider.dart';
import 'package:sharetime/screens/timer_view_screen.dart';

class CreateTimerScreen extends StatefulWidget {
  const CreateTimerScreen({super.key});

  @override
  State<CreateTimerScreen> createState() => _CreateTimerScreenState();
}

class _CreateTimerScreenState extends State<CreateTimerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Timer',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter timer information and generate a share code',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 타이머 이름 입력
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Timer Name',
                      hintText: 'e.g., Meeting Timer',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a timer name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // 설명 입력
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Enter a description for the timer',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  
                  // 시간 설정
                  const Text(
                    'Time Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeSelector(
                          label: 'Hours',
                          value: _hours,
                          maxValue: 23,
                          onChanged: (value) => setState(() => _hours = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimeSelector(
                          label: 'Minutes',
                          value: _minutes,
                          maxValue: 59,
                          onChanged: (value) => setState(() => _minutes = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimeSelector(
                          label: 'Seconds',
                          value: _seconds,
                          maxValue: 59,
                          onChanged: (value) => setState(() => _seconds = value),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 선택된 시간 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Set Time',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // 생성 버튼
                  Consumer<TimerProvider>(
                    builder: (context, timerProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: timerProvider.isLoading
                              ? null
                              : _createTimer,
                          icon: timerProvider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(
                            timerProvider.isLoading ? 'Creating...' : 'Create & Share Timer',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required int value,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  value.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _createTimer() async {
    if (!_formKey.currentState!.validate()) return;
    
    final totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    if (totalSeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final success = await timerProvider.createTimer(
      name: _nameController.text,
      description: _descriptionController.text,
      totalSeconds: totalSeconds,
    );

    if (success) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/timer');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(timerProvider.error ?? 'Failed to create timer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 