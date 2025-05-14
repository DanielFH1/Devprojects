import 'package:flutter/material.dart';

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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(_diaryEntries[index]),
                        ),
                      );
                    }))
          ],
        ),
      ),
    );
  }
}
