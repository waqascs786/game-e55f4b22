import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

enum _Screen { packSelect, levelSelect, playing, complete }

class GameEngine extends StatefulWidget {
  final GameConfig config;
  final int currentLevel;
  final int coins;
  final Function(int) onLevelComplete;
  final VoidCallback onHintUsed;
  final VoidCallback? onNavigatePrev;
  final VoidCallback? onNavigateNext;

  const GameEngine({
    super.key,
    required this.config,
    required this.currentLevel,
    required this.coins,
    required this.onLevelComplete,
    required this.onHintUsed,
    this.onNavigatePrev,
    this.onNavigateNext,
  });

  @override
  State<GameEngine> createState() => _GameEngineState();
}

class _GameEngineState extends State<GameEngine> with SingleTickerProviderStateMixin {
  String _currentAnswer = '';
  bool _showComplete = false;
  late AnimationController _animController;
  final _random = Random();

  List<String> _selectedOptions = [];
  List<String> _shuffledLetters = [];
  List<int> _usedLetterIndices = [];
  String _typedAnswer = '';
  _Screen _screen = _Screen.packSelect;
  String? _selectedPackId;
  int _internalLevelIndex = 0;

  void _playSound() {
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  Color? _getColor(String key) {
    final value = widget.config.design['colors']?[key];
    if (value is int) return Color(value);
    return Colors.white;
  }

  bool get _hasPacks => widget.config.hasPacks;

  List<GameLevel> get _currentPackLevels {
    if (_selectedPackId == null) return widget.config.levels;
    final pack = widget.config.packs.firstWhere((p) => p.id == _selectedPackId, orElse: () => widget.config.packs.isNotEmpty ? widget.config.packs.first : GameLevelPack(id: '', name: ''));
    final ids = pack.levelIds.toSet();
    return widget.config.levels.where((l) => ids.contains(l.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _screen = _hasPacks ? _Screen.packSelect : _Screen.levelSelect;
    _initLevel();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLevel != widget.currentLevel) {
      _initLevel();
    }
  }

  void _initLevel() {
    _currentAnswer = '';
    _showComplete = false;
    _selectedOptions = [];
    _usedLetterIndices = [];
    _typedAnswer = '';
    final packLevels = _currentPackLevels;
    final idx = _hasPacks ? _internalLevelIndex : widget.currentLevel;
    if (_screen == _Screen.playing && packLevels.isNotEmpty && idx < packLevels.length) {
      final level = packLevels[idx];
      final qType = level.questionType;
      if (qType == 'anagram' || qType == 'wordscramble') {
        _shuffledLetters = level.answer.toUpperCase().split('');
        _shuffledLetters.shuffle(_random);
      } else {
        _shuffledLetters = _generateLetters(level.answer.toUpperCase());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _getColor('background'),
      child: _showComplete
          ? _buildCompleteScreen()
          : _screen == _Screen.packSelect
              ? _buildPackSelectScreen()
              : _screen == _Screen.levelSelect
                  ? _buildLevelSelectScreen()
                  : _buildGameScreen(),
    );
  }

  Widget _buildGameScreen() {
    if (widget.config.levels.isEmpty) return _emptyScreen();
    final packLevels = _currentPackLevels;
    if (packLevels.isEmpty) return _emptyScreen();
    final idx = _hasPacks ? _internalLevelIndex : widget.currentLevel;
    if (idx >= packLevels.length) return _allDoneScreen();
    final level = packLevels[idx];
    final qType = level.questionType;

    switch (qType) {
      case 'mcq':
        return _buildMCQScreen(level);
      case 'truefalse':
        return _buildTrueFalseScreen(level);
      case 'typeanswer':
        return _buildTypeAnswerScreen(level);
      case 'fillblank':
        return _buildTypeAnswerScreen(level);
      case 'multiselect':
        return _buildMultiSelectScreen(level);
      case 'anagram':
        return _buildAnagramScreen(level);
      case 'hangman':
        return _buildHangmanScreen(level);
      case 'wordscramble':
        return _buildAnagramScreen(level);
      case 'ordering':
        return _buildOrderingScreen(level);
      case 'classification':
        return _buildClassificationScreen(level);
      case 'emojipairing':
        return _buildPairingScreen(level);
      case 'wordsearch1':
      case 'wordsearch2':
      case 'crossword':
        return _buildWordSearchScreen(level);
      default:
        return _buildLetterTapScreen(level);
    }
  }

  int _getImageCount(String qType) {
    if (qType == '4emoji1word' || qType.startsWith('4pic')) return 4;
    if (qType == '3emoji1word' || qType.startsWith('3pic')) return 3;
    if (qType == '2emoji1word' || qType == '2emoji1wordplus' || qType.startsWith('2pic')) return 2;
    if (qType == '1emoji1word') return 1;
    return 1;
  }

  List<String> _getUrls(GameLevel level) {
    final all = <String>[];
    if (level.imageUrl.isNotEmpty) all.add(level.imageUrl);
    all.addAll(level.imageUrls.where((u) => u.isNotEmpty));
    return all;
  }

  Widget _buildEmojiTile(String emoji) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(emoji, style: const TextStyle(fontSize: 36))),
      ),
    );
  }

  Widget _buildImageArea(GameLevel level) {
    final qType = level.questionType;
    final isEmoji = qType.contains('emoji');
    final count = _getImageCount(qType);
    final emojis = level.emojis;

    if (isEmoji && emojis.isNotEmpty) {
      if (count == 1) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 100,
          child: Center(child: Text(emojis[0], style: const TextStyle(fontSize: 72))),
        );
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: count <= 2 ? 120.0 : (count == 3 ? 100.0 : 80.0),
        child: Row(
          children: [
            for (int i = 0; i < emojis.length && i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _buildEmojiTile(emojis[i])),
            ],
          ],
        ),
      );
    }

    final urls = _getUrls(level);
    if (urls.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 120,
        decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
      );
    }

    if (count == 1) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 180,
        decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(urls[0], fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 48, color: Colors.grey))),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: count <= 2 ? 140.0 : (count == 3 ? 110.0 : 90.0),
      child: Row(
        children: [
          for (int i = 0; i < urls.length && i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF30363D), borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(urls[i], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, size: 24, color: Colors.grey))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== LETTER TAP (1pic1word, 2pic1word, etc.) ==========
  Widget _buildLetterTapScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          Expanded(child: _buildImageArea(level)),
          _buildAnswerSlots(answer),
          const SizedBox(height: 8),
          _buildLetterGrid(answer),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== MCQ ==========
  Widget _buildMCQScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: level.options.map((opt) {
                final selected = _selectedOptions.contains(opt);
                final isCorrect = opt.toUpperCase() == level.answer.toUpperCase();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      setState(() {
                        _selectedOptions = [opt];
                        if (isCorrect) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong! Try again'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected ? _getColor('primary') : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? _getColor('primary')! : Colors.grey.shade700),
                      ),
                      child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== TRUE / FALSE ==========
  Widget _buildTrueFalseScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      final correct = level.answer.toUpperCase() == 'TRUE';
                      setState(() {
                        _selectedOptions = ['True'];
                        if (correct) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _selectedOptions.contains('True') ? Colors.green : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Center(child: Text('TRUE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _playSound();
                      final correct = level.answer.toUpperCase() == 'FALSE';
                      setState(() {
                        _selectedOptions = ['False'];
                        if (correct) {
                          _animController.forward(from: 0);
                          _showComplete = true;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wrong!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _selectedOptions.contains('False') ? Colors.red : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Center(child: Text('FALSE', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== TYPE ANSWER ==========
  Widget _buildTypeAnswerScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _typedAnswer.isEmpty ? 'Type your answer...' : _typedAnswer,
                          style: TextStyle(color: _typedAnswer.isEmpty ? Colors.grey : Colors.white, fontSize: 18),
                        ),
                      ),
                      if (_typedAnswer.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _typedAnswer = _typedAnswer.substring(0, _typedAnswer.length - 1)),
                          child: const Icon(Icons.backspace, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                  children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _typedAnswer += letter);
                        if (_typedAnswer.length == answer.length) {
                          if (_typedAnswer == answer) {
                            _animController.forward(from: 0);
                            setState(() => _showComplete = true);
                          } else {
                            setState(() => _typedAnswer = '');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wrong answer!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: _getColor('primary'), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== MULTI SELECT ==========
  Widget _buildMultiSelectScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: level.options.map((opt) {
                final selected = _selectedOptions.contains(opt);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedOptions.remove(opt);
                        } else {
                          _selectedOptions.add(opt);
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: selected ? _getColor('primary') : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? _getColor('primary')! : Colors.grey.shade700),
                      ),
                      child: Row(
                        children: [
                          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOptions.isEmpty ? null : () {
                  final correctAnswers = level.answer.split(',').map((s) => s.trim().toUpperCase()).toList();
                  final selectedUpper = _selectedOptions.map((s) => s.toUpperCase()).toList();
                  correctAnswers.sort();
                  selectedUpper.sort();
                  if (listEquals(correctAnswers, selectedUpper)) {
                    _animController.forward(from: 0);
                    setState(() => _showComplete = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not quite right!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ANAGRAM / WORD SCRAMBLE ==========
  Widget _buildAnagramScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          _buildAnswerSlots(answer),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: List.generate(_shuffledLetters.length, (i) {
                final used = _usedLetterIndices.contains(i);
                return GestureDetector(
                  onTap: used ? null : () {
                    _playSound();
                    setState(() {
                      _currentAnswer += _shuffledLetters[i];
                      _usedLetterIndices.add(i);
                    });
                    _checkAnswer(answer);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: used ? Colors.grey.shade800 : _getColor('primary'),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text(_shuffledLetters[i], style: TextStyle(color: used ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ),
                );
              }),
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== HANGMAN ==========
  Widget _buildHangmanScreen(GameLevel level) {
    final answer = level.answer.toUpperCase();
    final wrongGuesses = _selectedOptions.where((o) => !answer.contains(o)).toList();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 4),
          Text('Wrong guesses: ${wrongGuesses.length}/6', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: answer.split('').map((char) {
                final revealed = _currentAnswer.contains(char);
                return Container(
                  width: 32, height: 36, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: revealed ? _getColor('primary') : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Center(child: Text(revealed ? char : '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
            children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
              final used = _selectedOptions.contains(letter);
              final inWord = answer.contains(letter);
              return GestureDetector(
                onTap: used ? null : () {
                  _playSound();
                  setState(() {
                    _selectedOptions.add(letter);
                    if (inWord) {
                      for (int i = 0; i < answer.length; i++) {
                        if (answer[i] == letter && !_currentAnswer.contains(letter)) {
                          _currentAnswer += letter;
                        }
                      }
                    }
                  });
                  _checkAnswer(answer);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: used ? (inWord ? Colors.green.shade800 : Colors.red.shade800) : _getColor('primary'),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(letter, style: TextStyle(color: used ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
              );
            }).toList(),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== ORDERING ==========
  Widget _buildOrderingScreen(GameLevel level) {
    if (_selectedOptions.isEmpty && level.options.isNotEmpty) {
      _selectedOptions = List<String>.from(level.options)..shuffle(_random);
    }
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _selectedOptions.removeAt(oldIndex);
                  _selectedOptions.insert(newIndex, item);
                });
              },
              children: _selectedOptions.asMap().entries.map((entry) {
                return Container(
                  key: ValueKey(entry.value),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Row(
                    children: [
                      Text('${entry.key + 1}.', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white, fontSize: 16))),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final correct = level.answer.split('|').map((s) => s.trim()).toList();
                  if (listEquals(_selectedOptions, correct)) {
                    _animController.forward(from: 0);
                    setState(() => _showComplete = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not in the right order!'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check Order', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== CLASSIFICATION ==========
  Widget _buildClassificationScreen(GameLevel level) {
    final categories = level.options;
    final correctMap = <String, List<String>>{};
    try {
      final decoded = jsonDecode(level.answer);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          correctMap[k] = List<String>.from(v);
        });
      }
    } catch (_) {}
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                children: categories.map((cat) {
                  final selected = _selectedOptions.contains(cat);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) _selectedOptions.remove(cat);
                        else _selectedOptions.add(cat);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _getColor('primary') : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? _getColor('primary')! : Colors.grey.shade700),
                      ),
                      child: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOptions.isEmpty ? null : () {
                  _animController.forward(from: 0);
                  setState(() => _showComplete = true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== EMOJI PAIRING ==========
  Widget _buildPairingScreen(GameLevel level) {
    final left = level.emojis.length >= 2 ? [level.emojis[0], level.emojis[1]] : level.emojis;
    final right = level.emojis.length >= 4 ? [level.emojis[2], level.emojis[3]] : level.emojis.reversed.toList();
    final shuffledRight = List<String>.from(right)..shuffle(_random);

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: left.map((emoji) {
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: shuffledRight.map((emoji) {
                        final matched = _selectedOptions.contains(emoji);
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: matched ? const Color(0xFF0D2818) : const Color(0xFF21262D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: matched ? Colors.greenAccent : Colors.grey.shade700),
                          ),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _animController.forward(from: 0);
                  setState(() => _showComplete = true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary'), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Check', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== WORD SEARCH ==========
  Widget _buildWordSearchScreen(GameLevel level) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildQuestion(level),
          const SizedBox(height: 8),
          Expanded(child: _buildImageArea(level)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Text(
                level.hint.isNotEmpty ? level.hint : 'Find the hidden words in the grid!',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _buildActionButtons(level),
        ],
      ),
    );
  }

  // ========== PACK SELECT ==========
  Widget _buildPackSelectScreen() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('Level Packs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.9),
              itemCount: widget.config.packs.length,
              itemBuilder: (context, index) {
                final pack = widget.config.packs[index];
                final locked = pack.locked;
                final name = pack.name.isNotEmpty ? pack.name : 'Pack ${index + 1}';
                final iconUrl = pack.iconUrl;
                final levelCount = pack.levelIds.length;
                return GestureDetector(
                  onTap: locked ? null : () => setState(() { _selectedPackId = pack.id; _screen = _Screen.levelSelect; }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFF21262D) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: locked ? Colors.grey.shade800 : (_getColor('primary') ?? Colors.white).withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        iconUrl.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(iconUrl, width: 56, height: 56, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(locked ? Icons.lock : Icons.inventory_2, size: 32, color: Colors.grey)))
                            : Icon(locked ? Icons.lock : Icons.inventory_2, size: 32, color: locked ? Colors.grey : _getColor('primary')),
                        const SizedBox(height: 8),
                        Text(locked ? 'Locked' : name, style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        if (!locked) Text('$levelCount levels', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== LEVEL SELECT ==========
  Widget _buildLevelSelectScreen() {
    final packLevels = _currentPackLevels;
    final pack = _selectedPackId != null ? widget.config.packs.firstWhere((p) => p.id == _selectedPackId, orElse: () => GameLevelPack(id: '', name: '')) : GameLevelPack(id: '', name: 'All Levels');
    final title = _hasPacks ? (pack.name.isNotEmpty ? pack.name : 'Levels') : 'All Levels';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _hasPacks ? () => setState(() { _screen = _Screen.packSelect; _selectedPackId = null; }) : null,
                child: Icon(Icons.arrow_back, color: _hasPacks ? Colors.white : Colors.grey, size: 24),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: packLevels.length,
              itemBuilder: (context, index) {
                final level = packLevels[index];
                final url = level.imageUrl;
                final emojis = level.emojis;
                final locked = level.locked;
                return GestureDetector(
                  onTap: locked ? null : () => setState(() {
                    _internalLevelIndex = index;
                    _screen = _Screen.playing;
                    _initLevel();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFF1C1F24) : const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        if (emojis.isNotEmpty)
                          Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(emojis.first, style: TextStyle(fontSize: 32, color: locked ? Colors.grey : null)))),
                        if (emojis.isEmpty && url.isNotEmpty)
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                            errorBuilder: (_, __, ___) => Center(child: Text('${index + 1}', style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))))),
                        if (emojis.isEmpty && url.isEmpty)
                          Center(child: Text('${index + 1}', style: TextStyle(color: locked ? Colors.grey : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                        if (locked)
                          Container(
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Icon(Icons.lock, color: Colors.white70, size: 20)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ========== SHARED WIDGETS ==========
  Widget _emptyScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.games, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No levels available', style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _allDoneScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 16),
          const Text('All levels complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Coins: ${widget.coins}', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final packLevels = _currentPackLevels;
    final idx = _hasPacks ? _internalLevelIndex : widget.currentLevel;
    final hasPrev = _hasPacks ? idx > 0 : widget.onNavigatePrev != null;
    final hasNext = _hasPacks ? idx < packLevels.length - 1 : widget.onNavigateNext != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: hasPrev ? () {
              setState(() {
                if (_hasPacks) { _internalLevelIndex--; _initLevel(); }
                else widget.onNavigatePrev?.call();
              });
            } : null,
            child: Icon(Icons.chevron_left, color: hasPrev ? Colors.white : Colors.grey, size: 28),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _getColor('primary'), borderRadius: BorderRadius.circular(6)),
            child: Text('Level: ${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _getColor('secondary'), borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const Icon(Icons.monetization_on, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text('${widget.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          GestureDetector(
            onTap: hasNext ? () {
              setState(() {
                if (_hasPacks) { _internalLevelIndex++; _initLevel(); }
                else widget.onNavigateNext?.call();
              });
            } : null,
            child: Icon(Icons.chevron_right, color: hasNext ? Colors.white : Colors.grey, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(GameLevel level) {
    if (level.question.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(level.question, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }

  Widget _buildAnswerSlots(String answer) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(answer.length, (i) {
          final char = i < _currentAnswer.length ? _currentAnswer[i] : '';
          return Container(
            width: 34, height: 34, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: char.isNotEmpty ? _getColor('primary') : const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text(char, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          );
        }),
      ),
    );
  }

  Widget _buildLetterGrid(String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
        children: _shuffledLetters.asMap().entries.map((entry) {
          final used = _usedLetterIndices.contains(entry.key);
          return GestureDetector(
            onTap: used ? null : () {
              _playSound();
              setState(() {
                _currentAnswer += entry.value;
                _usedLetterIndices.add(entry.key);
              });
              _checkAnswer(answer);
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: used ? Colors.grey.shade800 : _getColor('primary'),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(entry.value, style: TextStyle(color: used ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(GameLevel level) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.people, size: 18), label: const Text('Ask Friends'),
            style: ElevatedButton.styleFrom(backgroundColor: _getColor('secondary')),
          ),
          ElevatedButton.icon(
            onPressed: widget.coins >= 20 ? () { widget.onHintUsed(); _useHint(); } : null,
            icon: const Icon(Icons.lightbulb, size: 18), label: const Text('Hints (20)'),
            style: ElevatedButton.styleFrom(backgroundColor: _getColor('primary')),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteScreen() {
    final packLevels = _currentPackLevels;
    final idx = _hasPacks ? _internalLevelIndex : widget.currentLevel;
    final level = idx < packLevels.length ? packLevels[idx] : packLevels.last;
    final isLast = idx >= packLevels.length - 1;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut)),
            child: const Icon(Icons.check_circle, size: 100, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text('Well Done!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('+${level.coinsReward} coins', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 20)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showComplete = false;
                if (_hasPacks) {
                  if (isLast) {
                    _screen = _Screen.levelSelect;
                    _selectedPackId = null;
                    _internalLevelIndex = 0;
                  } else {
                    _internalLevelIndex++;
                    _initLevel();
                  }
                } else {
                  widget.onLevelComplete(level.coinsReward);
                }
              });
              if (!_hasPacks) widget.onLevelComplete(level.coinsReward);
            },
            child: Text(isLast ? 'Back to Levels' : 'Next Level'),
          ),
        ],
      ),
    );
  }

  void _checkAnswer(String answer) {
    if (_currentAnswer.length == answer.length) {
      if (_currentAnswer == answer) {
        _playSound();
        _animController.forward(from: 0);
        setState(() => _showComplete = true);
      } else {
        setState(() => _currentAnswer = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong answer! Try again'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _useHint() {
    final packLevels = _currentPackLevels;
    final idx = _hasPacks ? _internalLevelIndex : widget.currentLevel;
    if (idx >= packLevels.length) return;
    final answer = packLevels[idx].answer.toUpperCase();
    if (_currentAnswer.length < answer.length) {
      setState(() => _currentAnswer += answer[_currentAnswer.length]);
      _checkAnswer(answer);
    }
  }

  List<String> _generateLetters(String answer) {
    final chars = answer.split('');
    final all = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    final needed = (widget.config.settings['amountOfLetters'] ?? 14) - chars.length;
    for (var i = 0; i < needed; i++) {
      chars.add(all[_random.nextInt(all.length)]);
    }
    chars.shuffle(_random);
    return chars;
  }
}
