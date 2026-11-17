import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cuedeck_providers.dart';

/// Deterministic local voice command and TV text search bottom sheet.
class VoiceControlSheet extends ConsumerStatefulWidget {
  const VoiceControlSheet({super.key});

  @override
  ConsumerState<VoiceControlSheet> createState() => _VoiceControlSheetState();
}

class _VoiceControlSheetState extends ConsumerState<VoiceControlSheet> {
  static const List<String> _quickVoicePrompts = <String>[
    'Sesi Aç',
    'Sesi Kıs',
    'Sessize Al',
    'beIN CONNECT Aç',
    'tabii Aç',
    'YouTube\'da Haberler',
    'Ana Ekran',
  ];

  late final TextEditingController _voiceInputController;
  late final FocusNode _voiceInputFocusNode;

  @override
  void initState() {
    super.initState();
    _voiceInputController = TextEditingController();
    _voiceInputFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cueDeckProvider.notifier).startVoiceCommandSession();
    });
  }

  @override
  void dispose() {
    _voiceInputController.dispose();
    _voiceInputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final isListening = ref.watch(
      cueDeckProvider.select((s) => s.isListeningVoice),
    );
    final lastTranscript = ref.watch(
      cueDeckProvider.select((s) => s.lastVoiceTranscript),
    );
    final lastStatus = ref.watch(
      cueDeckProvider.select((s) => s.lastCommandStatus),
    );
    final voicePermDenied = ref.watch(
      cueDeckProvider.select((s) => s.voicePermissionDenied),
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetBg =
        isDarkMode ? const Color(0xFF0E1017) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.58)
        : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final subSurfaceBg = isDarkMode ? const Color(0xFF090A0F) : Colors.white;
    final chipBg = isDarkMode ? const Color(0xFF1A1E2D) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.mic_external_on_rounded,
                  color: goldText,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sesli Komut & Akıllı TV Arama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: BorderSide(
                      color: const Color(0xFFE2A84B).withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final notifier = ref.read(cueDeckProvider.notifier);
                    if (isListening) {
                      await notifier.cancelVoiceCommandSession();
                    }
                    await notifier.triggerTvNativeVoiceAssistant();
                  },
                  icon: const Icon(Icons.assistant_rounded, size: 15),
                  label: const Text(
                    'TV Asistanını Aç',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('voice_sheet_mic_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: isListening
                      ? const Color(0xFFFF5252)
                      : const Color(0xFFE2A84B),
                  foregroundColor:
                      isListening ? Colors.white : const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  if (isListening) {
                    ref
                        .read(cueDeckProvider.notifier)
                        .stopVoiceCommandSession();
                  } else {
                    ref
                        .read(cueDeckProvider.notifier)
                        .startVoiceCommandSession();
                  }
                },
                icon: Icon(
                  isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  size: 22,
                ),
                label: Text(
                  isListening
                      ? 'Dinleniyor... Konuşun (Bitirmek için dokunun)'
                      : 'Telefon Mikrofonuyla Konuş',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (voicePermDenied) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0xFFFF5252)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(cueDeckProvider.notifier)
                        .openIosLocalNetworkSettings();
                  },
                  icon: const Icon(Icons.settings_voice_rounded, size: 17),
                  label: const Text(
                    '📲 Ayarlarda Mikrofon & Ses Tanıma İznini Aç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            if (lastTranscript.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: subSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE2A84B).withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.record_voice_over_rounded,
                          color: goldText,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Son Algılanan: "$lastTranscript"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('voice_sheet_type_active_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryText,
                              side: BorderSide(
                                color: goldText.withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(cueDeckProvider.notifier)
                                  .sendKeyboardText(
                                    lastTranscript,
                                    submitEnter: true,
                                  );
                            },
                            icon: const Icon(
                              Icons.keyboard_alt_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Aktif Alana Yaz',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('voice_sheet_search_youtube_button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: goldText,
                              side: BorderSide(
                                color: goldText.withValues(alpha: 0.55),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(cueDeckProvider.notifier)
                                  .searchTranscriptOnYoutube(lastTranscript);
                            },
                            icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'YouTube\'da Ara',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (lastStatus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                lastStatus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: voicePermDenied
                      ? const Color(0xFFFF5252)
                      : secondaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'HIZLI SESLİ KOMUTLAR (TEK DOKUNUŞ)',
              style: TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickVoicePrompts.map((prompt) {
                return ActionChip(
                  backgroundColor: chipBg,
                  side: BorderSide(
                    color: const Color(0xFFE2A84B).withValues(alpha: 0.45),
                  ),
                  label: Text(
                    prompt,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final notifier = ref.read(cueDeckProvider.notifier);
                    if (isListening) {
                      await notifier.cancelVoiceCommandSession();
                    }
                    await notifier.runVoiceTranscript(prompt);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _voiceInputController,
                    focusNode: _voiceInputFocusNode,
                    style: TextStyle(color: primaryText, fontSize: 13),
                    onTap: () {
                      if (isListening) {
                        ref
                            .read(cueDeckProvider.notifier)
                            .cancelVoiceCommandSession();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Sesli komut veya arama metni yazın...',
                      hintStyle: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: subSurfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: _submitCustomTranscript,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2A84B),
                    foregroundColor: const Color(0xFF090A0F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () =>
                      _submitCustomTranscript(_voiceInputController.text),
                  child: const Text(
                    'Çalıştır',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
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

  Future<void> _submitCustomTranscript(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final notifier = ref.read(cueDeckProvider.notifier);
    if (ref.read(cueDeckProvider).isListeningVoice) {
      await notifier.cancelVoiceCommandSession();
    }
    await notifier.runVoiceTranscript(text);
    _voiceInputController.clear();
  }
}

/// Live TV typing bottom sheet forwarding phone keyboard keystrokes onto the TV input field.
class RemoteKeyboardSheet extends ConsumerStatefulWidget {
  const RemoteKeyboardSheet({super.key});

  @override
  ConsumerState<RemoteKeyboardSheet> createState() =>
      _RemoteKeyboardSheetState();
}

class _RemoteKeyboardSheetState extends ConsumerState<RemoteKeyboardSheet> {
  late final TextEditingController _textController;
  late final FocusNode _textFocusNode;
  final bool _liveTypingEnabled = true;
  String _lastSyncedText = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _handlePhoneKeyboardChanged(String newText) {
    if (!_liveTypingEnabled) return;
    final prev = _lastSyncedText;
    if (newText == prev) return;

    var commonPrefix = 0;
    final minLen = newText.length < prev.length ? newText.length : prev.length;
    while (commonPrefix < minLen &&
        newText.codeUnitAt(commonPrefix) == prev.codeUnitAt(commonPrefix)) {
      commonPrefix++;
    }

    final deletedCount = prev.length - commonPrefix;
    final addedText = newText.substring(commonPrefix);
    _lastSyncedText = newText;

    final notifier = ref.read(cueDeckProvider.notifier);
    if (deletedCount > 0) {
      notifier.sendKeyboardBackspace(count: deletedCount);
    }
    if (addedText.isNotEmpty) {
      notifier.sendKeyboardText(addedText);
    }
  }

  void _submitAndSendEnter() {
    final text = _textController.text;
    final notifier = ref.read(cueDeckProvider.notifier);
    if (text != _lastSyncedText && text.trim().isNotEmpty) {
      _lastSyncedText = text;
      notifier.sendKeyboardText(text.trim(), submitEnter: true);
    } else {
      notifier.sendKeyboardEnter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDarkMode ? const Color(0xFF0E1017) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final inputFill = isDarkMode ? const Color(0xFF090A0F) : Colors.white;

    return Container(
      key: const Key('remote_keyboard_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.keyboard_alt_outlined,
                color: goldText,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TV Arama & Giriş Alanına Metin Gönder',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: secondaryText, size: 19),
              ),
            ],
          ),
          Text(
            'Telefon klavyesiyle yazdığınız harfler anında TV ekranına iletilir.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('remote_keyboard_text_field'),
                  controller: _textController,
                  focusNode: _textFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: primaryText, fontSize: 14),
                  onChanged: _handlePhoneKeyboardChanged,
                  onSubmitted: (_) => _submitAndSendEnter(),
                  decoration: InputDecoration(
                    hintText: 'Telefon klavyesiyle TV\'ye yazın...',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('remote_keyboard_send_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2A84B),
                  foregroundColor: const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty && text != _lastSyncedText.trim()) {
                    ref.read(cueDeckProvider.notifier).sendKeyboardText(text);
                  } else {
                    ref.read(cueDeckProvider.notifier).sendKeyboardEnter();
                  }
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Gönder',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('remote_keyboard_backspace_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(
                      color: goldText.withValues(alpha: 0.40),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (_textController.text.isNotEmpty) {
                      final next = _textController.text.substring(
                        0,
                        _textController.text.length - 1,
                      );
                      _lastSyncedText = next;
                      _textController.value = TextEditingValue(
                        text: next,
                        selection: TextSelection.collapsed(offset: next.length),
                      );
                    }
                    ref.read(cueDeckProvider.notifier).sendKeyboardBackspace();
                  },
                  icon: const Icon(Icons.backspace_outlined, size: 15),
                  label: const Text(
                    'Sil',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('remote_keyboard_space_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(
                      color: goldText.withValues(alpha: 0.40),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final next = '${_textController.text} ';
                    _lastSyncedText = next;
                    _textController.value = TextEditingValue(
                      text: next,
                      selection: TextSelection.collapsed(offset: next.length),
                    );
                    ref.read(cueDeckProvider.notifier).sendKeyboardText(' ');
                  },
                  icon: const Icon(Icons.space_bar_rounded, size: 16),
                  label: const Text(
                    'Boşluk',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('remote_keyboard_enter_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: BorderSide(
                      color: goldText.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _submitAndSendEnter();
                  },
                  icon: const Icon(Icons.keyboard_return_rounded, size: 15),
                  label: const Text(
                    'Ara / Enter',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
