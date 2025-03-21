import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "감정일기ㅣㅣㅣ",
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const EmotionDiaryScreen(),
    );
  }
}

class EmotionDiaryScreen extends StatefulWidget {
  const EmotionDiaryScreen({super.key});

  @override
  State<EmotionDiaryScreen> createState() => _EmotionDiaryScreenState();
}

class _EmotionDiaryScreenState extends State<EmotionDiaryScreen> {
  final TextEditingController _emotionController = TextEditingController();
  final List<String> _diaryEntries = [];

  @override
  void initState() {
    super.initState();
    _loadDiaryEntries();
  }

  Future<void> _loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _diaryEntries.addAll(prefs.getStringList("diary_entries") ?? []);
    });
  }

  Future<void> _saveDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("diary_entries", _diaryEntries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your private Emotion Diary"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emotionController,
              decoration: const InputDecoration(
                labelText: "write your emotion",
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (_emotionController.text.isNotEmpty) {
                    _diaryEntries.add(_emotionController.text);
                    _emotionController.clear();
                    _saveDiaryEntries();
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Saved!")),
                );
              },
              child: const Text("Save your Emotion"),
            ),
            const SizedBox(
              height: 20,
            ),
            Expanded(
                child: ListView.builder(
                    itemCount: _diaryEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _diaryEntries[index];
                      return Dismissible(
                        key: Key(entry), // 일단 entry 자체로 key 사용
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          setState(() {
                            _diaryEntries.removeAt(index); // 안전하게 삭제
                          });
                          _saveDiaryEntries();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Deleted: $entry")),
                          );
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            title: Text(entry),
                          ),
                        ),
                      );
                    }))
          ],
        ),
      ),
    );
  }
}
