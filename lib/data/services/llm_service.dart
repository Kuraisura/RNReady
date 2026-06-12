import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown when the request can't reach the AI because the device is offline
/// (no network, DNS failure, or timeout). UI should show a friendly "Offline"
/// state for this — never a raw provider error.
class OfflineException implements Exception {
  const OfflineException();
  @override
  String toString() => 'Offline';
}

/// Thrown when no API key is configured. Distinct from being offline.
class MissingKeyException implements Exception {
  final String message;
  const MissingKeyException(this.message);
  @override
  String toString() => message;
}

/// First non-empty env value among [names]. Ignores placeholders.
String _env(List<String> names) {
  for (final name in names) {
    final v = dotenv.env[name]?.trim() ?? '';
    if (v.isNotEmpty && !v.startsWith('put_your')) return v;
  }
  return '';
}

/// Free LLM access with automatic fallback across providers **and models**.
///
/// On every `chat()` the configured providers are tried in order — Groq →
/// Gemini → OpenRouter. Inside each provider, several current model IDs are
/// tried so a retired model (e.g. Groq's old Llama 3.3) does not abort the
/// whole chain. Callers keep the same `chat()` signature.
class LlmService {
  LlmService({List<LlmProvider>? providers})
      : _providers = providers ??
            [
              GroqProvider(),
              GeminiProvider(),
              OpenRouterProvider(),
            ];

  final List<LlmProvider> _providers;

  Future<String> chat(
    List<Map<String, String>> messages, {
    double temperature = 0.5,
  }) async {
    final configured = _providers.where((p) => p.hasKey).toList();
    if (configured.isEmpty) {
      throw const MissingKeyException(
          'No AI key set. Add a GROQ_API_KEY, GEMINI_API_KEY, or '
          'OPENROUTER_API_KEY to the .env file.');
    }

    final failures = <String>[];
    var sawNetwork = false;

    for (final p in configured) {
      try {
        final reply = await p.chat(messages, temperature);
        debugPrint('LLM: ${p.name} succeeded');
        return reply;
      } on OfflineException {
        sawNetwork = true;
        failures.add('${p.name}: network timeout or unreachable');
        debugPrint('LLM: ${p.name} offline, trying next');
        continue;
      } on MissingKeyException {
        continue;
      } catch (e) {
        failures.add('${p.name}: ${_short(e)}');
        debugPrint('LLM: ${p.name} failed (${_short(e)}), trying next');
        continue;
      }
    }

    if (failures.isNotEmpty && !failures.every((f) => f.contains('network'))) {
      throw Exception('All AI providers failed. ${failures.join(' | ')}');
    }
    if (sawNetwork) throw const OfflineException();
    throw const OfflineException();
  }

  static String _short(Object e) {
    final s = e.toString().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > 180 ? '${s.substring(0, 180)}…' : s;
  }
}

/// One chat-completion backend. Converts the shared OpenAI-style [messages]
/// (each a `{'role': ..., 'content': ...}` map) into its own wire format.
abstract class LlmProvider {
  String get name;

  /// The configured API key, or '' if absent.
  String get apiKey;

  /// True when a usable key is present (ignores empty/placeholder values).
  bool get hasKey => apiKey.isNotEmpty && !apiKey.startsWith('put_your');

  /// Returns the assistant's reply text. Throws [OfflineException] on a network
  /// failure, or a plain [Exception] when the provider responds with an error.
  Future<String> chat(List<Map<String, String>> messages, double temperature);

  /// Shared POST that maps socket/timeout failures to [OfflineException].
  Future<http.Response> postJson(
    String url,
    Map<String, String> headers,
    Object body,
  ) async {
    try {
      return await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } on SocketException {
      throw const OfflineException();
    } on http.ClientException {
      throw const OfflineException();
    } on TimeoutException {
      throw const OfflineException();
    }
  }
}

/// Base for OpenAI-compatible endpoints (Groq, OpenRouter share the same
/// request/response shape). Tries [candidateModels] in order until one works.
abstract class _OpenAiCompatProvider extends LlmProvider {
  String get url;
  List<String> get candidateModels;
  Map<String, String> get extraHeaders => const {};

  @override
  Future<String> chat(
      List<Map<String, String>> messages, double temperature) async {
    Object? last;
    final tried = <String>{};
    for (final model in candidateModels) {
      if (model.isEmpty || !tried.add(model)) continue;
      try {
        return await _complete(model, messages, temperature);
      } catch (e) {
        if (e is OfflineException) rethrow;
        last = e;
        debugPrint('$name model $model failed: $e');
      }
    }
    throw last is Exception
        ? last
        : Exception('$name: no working model (${last ?? 'unknown'})');
  }

  Future<String> _complete(
    String model,
    List<Map<String, String>> messages,
    double temperature,
  ) async {
    final res = await postJson(
      url,
      {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        ...extraHeaders,
      },
      {
        'model': model,
        'temperature': temperature,
        'messages': messages,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('$name error ${res.statusCode} ($model): ${res.body}');
    }
    final data = jsonDecode(res.body);
    final content = data['choices']?[0]?['message']?['content'];
    if (content is! String || content.isEmpty) {
      // Some reasoning models put text in `reasoning` / `content` null.
      final alt = data['choices']?[0]?['message']?['reasoning'];
      if (alt is String && alt.isNotEmpty) return alt;
      throw Exception('$name returned an empty reply ($model).');
    }
    return content;
  }
}

/// Groq's OpenAI-compatible endpoint. Llama 3.3 was retired 16 Aug 2026.
class GroqProvider extends _OpenAiCompatProvider {
  @override
  String get name => 'Groq';
  @override
  String get apiKey => _env(['GROQ_API_KEY']);
  @override
  String get url => 'https://api.groq.com/openai/v1/chat/completions';
  @override
  List<String> get candidateModels => [
        _env(['GROQ_MODEL']),
        'openai/gpt-oss-20b',
        'openai/gpt-oss-120b',
        'qwen/qwen3.6-27b',
      ];
}

/// OpenRouter — OpenAI-compatible aggregator. Accepts either OPENROUTER_API_KEY
/// or OPENAI_API_KEY (sk-or-v1 keys are OpenRouter, not native OpenAI).
class OpenRouterProvider extends _OpenAiCompatProvider {
  @override
  String get name => 'OpenRouter';
  @override
  String get apiKey => _env(['OPENROUTER_API_KEY', 'OPENAI_API_KEY']);
  @override
  String get url => 'https://openrouter.ai/api/v1/chat/completions';
  @override
  List<String> get candidateModels => [
        _env(['OPENROUTER_MODEL']),
        'openai/gpt-oss-20b:free',
        'google/gemini-2.0-flash-exp:free',
        'qwen/qwen3-8b:free',
        'openrouter/auto',
      ];
  @override
  Map<String, String> get extraHeaders => const {
        'HTTP-Referer': 'https://github.com/rn-ready',
        'X-Title': 'RN Ready',
      };
}

/// Google Gemini via the Generative Language API.
class GeminiProvider extends LlmProvider {
  @override
  String get name => 'Gemini';
  @override
  String get apiKey => _env(['GEMINI_API_KEY']);

  List<String> get candidateModels => [
        _env(['GEMINI_MODEL']),
        'gemini-2.0-flash',
        'gemini-2.5-flash',
        'gemini-flash-latest',
        'gemini-1.5-flash',
      ];

  @override
  Future<String> chat(
      List<Map<String, String>> messages, double temperature) async {
    final systemText = messages
        .where((m) => m['role'] == 'system')
        .map((m) => m['content'] ?? '')
        .join('\n\n')
        .trim();

    final contents = <Map<String, Object>>[];
    for (final m in messages) {
      final role = m['role'];
      if (role == 'system') continue;
      contents.add({
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m['content'] ?? ''}
        ],
      });
    }

    final body = <String, Object>{
      'contents': contents,
      'generationConfig': {'temperature': temperature},
      if (systemText.isNotEmpty)
        'system_instruction': {
          'parts': [
            {'text': systemText}
          ]
        },
    };

    Object? last;
    final tried = <String>{};
    for (final model in candidateModels) {
      if (model.isEmpty || !tried.add(model)) continue;
      try {
        return await _generate(model, body);
      } catch (e) {
        if (e is OfflineException) rethrow;
        last = e;
        debugPrint('Gemini model $model failed: $e');
      }
    }
    throw last is Exception
        ? last
        : Exception('Gemini: no working model (${last ?? 'unknown'})');
  }

  Future<String> _generate(String model, Map<String, Object> body) async {
    final res = await postJson(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
      {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body,
    );

    if (res.statusCode != 200) {
      throw Exception('$name error ${res.statusCode} ($model): ${res.body}');
    }
    final data = jsonDecode(res.body);
    final parts = data['candidates']?[0]?['content']?['parts'];
    if (parts is List) {
      final buf = StringBuffer();
      for (final p in parts) {
        final t = p is Map ? p['text'] : null;
        if (t is String) buf.write(t);
      }
      final text = buf.toString();
      if (text.isNotEmpty) return text;
    }
    throw Exception('$name returned an empty reply ($model): ${res.body}');
  }
}
