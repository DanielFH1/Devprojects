//import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toonflix/widgets/button.dart';
import 'package:toonflix/widgets/card.dart';

void main() {
  runApp(
      MyApp()); // 앱 시작할때 가장 먼저 실행되는 위젯(그래서 지금은 이게 root임),root: material, cupertino중 하나를 정해야 하는 역할, runApp은 화면에 위젯을 띄워주는 역할
}

class MyApp extends StatelessWidget {
  // flutter의 core위젯 중 하나인 StatelessWidget을 상속받음 , 역할은 화면에 띄워서 보여주는거
  // App을 위젯으로 바꾸기 위해 상속받았고, 상속받을땐 build 메소드(flutter가 화면에 띄워줄)를 정의해줘야.

  @override // 부모 클래스에 있는 메소드에 오버라이드
  Widget build(BuildContext context) {
    // root 위젯임 , 모든 위젯은 build 메소드를 가지고 있음
    return MaterialApp(
      // material:google스타일, cupertino:ios스타일
      home: Scaffold(
          backgroundColor: Color(0xFF181818), // 배경색 , shade는 채도
          body: SingleChildScrollView(
            // 스크롤할 수 있도록
            child: Padding(
                // 테두리 여백을 위해 padding
                padding:
                    EdgeInsets.symmetric(horizontal: 14) //all, only, symmetric
                ,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: 60), // for 맨위의 공백 , children 안에는 다 리스트니 콤마로 구분
                    Row(
                      //Row의 Mainaxis는 가로, vice versa
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end, // column의 crossaxis는 가로
                          children: [
                            Text("Hey Daniel",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.bold)),
                            Text("Welcome back!",
                                style: TextStyle(
                                  color: Colors.white.withValues(
                                      alpha: 0.3), // withOpacity대신 새롭게 적용
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 50,
                    ),

                    Text("Total Balance",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                        )),
                    SizedBox(
                      height: 5,
                    ),
                    Text("\$5,194,293", // \$는 $를 문자로 인식하게 해줌
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        )),
                    SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Button(
                          // reusable!!
                          text: "lalala",
                          bgColor: Color(0xFFf2b33b),
                          textColor: Colors.black,
                        ),
                        Button(
                          text: "Request",
                          bgColor: Color(0xFF1f2123),
                          textColor: Colors.white,
                        )
                      ],
                    ),

                    SizedBox(
                      height: 50,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Wallets",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 30,
                          ),
                        ),
                        Text("View all",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                            )),
                      ],
                    ),

                    SizedBox(
                      height: 20,
                    ),

                    CurrencyCard(
                      name: "Euro",
                      code: "EUR",
                      amount: "6 428",
                      icon: Icons.euro_rounded,
                      isInverted: false,
                    ),

                    Transform.translate(
                      // 이 안에 있는 offset이라는 메소드 써서 카드를 이동시키려고
                      offset: Offset(0, -20),
                      child: CurrencyCard(
                        name: "BITCOIN",
                        code: "BTC",
                        amount: "9 782",
                        icon: Icons.currency_bitcoin,
                        isInverted: true,
                      ),
                    ),

                    Transform.translate(
                      offset: Offset(0, -40),
                      child: CurrencyCard(
                        name: "Dollar",
                        code: "USD",
                        amount: "1 428",
                        icon: Icons.attach_money_rounded,
                        isInverted: false,
                      ),
                    ),
                  ],
                )),
          )),
    ); // Material: gooele스타일, Cupertino: ios스타일
  }
}
