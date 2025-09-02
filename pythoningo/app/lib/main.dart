import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(FlashcardApp());
}

class FlashcardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English-Polish Flashcards',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FlashcardScreen(),
    );
  }
}

class FlashcardScreen extends StatefulWidget {
  @override
  _FlashcardScreenState createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<dynamic> _allItems = [];
  dynamic _currentItem;
  String _correctAnswer = '';
  List<String> _answers = [];
  String _feedback = '';
  Color _feedbackColor = Colors.transparent;
  String _translation = '';
  String _example = '';
  bool _exampleVisible = false;
  bool _buttonsDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final String response = await rootBundle.loadString('assets/dictionary.json');
    final data = await json.decode(response);
    setState(() {
      _allItems = data['entries'];
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    setState(() {
      _feedback = '';
      _feedbackColor = Colors.transparent;
      _translation = '';
      _example = '';
      _exampleVisible = false;
      _buttonsDisabled = false;

      _currentItem = _allItems[Random().nextInt(_allItems.length)];
      _correctAnswer = _currentItem['polish'];

      _answers = _getRandomAnswers();
      _answers.shuffle();
    });
  }

  List<String> _getRandomAnswers() {
    List<String> answers = [_correctAnswer];
    while (answers.length < 4) {
      var randomItem = _allItems[Random().nextInt(_allItems.length)];
      if (!answers.contains(randomItem['polish'])) {
        answers.add(randomItem['polish']);
      }
    }
    return answers;
  }

  void _checkAnswer(String chosenAnswer) {
    setState(() {
      _buttonsDisabled = true;
      if (chosenAnswer == _correctAnswer) {
        _feedback = 'Correct!';
        _feedbackColor = Colors.green;
      } else {
        _feedback = 'Incorrect. Correct was: $_correctAnswer';
        _feedbackColor = Colors.red;
      }
      _showExample();
      _translation = 'Translation: "${_currentItem["example_polish"]}"';
    });
  }

  void _showExample() {
    setState(() {
      _example = 'e.g., "${_currentItem["example_english"]}"';
      _exampleVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('English-Polish Flashcards'),
      ),
      body: _currentItem == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _currentItem['english'],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  if (_exampleVisible)
                    Text(
                      _example,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                  if (!_exampleVisible)
                    TextButton(
                      onPressed: _showExample,
                      child: Text('Show Example'),
                    ),
                  SizedBox(height: 20),
                  ..._answers.map((answer) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ElevatedButton(
                        onPressed: _buttonsDisabled ? null : () => _checkAnswer(answer),
                        child: Text(answer),
                      ),
                    );
                  }).toList(),
                  SizedBox(height: 20),
                  Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: _feedbackColor, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  if (_buttonsDisabled)
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text('Next Question'),
                    ),
                ],
              ),
            ),
    );
  }
}
