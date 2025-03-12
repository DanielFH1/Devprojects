import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  //const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  //얘가 찐 state
  int counter = 0;

  void onClicked() {
    setState(() {
      counter = counter + 1;
    });
  }

  void deleteCounter() {
    setState(() {
      counter = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      backgroundColor: Color(0xFFFFFFF0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Click Count",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 40,
              ),
            ),
            Text(
              "$counter",
              style: TextStyle(
                color: Colors.black,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
                iconSize: 50,
                highlightColor: Color(0xFFFFFFF0),
                onPressed: onClicked,
                icon: Icon(Icons.add_box_sharp)),
            IconButton(
                iconSize: 30,
                onPressed: deleteCounter,
                icon: Icon(Icons.refresh))
          ],
        ),
      ),
    ));
  }
}
