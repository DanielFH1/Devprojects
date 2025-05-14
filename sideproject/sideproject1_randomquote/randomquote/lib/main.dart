import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

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

  // 로컬 JSON 데이터를 저장할 변수
  List<dynamic> _quotesData = [];

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

    // 초기화 시 JSON 데이터 로드 후 명언 가져오기
    Future.delayed(Duration(milliseconds: 300), () {
      _loadQuotesData().then((_) {
        _getRandomQuote();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // JSON 파일 로드 함수
  Future<void> _loadQuotesData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // assets/data/quotes.json 파일 로드
      final String response =
          await rootBundle.loadString('assets/data/quotes.json');
      final data = json.decode(response);

      setState(() {
        _quotesData = data;
        _isLoading = false;
      });

      print('Quotes loaded: ${_quotesData.length}');
    } catch (e) {
      print('JSON 로드 오류: $e');
      setState(() {
        _quote = "명언 데이터를 불러오는 중 오류가 발생했습니다: $e";
        _author = "";
        _isLoading = false;
      });
    }
  }

  // 랜덤 명언 선택 함수
  void _getRandomQuote() {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_quotesData.isEmpty) {
        setState(() {
          _quote = "명언 데이터가 없습니다!!!";
          _author = "";
          _isLoading = false;
        });
        return;
      }

      // 랜덤으로 명언 선택
      final random = Random();
      final randomIndex = random.nextInt(_quotesData.length);
      final quoteItem = _quotesData[randomIndex];

      final content = quoteItem['quote']; // ZenQuotes 형식 유지
      final author = quoteItem['author'];

      setState(() {
        _quote = content ?? "명언 내용이 없습니다.";
        _author = author ?? "";
        _isLoading = false;
      });

      print('Quote: $_quote');
      print('Author: $_author');

      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      print('명언 선택 오류: $e');
      setState(() {
        _quote = "명언을 선택하는 중 오류가 발생했습니다: $e";
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
                      color: colorScheme.primary.withValues(alpha: 0.7),
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
                    colorScheme.primary.withValues(alpha: 0.3),
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
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(25.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withOpacity(0.9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: FadeTransition(
                                opacity: _fadeAnimation ??
                                    AlwaysStoppedAnimation(1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.format_quote,
                                      size: 45,
                                      color: colorScheme.primary,
                                    ),
                                    SizedBox(height: 25),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          _quote,
                                          style: GoogleFonts.roboto(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            height: 1.6,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 25),
                                    if (_author.isNotEmpty)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 15, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          "- $_author",
                                          style: GoogleFonts.roboto(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.secondary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    SizedBox(height: 15),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getRandomQuote,
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
                        "새로운 명언 보기",
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
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
