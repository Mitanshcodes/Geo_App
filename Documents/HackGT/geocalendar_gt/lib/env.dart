import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Returns the OpenAI API key from dotenv or an empty string if not set.
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
}
