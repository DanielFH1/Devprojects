import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharetime/providers/timer_provider.dart';
import 'package:sharetime/screens/timer_view_screen.dart';

class JoinTimerScreen extends StatefulWidget {
  const JoinTimerScreen({super.key});

  @override
  State<JoinTimerScreen> createState() => _JoinTimerScreenState();
}

class _JoinTimerScreenState extends State<JoinTimerScreen> {
  final _codeController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Timer'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join Timer',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan QR code or enter code to join a timer',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                
                // QR 코드 스캔 버튼
                if (!_showManualInput) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan the QR code provided by the timer creator',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _scanQRCode,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Start Scan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 수동 입력 옵션
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showManualInput = true),
                      child: const Text(
                        'Enter code manually?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // 수동 코드 입력
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter Code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Timer Code',
                            hintText: 'Enter 6-digit code',
                            prefixIcon: Icon(Icons.code),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a code';
                            }
                            if (value.length != 6) {
                              return 'Please enter a 6-digit code';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _joinTimer,
                                child: const Text('Join'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => setState(() => _showManualInput = false),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Spacer(),
                
                // 도움말
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Help',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Scan the QR code provided by the timer creator\n• Or enter the 6-digit share code to join the timer',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scanQRCode() {
    // TODO: QR 코드 스캔 기능 구현
    // mobile_scanner 패키지를 사용하여 QR 코드 스캔
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code scanning will be implemented soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _joinTimer() async {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final success = await timerProvider.joinTimer(_codeController.text.toUpperCase());

    if (success) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/timer');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(timerProvider.error ?? 'Failed to join timer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 