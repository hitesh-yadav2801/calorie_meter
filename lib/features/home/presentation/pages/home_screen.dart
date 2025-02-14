import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:fllama/fllama.dart';

class HomeScreen extends StatefulWidget {
  final String modelPath;
  const HomeScreen({super.key, required this.modelPath});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image;
  final picker = ImagePicker();
  late Interpreter _imageInterpreter;
  String _foodResult = "";
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _imageInterpreter.close();
    super.dispose();
  }

  Future<void> loadModel() async {
    try {
      _imageInterpreter = await Interpreter.fromAsset('assets/efficientnet_lite.tflite');
      print("Model loaded successfully!");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<List<String>> loadLabels() async {
    String labelData = await rootBundle.loadString('assets/imagenet_labels.txt');
    return labelData.split('\n');
  }

  Future<List<List<List<List<double>>>>> preprocessImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Failed to decode image.");
    img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

    return List.generate(
      1,
          (_) => List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );
  }

  Future<void> classifyImage(File image) async {
    try {
      List<String> labels = await loadLabels();
      var input = await preprocessImage(image);
      var output = List.filled(1 * 1000, 0.0).reshape([1, 1000]);
      _imageInterpreter.run(input, output);

      int maxIndex = output[0].indexOf(output[0].reduce((double a, double b) => a > b ? a : b));
      if (maxIndex < labels.length) {
        String labelLine = labels[maxIndex];
        List<String> parts = labelLine.split(':');
        if (parts.length > 1) {
          String foodName = parts[1].split(',')[0].trim().replaceAll("'", "");
          setState(() {
            _foodResult = foodName;
            // _messages.clear(); // Clear previous chat when new image is selected
          });
          // Generate initial nutrition analysis
          generateNutritionalInfo(foodName);
        }
      }
    } catch (e) {
      print("Error classifying image: $e");
    }
  }

  Future<void> generateNutritionalInfo(String food) async {
    print("Generating nutritional info for $food");

    final request = OpenAiRequest(
      maxTokens: 50, // Adjusted for response size
      messages: [
        Message(
            Role.system,
            'You are a nutrition expert. Reply strictly with the following format: \n\nFood Name: [Name of the food] \nCalories: [Number of calories] \nCarbs: [Number of grams of carbohydrates] \nProtein: [Number of grams of protein] \nFats: [Number of grams of fat] \nVitamins: [List of vitamins]. If input is not a food item, respond with "Not a food item". Avoid any additional commentary.'
        ),
        Message(
            Role.user,
            'Provide a succinct nutritional overview for "$food".'
        ),
      ],
      modelPath: widget.modelPath,
      presencePenalty: 1.1,
      temperature: 0.1,
    );

    String accumulatedResponse = "";

    setState(() {
      _messages.add(ChatMessage(text: "", isUser: false));
    });

    fllamaChat(request, (response, done) {
      accumulatedResponse = response; // Update with latest chunk

      setState(() {
        _messages.last = ChatMessage(text: accumulatedResponse, isUser: false);
      });

      if (done) {
        setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> handleUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _messages.add(ChatMessage(text: "", isUser: false)); // Placeholder for AI response
      _messageController.clear();
      _isProcessing = true;
    });

    // Include full conversation history
    List<Message> chatHistory = [
      Message(Role.system, 'You are a nutrition expert. Reply concisely, respond with: Food Name, Calories, Carbs, Protein, Fats, Vitamins. If not a food item, say "Not a food item" & name of that identified item. No extra words. '),
    ];

    for (var chat in _messages) {
      chatHistory.add(Message(chat.isUser ? Role.user : Role.assistant, chat.text));
    }

    final request = OpenAiRequest(
      maxTokens: 50, // Ensures concise responses
      messages: chatHistory,
      modelPath: widget.modelPath,
      presencePenalty: 1.1,
      temperature: 0.1,
    );

    String accumulatedResponse = "";

    fllamaChat(request, (response, done) {
      accumulatedResponse = response;

      setState(() {
        _messages.last = ChatMessage(text: accumulatedResponse, isUser: false);
      });

      if (done) {
        setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _messages.add(ChatMessage(text: "", isUser: true, image: _image));
      });
      await classifyImage(File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calorie Meter'), elevation: 2),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.photo_camera), onPressed: () => getImage(ImageSource.camera)),
                IconButton(icon: const Icon(Icons.photo_library), onPressed: () => getImage(ImageSource.gallery)),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about the food...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    // enabled: !_isProcessing && _foodResult.isNotEmpty,
                  ),
                ),
                IconButton(
                  icon: Icon(_isProcessing ? Icons.hourglass_empty : Icons.send),
                  onPressed:  () => handleUserMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final File? image;

  ChatMessage({required this.text, required this.isUser, this.image});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.image != null) // Check if image exists
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Image.file(
                  message.image!,
                  width: 200, // Adjust as needed
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
