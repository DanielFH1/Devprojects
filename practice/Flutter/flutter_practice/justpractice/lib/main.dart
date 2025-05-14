import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PDF Generator",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
      });
    }
  }

  Future<void> _takePicture() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    }
  }

  Future<void> _createPdf() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please pick an image first")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();

      //각 이미지를 pdf페이지로 추가
      for (var imageFile in _selectedImages) {
        final image = pw.MemoryImage(
          await imageFile.readAsBytes(),
        );

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image),
              );
            },
          ),
        );
      }

      //저장 경로 설정
      final output = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final file = File('${output.path}/image_$timestamp.pdf');

      //pdf파일 저장
      await file.writeAsBytes(await pdf.save());

      //pdf 출력
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: "images_$timestamp.pdf");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pdf 생성 중 오류가 발생하였습니다 : $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("사진 2 pdf"),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _selectedImages.isEmpty
                      ? const Center(child: Text("선택된 이미지가 없습니다."))
                      : GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    onPressed: () => _removeImage(index),
                                    color: Colors.red,
                                    icon: const Icon(Icons.remove_circle),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text("Camera"),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          label: const Text("Gallery"),
                          icon: const Icon(Icons.photo_library),
                        ),
                        ElevatedButton.icon(
                          onPressed: _createPdf,
                          label: const Text("Make PDF!!"),
                          icon: const Icon(Icons.picture_as_pdf),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ))
              ],
            ),
    );
  }
}
