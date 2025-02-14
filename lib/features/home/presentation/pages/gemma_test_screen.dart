import 'package:flutter/material.dart';
import 'package:fllama/fllama.dart';

class GemmaTestScreen extends StatefulWidget {
  final String modelPath;
  const GemmaTestScreen({super.key, required this.modelPath});

  @override
  _GemmaTestScreenState createState() => _GemmaTestScreenState();
}

class _GemmaTestScreenState extends State<GemmaTestScreen> {
  final TextEditingController _controller = TextEditingController();
  String _response = "";
  bool _isProcessing = false;

  Future<void> generateResponse() async {
    if (_controller.text.isEmpty || _isProcessing) return;

    setState(() {
      _response = "";
      _isProcessing = true;
    });

    final request = OpenAiRequest(
      maxTokens: 256,
      messages: [
        Message(Role.system, 'You are a chatbot. You reply concisely to all the user queries'),
        Message(Role.user, _controller.text),
      ],
      numGpuLayers: 99, // Recommended GPU optimization
      modelPath: widget.modelPath,
      frequencyPenalty: 0.0,
      presencePenalty: 1.1,
      topP: 1.0,
      contextSize: 2048,
      temperature: 0.1,
      logger: (log) {
        debugPrint('[fllama] $log');
      },
    );

    // Fix: Store the latest response chunk instead of appending.
    String accumulatedResponse = "";

    fllamaChat(request, (response, done) {
      accumulatedResponse = response; // Replace with the latest chunk

      setState(() {
        _response = accumulatedResponse; // Update UI with latest complete text
      });

      if (done) {
        setState(() => _isProcessing = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gemma Model Test")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter your question",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: generateResponse,
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text("Get Response"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_response, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
