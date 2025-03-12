import 'package:flutter/material.dart';
import 'dart:async'; //타이머

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const twentyFiveMinutes = 1500;
  int totalSeconds = twentyFiveMinutes;
  bool isRunning = false;
  late Timer timer;
  int totalPomodoros = 0;

  void onTick(Timer timer) {
    //state 변경해줌
    if (totalSeconds == 0) {
      setState(() {
        totalPomodoros = totalPomodoros + 1;
        isRunning = false;
        totalSeconds = twentyFiveMinutes;
      });
      timer.cancel();
    } else {
      setState(() {
        totalSeconds = totalSeconds - 1;
      });
    }
  }

  void onStartPressed() {
    timer = Timer.periodic(
      Duration(seconds: 1),
      onTick,
    );

    setState(() {
      isRunning = true;
    });
  }

  void onPausePressed() {
    timer.cancel();

    setState(() {
      isRunning = false;
    });
  }

  void newTimer() {
    setState(() {
      isRunning = false;
      totalSeconds = twentyFiveMinutes;
    });
  }

  String format(int seconds) {
    var duration = Duration(seconds: seconds);
    return duration.toString().split(".").first.substring(2, 7);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Flexible(
              flex:
                  1, //하나의 박스의 크기, 디폴트는 1, 400px 500px이렇게 하는건 하드코딩 : 기기마다 문제생길수도
              child: Container(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    format(totalSeconds),
                    style: TextStyle(
                      color: Theme.of(context).cardColor,
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
            ),
            Flexible(
                flex: 3,
                child: Column(
                  children: [
                    Center(
                      child: IconButton(
                        iconSize: 120,
                        color: Theme.of(context).cardColor,
                        icon: Icon(isRunning
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline_rounded),
                        onPressed: isRunning ? onPausePressed : onStartPressed,
                      ),
                    ),
                    Center(
                      child: IconButton(
                          iconSize: 50,
                          color: Colors.black,
                          onPressed: newTimer,
                          icon: Icon(Icons.refresh)),
                    ),
                  ],
                )),
            Flexible(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Pomodoros",
                              style: TextStyle(
                                fontSize: 20,
                                color: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "$totalPomodoros",
                              style: TextStyle(
                                fontSize: 60,
                                color: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )),
                  ),
                ],
              ),
            ),
          ],
        ));
  }
}
