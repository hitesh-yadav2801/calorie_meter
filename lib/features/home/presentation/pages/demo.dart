import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final picker = ImagePicker();
  late Interpreter _interpreter;
  String _foodResult = "";

  // Nutrition data for a few food items (extend this as needed)
  Map<String, Map<String, double>> nutritionData = {
    "Apple": {"Calories": 52, "Proteins": 0.3, "Fats": 0.2, "Carbs": 14},
    "Banana": {"Calories": 89, "Proteins": 1.1, "Fats": 0.3, "Carbs": 23},
    "Pizza": {"Calories": 266, "Proteins": 11, "Fats": 10, "Carbs": 33},
    "Burger": {"Calories": 295, "Proteins": 17, "Fats": 12, "Carbs": 32},
    "Peanuts": {"Calories": 567, "Proteins": 15, "Fats": 57, "Carbs": 67},
    "Orange": {"Calories": 47, "Proteins": 1.1, "Fats": 0.2, "Carbs": 10},
  };

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  /// **Loads the EfficientNet-Lite model**
  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/efficientnet_lite.tflite');
    print("Model loaded!");
  }

  /// **Loads labels from imagenet_labels.txt**
  Future<List<String>> loadLabels() async {
    // Load the labels from the imagenet_labels.txt file
    String labelData = await rootBundle.loadString('assets/imagenet_labels.txt');
    print("Labels loaded!");
    List<String> labels = labelData.split('\n');
    return labels;
  }

  /// **Preprocesses the image to match model input (1x224x224x3, Float32)**
  Future<List<List<List<List<double>>>>> preprocessImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception("Failed to decode image.");
    }

    img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

    List<List<List<List<double>>>> input = List.generate(
      1,
          (_) => List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0, // Red
              pixel.g / 255.0, // Green
              pixel.b / 255.0, // Blue
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// **Runs inference on the image and gets food classification result**
  Future<void> classifyImage(File image) async {
    try {
      // Load the labels dynamically
      List<String> labels = await loadLabels();

      var input = await preprocessImage(image);
      var output = List.filled(1 * 1000, 0.0).reshape([1, 1000]);  // Adjusted to match EfficientNet's output
      print(output);
      _interpreter.run(input, output);

      // Find the index of the highest probability
      int maxIndex = output[0].indexOf(output[0].reduce((double a, double b) => a > b ? a : b));
      print("Predicted index: $maxIndex");

      // Check if the predicted index is within bounds of the labels array
      if (maxIndex < labels.length) {
        // Split the label properly to extract the food name after the colon
        String labelLine = labels[maxIndex];
        List<String> parts = labelLine.split(':');  // Split by colon to get index and food name
        if (parts.length > 1) {
          String foodName = parts[1].split(',')[0].trim().replaceAll("'", "");
          setState(() {
            _foodResult = foodName;
          });
          print("Detected food: $_foodResult");
        }
      } else {
        print("Predicted index ($maxIndex) is out of bounds.");
        setState(() {
          _foodResult = "Unknown food item";  // Default message for out-of-bounds prediction
        });
      }
    } catch (e) {
      print("Error classifying image: $e");
    }
  }

  /// **Picks an image from gallery or camera**
  Future<void> getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      File image = File(pickedFile.path);
      setState(() {
        _image = image;
      });
      classifyImage(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Calorie Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? const Text('No image selected.', style: TextStyle(fontSize: 16))
                : Image.file(_image!, height: 200),
            const SizedBox(height: 20),
            Text(
              _foodResult.isEmpty ? "Detecting food..." : "Detected: $_foodResult",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_foodResult.isNotEmpty && nutritionData.containsKey(_foodResult))
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    Text("Calories: ${nutritionData[_foodResult]!["Calories"]} kcal"),
                    Text("Proteins: ${nutritionData[_foodResult]!["Proteins"]} g"),
                    Text("Fats: ${nutritionData[_foodResult]!["Fats"]} g"),
                    Text("Carbs: ${nutritionData[_foodResult]!["Carbs"]} g"),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => getImage(ImageSource.camera),
                  child: const Text('Capture Image'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => getImage(ImageSource.gallery),
                  child: const Text('Pick from Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
