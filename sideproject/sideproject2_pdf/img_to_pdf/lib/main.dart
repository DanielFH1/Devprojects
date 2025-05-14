import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이미지 PDF 변환기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4355B9),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const ImageToPdfScreen(),
    );
  }
}

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _statusMessage = '';
  String? _customSavePath;

  // 광고 관련 변수
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdLoaded = false;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initAds();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _initAds() {
    _loadBannerAd();
    _loadInterstitialAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _getAdUnitId(AdType.banner),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          Future.delayed(const Duration(minutes: 1), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _getAdUnitId(AdType.interstitial),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isInterstitialAdReady = false;
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              _isInterstitialAdReady = false;
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (_) => _isInterstitialAdReady = false,
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialAdReady) {
      _interstitialAd?.show();
    } else {
      _loadInterstitialAd();
    }
  }

  String _getAdUnitId(AdType type) {
    final isDebug = kDebugMode;
    if (Platform.isAndroid) {
      switch (type) {
        case AdType.banner:
          return isDebug
              ? 'ca-app-pub-3940256099942544/6300978111'
              : 'ca-app-pub-1436097168733294/2748358353';
        case AdType.interstitial:
          return isDebug
              ? 'ca-app-pub-3940256099942544/1033173712'
              : 'ca-app-pub-1436097168733294/8830550974';
      }
    } else if (Platform.isIOS) {
      switch (type) {
        case AdType.banner:
          return isDebug
              ? 'ca-app-pub-3940256099942544/2934735716'
              : 'ca-app-pub-1436097168733294/2748358353';
        case AdType.interstitial:
          return isDebug
              ? 'ca-app-pub-3940256099942544/4411468910'
              : 'ca-app-pub-1436097168733294/8830550974';
      }
    }
    return '';
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.clear();
          _selectedImages.addAll(images.map((e) => File(e.path)));
        });
      }
    } catch (e) {
      _showSnackBar('이미지 선택 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _selectedImages.add(File(photo.path)));
      }
    } catch (e) {
      _showSnackBar('사진 촬영 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) {
      _showSnackBar('먼저 이미지를 선택해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '변환 중...';
    });

    try {
      if (!await _requestPermissions()) {
        _showSnackBar('PDF를 저장하려면 저장소 접근 권한이 필요합니다.');
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }

      final pdf = pw.Document();
      for (final imageFile in _selectedImages) {
        final image = await _loadImage(imageFile);
        if (image != null) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(child: pw.Image(image)),
            ),
          );
        }
      }

      final output = await _getOutputPath();
      final file = File(output);
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      _showInterstitialAd();
      Future.delayed(const Duration(milliseconds: 500), () {
        _showCompletionDialog(file);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      _showSnackBar('PDF 변환 중 오류가 발생했습니다: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    return Platform.isAndroid
        ? await Permission.storage.request().isGranted
        : true;
  }

  Future<pw.MemoryImage?> _loadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return pw.MemoryImage(bytes);
    } catch (e) {
      _showSnackBar('이미지 로딩 중 오류가 발생했습니다: $e');
      return null;
    }
  }

  Future<String> _getDefaultSavePath() async {
    try {
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Download');
        if (await directory.exists()) return directory.path;
        return (await getExternalStorageDirectory())?.path ??
            '/storage/emulated/0/Download';
      }
      return (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  Future<String> _getOutputPath() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final savePath = _customSavePath ?? await _getDefaultSavePath();
    return path.join(savePath, 'PDF_변환_$timestamp.pdf');
  }

  Future<void> _showPathSelectionDialog() async {
    final defaultPath = await _getDefaultSavePath();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('저장 경로 선택'),
            content: Text('현재 경로: ${_customSavePath ?? defaultPath}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  _customSavePath = defaultPath;
                  Navigator.pop(context);
                  _showSnackBar('기본 저장 경로가 설정되었습니다');
                },
                child: const Text('기본 경로 사용'),
              ),
            ],
          ),
    );
  }

  void _showCompletionDialog(File pdfFile) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('PDF 변환 완료', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('파일명: ${path.basename(pdfFile.path)}'),
                Text('위치: ${path.dirname(pdfFile.path)}'),
                Text('페이지: ${_selectedImages.length}장'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(path.dirname(pdfFile.path));
                },
                child: const Text('위치 열기'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  OpenFile.open(pdfFile.path);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('PDF 열기'),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 PDF 변환기'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: _showPathSelectionDialog,
            tooltip: '저장 경로 설정',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSelectionCard(theme),
                  const SizedBox(height: 16),
                  _buildImageInfoRow(theme),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        _selectedImages.isEmpty
                            ? _buildEmptyImageMessage(theme)
                            : _buildImageList(),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading) _buildProgressIndicator(theme),
                  const SizedBox(height: 16),
                  _buildConvertButton(theme),
                  if (_customSavePath != null) _buildSavePathInfo(),
                ],
              ),
            ),
          ),
          _buildAdBanner(),
        ],
      ),
    );
  }

  Widget _buildImageSelectionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '이미지 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text(
                      '갤러리에서 선택',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text(
                      '카메라로 촬영',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageInfoRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '선택된 이미지: ${_selectedImages.length}개',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_selectedImages.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('모두 지우기'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => setState(() => _selectedImages.clear()),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    return Column(
      children: [
        LinearProgressIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
        ),
        const SizedBox(height: 8),
        Text(_statusMessage),
      ],
    );
  }

  Widget _buildConvertButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _selectedImages.isEmpty || _isLoading ? null : _convertToPdf,
      icon: const Icon(Icons.picture_as_pdf),
      label: const Text('PDF로 변환하기'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSavePathInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '저장 경로: $_customSavePath',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner() {
    return _isBannerAdLoaded && _bannerAd != null
        ? SizedBox(
          width: double.infinity,
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        )
        : Container(
          width: double.infinity,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.grey.shade200),
          child: Text(
            '광고 로딩 중...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        );
  }

  Widget _buildEmptyImageMessage(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_search,
            size: 70,
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text('아직 선택된 이미지가 없습니다', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '갤러리에서 이미지를 선택하거나\n카메라로 사진을 촬영하세요',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageList() {
    return ListView.builder(
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                _selectedImages[index],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              path.basename(_selectedImages[index].path),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeImage(index),
            ),
          ),
        );
      },
    );
  }
}

enum AdType { banner, interstitial }
