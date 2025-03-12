import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainPage();
  }
}

class _MainPage extends State<MainPage> {
  Future<String> loadAsset() async {
    return await rootBundle
        .loadString('res/api/list.json'); // list.json을 읽어오는 라인
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        // list.json을 UI로 표시할때 futurebuilder가 사용됨
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.active:
              return const Center(
                child: CircularProgressIndicator(),
              );

            case ConnectionState.done:
              Map<String, dynamic> list = jsonDecode(
                  snapshot.data!); // list.json을 문자열로 반환 -> json으로 디코딩
              return ListView.builder(
                itemBuilder: (context, value) {
                  return InkWell(
                    // inkwell: 터치에 반응하는 위젯이고 잉크가 퍼지는듯한 비주얼이펙트를 줌
                    child: SizedBox(
                      height: 50,
                      child: Card(
                        child: Text(list['questions'][value]['title']
                            .toString()), // list.json에서 title부분만 표시
                      ),
                    ),
                    onTap: () {},
                  );
                },
                itemCount: list['count'],
              );
            case ConnectionState.none:
              return const Center(
                child: Text('No Data'),
              );
            case ConnectionState.waiting:
              return const Center(
                child: CircularProgressIndicator(),
              );
          }
        },
        future: loadAsset(),
      ),
    );
  }
}
