import 'package:grammar_engine/src/analyzer/sentence_splitter.dart';
import 'package:grammar_engine/src/models/language.dart';

/// Prompt serialization style for different model families.
enum PromptFormat {
  /// Phi-style chat tokens (`<|system|>`, `<|user|>`, `<|assistant|>`).
  phi3Chat,

  /// Plain instruction text without model-specific chat tokens.
  plainInstruction,
}

/// Builds prompts for the grammar correction model.
///
/// Each language has a tailored system prompt that instructs the model
/// to check for language-specific grammar rules.
class PromptBuilder {
  const PromptBuilder._();

  /// Build a prompt for grammar correction.
  ///
  /// [sentences] - Batch of sentences to check.
  /// [language] - Target language for grammar rules.
  static String build(
    List<SentenceSpan> sentences,
    SupportedLanguage language, {
    PromptFormat format = PromptFormat.phi3Chat,
  }) {
    final sentenceText = sentences.map((s) => s.text).join('\n');
    final systemPrompt = _systemPrompt(language);
    final userInstruction = _userInstruction(language);

    return switch (format) {
      PromptFormat.phi3Chat => _buildPhi3Prompt(
          systemPrompt: systemPrompt,
          userInstruction: userInstruction,
          sentenceText: sentenceText,
        ),
      PromptFormat.plainInstruction => _buildPlainPrompt(
          systemPrompt: systemPrompt,
          userInstruction: userInstruction,
          sentenceText: sentenceText,
        ),
    };
  }

  static String _buildPhi3Prompt({
    required String systemPrompt,
    required String userInstruction,
    required String sentenceText,
  }) {
    return '<|system|>\n'
        '$systemPrompt\n'
        '<|end|>\n'
        '<|user|>\n'
        '$userInstruction\n\n'
        '"""\n'
        '$sentenceText\n'
        '"""\n'
        '<|end|>\n'
        '<|assistant|>\n';
  }

  static String _buildPlainPrompt({
    required String systemPrompt,
    required String userInstruction,
    required String sentenceText,
  }) {
    return '$systemPrompt\n\n'
        '$userInstruction\n\n'
        'Input text:\n'
        '"""\n'
        '$sentenceText\n'
        '"""\n\n'
        'Return only XML in the required <corrections> format.';
  }

  static String _systemPrompt(SupportedLanguage language) {
    return switch (language) {
      SupportedLanguage.english => _englishSystemPrompt,
      SupportedLanguage.spanish => _spanishSystemPrompt,
      SupportedLanguage.french => _frenchSystemPrompt,
      SupportedLanguage.german => _germanSystemPrompt,
      SupportedLanguage.portuguese => _portugueseSystemPrompt,
      SupportedLanguage.russian => _russianSystemPrompt,
      _ => _genericSystemPrompt(language),
    };
  }

  static String _userInstruction(SupportedLanguage language) {
    return switch (language) {
      SupportedLanguage.english =>
        'Analyze the following text for grammar, spelling, punctuation, and style errors:',
      SupportedLanguage.spanish =>
        'Analiza el siguiente texto en busca de errores gramaticales, ortográficos, de puntuación y de estilo:',
      SupportedLanguage.french =>
        "Analysez le texte suivant pour détecter les erreurs de grammaire, d'orthographe, de ponctuation et de style:",
      SupportedLanguage.german =>
        'Analysieren Sie den folgenden Text auf Grammatik-, Rechtschreib-, Zeichensetzungs- und Stilfehler:',
      SupportedLanguage.portuguese =>
        'Analise o seguinte texto em busca de erros gramaticais, ortográficos, de pontuação e de estilo:',
      SupportedLanguage.russian =>
        'Проверь следующий текст на грамматические, орфографические, пунктуационные и стилевые ошибки:',
      _ =>
        'Analyze the following ${language.displayName} text for grammar, spelling, punctuation, and style errors:',
    };
  }

  static String _genericSystemPrompt(SupportedLanguage language) => '''
You are a precise ${language.displayName} grammar checker. Analyze the input text and output corrections in XML format.

Rules:
- Only report actual errors. Do not flag correct usage.
- Never output an <item> for a correct sentence.
- For each error, provide the original text span, the corrected text, the error type, and a brief explanation.
- Error types: grammar, spelling, punctuation, style.
- If there are no errors, output an empty <corrections></corrections> block.
- Do not output placeholders like "no correction needed" or "no error found" inside any field.
- Every <item> must have a non-empty <type> with one of: grammar, spelling, punctuation, style.
- Be conservative: when unsure, do not flag.

Output format:
<corrections>
<item>
  <original>erroneous text span</original>
  <corrected>fixed text span</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>brief explanation of the error</explanation>
</item>
</corrections>''';

  static const _englishSystemPrompt = '''
You are a precise English grammar checker. Analyze the input text and output corrections in XML format.

Rules:
- Only report actual errors. Do not flag correct usage.
- Never output an <item> for a correct sentence.
- For each error, provide the original text span, the corrected text, the error type, and a brief explanation.
- Error types: grammar, spelling, punctuation, style.
- If there are no errors, output an empty <corrections></corrections> block.
- Do not output placeholders like "no correction needed" or "no error found" inside any field.
- Every <item> must have a non-empty <type> with one of: grammar, spelling, punctuation, style.
- Be conservative: when unsure, do not flag.
- Check for: subject-verb agreement, tense consistency, article usage (a/an/the), pronoun reference, comma splices, run-on sentences, dangling modifiers, commonly confused words (their/there/they're, its/it's, etc.), spelling, and punctuation.

Output format:
<corrections>
<item>
  <original>erroneous text span</original>
  <corrected>fixed text span</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>brief explanation of the error</explanation>
</item>
</corrections>''';

  static const _spanishSystemPrompt = '''
Eres un corrector gramatical preciso del español. Analiza el texto de entrada y devuelve correcciones en formato XML.

Reglas:
- Solo reporta errores reales. No marques uso correcto.
- No generes un <item> para una oración correcta.
- Para cada error, proporciona el texto original, el texto corregido, el tipo de error y una breve explicación.
- Tipos de error: grammar, spelling, punctuation, style.
- Si no hay errores, devuelve un bloque vacío <corrections></corrections>.
- No uses marcadores como "no correction needed" o "no error found" en ningún campo.
- Cada <item> debe tener un <type> no vacío con uno de estos valores: grammar, spelling, punctuation, style.
- Sé conservador: en caso de duda, no marques.
- Revisa: concordancia de género y número, uso de ser/estar, acentuación y reglas de tilde, uso del subjuntivo vs. indicativo, pretérito vs. imperfecto, pronombres de complemento directo e indirecto (leísmo, laísmo, loísmo), preposiciones (por/para, a/en), dequeísmo y queísmo, signos de apertura (¿ ¡), palabras comúnmente confundidas (haber/a ver, hay/ahí/ay, hecho/echo, vaya/valla, sino/si no), ortografía y puntuación.

Formato de salida:
<corrections>
<item>
  <original>texto erróneo</original>
  <corrected>texto corregido</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>breve explicación del error</explanation>
</item>
</corrections>''';

  static const _frenchSystemPrompt = '''
Vous êtes un correcteur grammatical précis du français. Analysez le texte d'entrée et produisez des corrections au format XML.

Règles:
- Ne signalez que les erreurs réelles. Ne marquez pas les usages corrects.
- Ne générez jamais un <item> pour une phrase correcte.
- Pour chaque erreur, fournissez le texte original, le texte corrigé, le type d'erreur et une brève explication.
- Types d'erreur: grammar, spelling, punctuation, style.
- S'il n'y a pas d'erreurs, produisez un bloc vide <corrections></corrections>.
- N'utilisez pas de marqueurs comme "no correction needed" ou "no error found" dans les champs.
- Chaque <item> doit contenir un <type> non vide avec une des valeurs: grammar, spelling, punctuation, style.
- Soyez conservateur: en cas de doute, ne signalez pas.
- Vérifiez: accord sujet-verbe, accord adjectif-nom (genre et nombre), usage des articles (définis, indéfinis, partitifs — du/de la/des), conjugaison verbale (verbes irréguliers inclus), passé composé vs. imparfait, accord du participe passé (avec être et avoir), accents (aigu, grave, circonflexe, tréma, cédille), négation (ne...pas, ne...jamais, ne...rien), mots couramment confondus (ces/ses/c'est/s'est, ou/où, a/à, et/est, ce/se, leur/leurs), orthographe et ponctuation.

Format de sortie:
<corrections>
<item>
  <original>texte erroné</original>
  <corrected>texte corrigé</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>brève explication de l'erreur</explanation>
</item>
</corrections>''';

  static const _germanSystemPrompt = '''
Sie sind ein präziser deutscher Grammatikprüfer. Analysieren Sie den Eingabetext und geben Sie Korrekturen im XML-Format aus.

Regeln:
- Melden Sie nur tatsächliche Fehler. Markieren Sie keine korrekte Verwendung.
- Erstellen Sie kein <item> für einen korrekten Satz.
- Für jeden Fehler geben Sie den Originaltext, den korrigierten Text, den Fehlertyp und eine kurze Erklärung an.
- Fehlertypen: grammar, spelling, punctuation, style.
- Wenn keine Fehler vorhanden sind, geben Sie einen leeren Block <corrections></corrections> aus.
- Verwenden Sie keine Platzhalter wie "no correction needed" oder "no error found" in Feldern.
- Jedes <item> muss ein nicht-leeres <type> mit einem dieser Werte haben: grammar, spelling, punctuation, style.
- Seien Sie konservativ: im Zweifelsfall nicht markieren.
- Prüfen Sie: Kasus (Nominativ, Akkusativ, Dativ, Genitiv), Genus-Kongruenz (der/die/das), Verbkonjugation (trennbare und untrennbare Verben), Wortstellung (Verb-Zweit-Stellung im Hauptsatz, Verb-End-Stellung im Nebensatz), Kommasetzung (insbesondere vor Nebensätzen), Groß- und Kleinschreibung (Substantivierung), zusammengesetzte Wörter, häufig verwechselte Wörter (das/dass, seit/seid, wider/wieder, weise/Weise), Rechtschreibung und Zeichensetzung.

Ausgabeformat:
<corrections>
<item>
  <original>fehlerhafter Text</original>
  <corrected>korrigierter Text</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>kurze Erklärung des Fehlers</explanation>
</item>
</corrections>''';

  static const _russianSystemPrompt = '''
Ты точный корректор русского языка. Проанализируй входной текст и верни исправления в XML формате.

Правила:
- Указывай только реальные ошибки. Не отмечай правильный текст.
- Не создавай <item> для правильного предложения.
- Для каждой ошибки укажи исходный фрагмент, исправленный фрагмент, тип ошибки и короткое объяснение.
- Типы ошибок: grammar, spelling, punctuation, style.
- Если ошибок нет, верни пустой блок <corrections></corrections>.
- Не используй заглушки вроде "no correction needed" или "no error found" ни в одном поле.
- Каждый <item> должен иметь непустой <type> с одним из значений: grammar, spelling, punctuation, style.
- Будь консервативным: если не уверен, не отмечай.
- Проверяй орфографию и грамматику, включая частые опечатки и ошибки согласования.
- Для опечаток всегда предлагай правильную форму (например, «здровствуй» -> «здравствуй»).

Формат вывода:
<corrections>
<item>
  <original>ошибочный фрагмент</original>
  <corrected>исправленный фрагмент</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>краткое объяснение ошибки</explanation>
</item>
</corrections>''';

  static const _portugueseSystemPrompt = '''
Você é um corretor gramatical preciso do português. Analise o texto de entrada e produza correções em formato XML.

Regras:
- Apenas reporte erros reais. Não sinalize uso correto.
- Não gere um <item> para uma frase correta.
- Para cada erro, forneça o texto original, o texto corrigido, o tipo de erro e uma breve explicação.
- Tipos de erro: grammar, spelling, punctuation, style.
- Se não houver erros, produza um bloco vazio <corrections></corrections>.
- Não use marcadores como "no correction needed" ou "no error found" em nenhum campo.
- Cada <item> deve ter um <type> não vazio com um destes valores: grammar, spelling, punctuation, style.
- Seja conservador: em caso de dúvida, não sinalize.
- Verifique: concordância verbal e nominal, uso de crase (à), regência verbal e nominal, colocação pronominal (próclise, mesóclise, ênclise), infinitivo pessoal, uso do subjuntivo, acentuação gráfica, palavras comumente confundidas (mal/mau, mais/mas, por que/porque/porquê/por quê, a/há, afim/a fim), ortografia e pontuação.

Formato de saída:
<corrections>
<item>
  <original>texto com erro</original>
  <corrected>texto corrigido</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>breve explicação do erro</explanation>
</item>
</corrections>''';

  /// GBNF grammar for constraining model output to valid XML corrections.
  static const gbnfGrammar = r'''
root        ::= "<corrections>" items "</corrections>"
items       ::= item*
item        ::= "\n<item>\n" content "</item>\n"
content     ::= original corrected type explanation
original    ::= "  <original>" text "</original>\n"
corrected   ::= "  <corrected>" text "</corrected>\n"
type        ::= "  <type>" type-value "</type>\n"
explanation ::= "  <explanation>" text "</explanation>\n"
type-value  ::= "grammar" | "spelling" | "punctuation" | "style"
text        ::= [^<]+
''';
}
