import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Random Quote",
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey, brightness: Brightness.dark),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String _quote = "여기에 명언이 표시됩니다.";
  String _author = "";
  bool _isLoading = false;
  late AnimationController _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    // 초기화 시 명언 가져오기
    Future.delayed(Duration(milliseconds: 300), () {
      _fetchRandomQuote();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchRandomQuote() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ZenQuotes API 사용
      final response = await http.get(
        Uri.parse('https://zenquotes.io/api/random'),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'User-Agent': 'RandomQuoteApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10)); // 타임아웃 설정

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // 응답이 비어있는지 확인
        if (response.body.isEmpty) {
          setState(() {
            _quote = "서버에서 빈 응답이 반환되었습니다.";
            _author = "";
            _isLoading = false;
          });
          return;
        }

        try {
          // ZenQuotes는 배열 형태로 반환됨
          final List<dynamic> dataList = jsonDecode(response.body);

          if (dataList.isEmpty) {
            setState(() {
              _quote = "데이터가 없습니다.";
              _author = "";
              _isLoading = false;
            });
            return;
          }

          // 첫 번째 항목 사용
          final data = dataList[0] as Map<String, dynamic>;

          // 데이터 확인
          print('Decoded data: $data');

          // ZenQuotes API 형식에 맞게 필드 이름 변경
          final content = data['q']; // ZenQuotes는 'q'를 명언 필드로 사용
          final author = data['a']; // ZenQuotes는 'a'를 저자 필드로 사용

          if (content == null) {
            setState(() {
              _quote = "명언 컨텐츠가 없습니다.";
              _author = "";
              _isLoading = false;
            });
            return;
          }

          setState(() {
            _quote = content;
            _author = author ?? "";
            _isLoading = false;
          });

          print('Quote: $_quote');
          print('Author: $_author');

          _animationController.reset();
          _animationController.forward();
        } catch (decodeError) {
          print('JSON 디코딩 오류: $decodeError');
          setState(() {
            _quote = "데이터 형식 오류: $decodeError";
            _author = "";
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 429) {
        // 429 에러 (Too Many Requests) 처리
        setState(() {
          _quote = "Too many requests. Please try again in a minute.";
          _author = "Rate limit exceeded (429 error)";
          _isLoading = false;
        });
      } else {
        setState(() {
          _quote = "Failed to load quote. (Error ${response.statusCode})";
          _author = "";
          _isLoading = false;
        });
      }
    } catch (e) {
      print('네트워크 오류: $e');
      setState(() {
        _quote = "네트워크 오류: $e";
        _author = "";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Random Quote",
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: colorScheme.primary,
                  ),
                  ClipPath(
                    clipper: WaveClipper(),
                    child: Container(
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 20),
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: FadeTransition(
                                opacity: _fadeAnimation ??
                                    AlwaysStoppedAnimation(1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      size: 40,
                                      color: colorScheme.primary,
                                    ),
                                    SizedBox(height: 20),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          _quote,
                                          style: GoogleFonts.roboto(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    if (_author.isNotEmpty)
                                      Text(
                                        "- $_author",
                                        style: GoogleFonts.roboto(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    SizedBox(height: 10),
                                    // 출처 표기 (필수)
                                    Text(
                                      "Powered by ZenQuotes.io",
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _fetchRandomQuote,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.refresh),
                      label: Text(
                        "Generate new Quote!",
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.65);

    var firstControlPoint = Offset(size.width * 0.25, size.height * 0.75);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.65);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.75, size.height * 0.55);
    var secondEndPoint = Offset(size.width, size.height * 0.65);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
