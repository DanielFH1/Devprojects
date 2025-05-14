import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이미지-PDF 변환기',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<File> selectedFiles = [];
  bool isConverting = false;
  String? pdfPath;

  Future<void> pickImages() async {
    try {
      // 파일 선택기 열기
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          selectedFiles = result.paths.map((path) => File(path!)).toList();
          pdfPath = null; // 새 파일이 선택되면 이전 PDF 경로 초기화
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 선택 오류: $e')));
    }
  }

  Future<void> convertToPdf() async {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 이미지를 선택해주세요')));
      return;
    }

    try {
      setState(() {
        isConverting = true;
      });

      // PDF 문서 생성
      final pdf = pw.Document();

      // 각 이미지를 PDF 페이지로 추가
      for (var imageFile in selectedFiles) {
        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            },
          ),
        );
      }

      // 저장 경로 가져오기
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/converted_document.pdf';

      // PDF 파일 저장
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      setState(() {
        pdfPath = filePath;
        isConverting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 파일이 저장되었습니다: $filePath')));
    } catch (e) {
      setState(() {
        isConverting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변환 오류: $e')));
    }
  }

  Future<void> openPdf() async {
    if (pdfPath != null) {
      try {
        await OpenFile.open(pdfPath!);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF 열기 오류: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지-PDF 변환기'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: pickImages,
              child: const Text('이미지 파일 선택하기'),
            ),
            const SizedBox(height: 16),
            if (selectedFiles.isNotEmpty) ...[
              Text(
                '선택된 파일: ${selectedFiles.length}개',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: selectedFiles.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Image.file(
                        selectedFiles[index],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(selectedFiles[index].path.split('/').last),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isConverting ? null : convertToPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child:
                    isConverting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('PDF로 변환하기'),
              ),
            ],
            if (pdfPath != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('PDF 파일 열기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
