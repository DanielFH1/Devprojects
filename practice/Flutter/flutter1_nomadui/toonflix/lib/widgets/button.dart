import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const Button(
      {super.key,
      required this.text,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
        // ----------2번째 container----------
        //container는 html의 div, child를 가지는 box

        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 45),
          child: Text(text,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
              )),
        ));
  }
}
