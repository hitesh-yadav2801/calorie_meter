import 'dart:io';
import 'package:calorie_meter/features/home/presentation/pages/gemma_test_screen.dart';
import 'package:calorie_meter/features/home/presentation/pages/home_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  _ModelManagerScreenState createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _modelPath = '';

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final directory = await getApplicationDocumentsDirectory();
    print("Directory: ${directory.path}");
    final modelFile = File('${directory.path}/gemma_2b_it.gguf');
    if (modelFile.existsSync()) {
      setState(() => _modelPath = modelFile.path);
    }
  }

  Future<void> _downloadModel() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/gemma_2b_it.gguf';
    final file = File(filePath);

    if (file.existsSync()) {
      setState(() => _modelPath = filePath);
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    try {
      const modelUrl = 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf';

      await Dio().download(
        modelUrl,
        filePath,
        onReceiveProgress: (received, total) {
          setState(() {
            _progress = total != -1 ? received / total : 0;
          });
        },
      );

      setState(() {
        _isDownloading = false;
        _modelPath = filePath;
      });
    } catch (e) {
      setState(() => _isDownloading = false);
      print("Error downloading model: $e");
    }
  }

  void _loadModel() {
    if (_modelPath.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(modelPath: _modelPath)),
    );
  }

  void _goToGemmaTestScreen() {
    if (_modelPath.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GemmaTestScreen(modelPath: _modelPath)),
    );
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      /// Check Android version
      if (await DeviceInfoPlugin().androidInfo.then((value) => value.version.sdkInt) >= 33) {
        /// For Android 13 and above
        final statuses = await [
          Permission.photos,
          Permission.camera,
          Permission.mediaLibrary,
          Permission.videos,
        ].request();

        debugPrint('Permissions status: \n'
            'Photos: ${statuses[Permission.photos]}\n'
            'Camera: ${statuses[Permission.camera]}\n'
            'Media Library: ${statuses[Permission.mediaLibrary]}\n'
            'Videos: ${statuses[Permission.videos]}');
      } else {
        /// For Android 10-12
        final statuses = await [
          Permission.photos,
          Permission.camera,
          Permission.storage,
        ].request();

        debugPrint('Permissions status: \n'
            'Photos: ${statuses[Permission.photos]}\n'
            'Camera: ${statuses[Permission.camera]}\n'
            'Storage: ${statuses[Permission.storage]}');
      }
    } else {
      // For iOS
      final statuses = await [
        Permission.photos,
        Permission.camera,
      ].request();

      print('Permissions status: \n'
          'Photos: ${statuses[Permission.photos]}\n'
          'Camera: ${statuses[Permission.camera]}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download or Load Model')),
      body: Center(
        child: _isDownloading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Downloading Model...'),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: LinearProgressIndicator(value: _progress),
            ),
            Text('${(_progress * 100).toStringAsFixed(1)}%'),
          ],
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_modelPath.isEmpty)
              ElevatedButton(
                onPressed: _downloadModel,
                child: const Text('Download Model'),
              )
            else
              ElevatedButton(
                onPressed: _loadModel,
                child: const Text('Load Model and Start Chat'),
              ),

            if (_modelPath.isNotEmpty)
              ElevatedButton(
                onPressed: _goToGemmaTestScreen,
                child: const Text('Test Gemma Model'),
              ),
          ],
        ),
      ),
    );
  }
}
