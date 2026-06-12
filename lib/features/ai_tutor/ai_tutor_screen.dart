import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/offline_view.dart';
import '../../data/services/chat_store.dart';
import '../../data/services/llm_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isOffline;
  ChatMessage(this.text, this.isUser, {this.isOffline = false});
}

final _llmProvider = Provider((_) => LlmService());
final _chatStoreProvider = Provider((_) => ChatStore());

final chatProvider =
    StateNotifierProvider<ChatController, List<ChatMessage>>(
  (ref) => ChatController(ref.read(_llmProvider), ref.read(_chatStoreProvider)),
);

class ChatController extends StateNotifier<List<ChatMessage>> {
  final LlmService _service;
  final ChatStore _store;
  ChatController(this._service, this._store) : super([]) {
    _restore();
  }
  bool loading = false;

  /// Load any saved conversation when the controller is first created.
  Future<void> _restore() async {
    final saved = await _store.load();
    if (saved.isNotEmpty && state.isEmpty) {
      state = [for (final m in saved) ChatMessage(m.text, m.isUser)];
    }
  }

  /// Persist only the real (non-offline, non-empty) turns.
  void _persist() {
    _store.save([
      for (final m in state)
        if (!m.isOffline && m.text.isNotEmpty) (text: m.text, isUser: m.isUser),
    ]);
  }

  /// Wipe the saved conversation and start fresh.
  Future<void> clear() async {
    state = [];
    await _store.clear();
  }

  Future<void> send(String text, {String? pageContext}) async {
    state = [...state, ChatMessage(text, true)];
    loading = true;
    state = [...state]; // notify
    try {
      final reply = await _service.chat([
        {
          'role': 'system',
          'content':
              'You are a friendly nursing tutor for PNLE/NCLEX students. '
                  'Your ONLY domain is nursing and directly related health '
                  'sciences (anatomy, physiology, pharmacology, pathophysiology, '
                  'microbiology, nutrition, ethics/jurisprudence, and clinical '
                  'practice). '
                  'If a question is NOT about nursing or these health topics '
                  '(e.g. music, gadgets, sports, coding, general trivia like '
                  '"what is a guitar"), politely DECLINE in one sentence and '
                  'steer the student back to their nursing review — do not answer '
                  'the off-topic question. '
                  'Explain clearly and concisely. '
                  '${pageContext != null ? "Module context:\n$pageContext" : ""}'
        },
        ...state.map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            }),
      ]);
      state = [...state, ChatMessage(reply, false)];
      _persist();
    } on OfflineException {
      state = [...state, ChatMessage('', false, isOffline: true)];
    } catch (e) {
      state = [...state, ChatMessage('⚠️ Could not reach tutor. $e', false)];
    } finally {
      loading = false;
      state = [...state];
    }
  }
}

class AiTutorScreen extends ConsumerStatefulWidget {
  final String? pageContext;
  const AiTutorScreen({super.key, this.pageContext});

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).send(text, pageContext: widget.pageContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final loading = ref.read(chatProvider.notifier).loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear conversation?'),
                    content: const Text(
                        'This permanently deletes the saved chat history.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(chatProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length + (loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == messages.length) return const _TypingBubble();
                      final m = messages[i];
                      if (m.isOffline) return const OfflineBubble();
                      return _Bubble(message: m);
                    },
                  ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Ask anything about your module.\n'
                'e.g. "Explain the pathophysiology of pre-eclampsia."',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Implicit slide+fade-in on each new bubble.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset((isUser ? 30 : -30) * (1 - t), 0), child: child),
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isUser ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: isUser ? null : Border.all(color: scheme.outline),
          ),
          child: Text(message.text,
              style: text.bodyMedium?.copyWith(
                  color: isUser ? scheme.onPrimary : scheme.onSurface)),
        ),
      ),
    );
  }
}

/// Animated three-dot "tutor is thinking" indicator.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: scheme.outline),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Stagger each dot's bounce by phase.
              final phase = (_c.value + i * 0.2) % 1.0;
              final t = (phase < 0.5 ? phase : 1 - phase) * 2; // 0→1→0
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary
                      .withValues(alpha: 0.4 + 0.6 * t),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ask about this page…',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: scheme.outline)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: scheme.outline)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: scheme.primary, width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: onSend,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 0,
            child: const Icon(Icons.send_rounded),
          ),
        ]),
      ),
    );
  }
}
