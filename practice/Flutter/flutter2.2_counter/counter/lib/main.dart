import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  //이 부분은 위젯 그자체
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  //여기가 state

  int counter = 0;

  void onClicked() {
    setState(() {
      // state에게 데이터가 변했으니 변한 데이터를 표시하라고 알려줘서,할때마다 build메소드를 다시 실행하게함
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
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Click count",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 30,
              ),
            ),
            Text(
              "$counter",
              style: TextStyle(
                fontSize: 30,
              ),
            ),

            IconButton(
                iconSize: 50,
                onPressed: onClicked,
                icon: Icon(
                  Icons.add_box_rounded,
                )),

            IconButton(
                onPressed: deleteCounter,
                color: Colors.red,
                icon: Icon(Icons.refresh)) // 버튼 클릭할 때 실행할 함수와, 버튼 모양
          ],
        ),
      ),
    ));
  }
}
