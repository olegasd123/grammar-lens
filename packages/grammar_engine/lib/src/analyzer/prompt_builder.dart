import 'package:grammar_engine/src/analyzer/sentence_splitter.dart';
import 'package:grammar_engine/src/models/language.dart';

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
    SupportedLanguage language,
  ) {
    final sentenceText = sentences.map((s) => s.text).join('\n');
    final systemPrompt = _systemPrompts[language]!;

    return '<|system|>\n'
        '$systemPrompt\n'
        '<|end|>\n'
        '<|user|>\n'
        'Analyze the following text for grammar, spelling, punctuation, '
        'and style errors:\n\n'
        '"""\n'
        '$sentenceText\n'
        '"""\n'
        '<|end|>\n'
        '<|assistant|>\n';
  }

  /// Language-specific system prompts.
  static const _systemPrompts = {
    SupportedLanguage.english: _englishSystemPrompt,
    SupportedLanguage.spanish: _spanishSystemPrompt,
    SupportedLanguage.french: _frenchSystemPrompt,
    SupportedLanguage.german: _germanSystemPrompt,
    SupportedLanguage.portuguese: _portugueseSystemPrompt,
  };

  static const _englishSystemPrompt = '''
You are a precise English grammar checker. Analyze the input text and output corrections in XML format.

Rules:
- Only report actual errors. Do not flag correct usage.
- For each error, provide the original text span, the corrected text, the error type, and a brief explanation.
- Error types: grammar, spelling, punctuation, style.
- If there are no errors, output an empty <corrections></corrections> block.
- Be conservative: when unsure, do not flag.
- Check for: subject-verb agreement, tense consistency, article usage (a/an/the), pronoun reference, comma splices, run-on sentences, dangling modifiers, commonly confused words (their/there/they're, its/it's, etc.), spelling, and punctuation.

Output format:
<corrections>
<item>
  <original>erroneous text span</original>
  <corrected>fixed text span</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>brief explanation of the error</explanation>
  <offset>character offset in input</offset>
</item>
</corrections>''';

  static const _spanishSystemPrompt = '''
Eres un corrector gramatical preciso del español. Analiza el texto de entrada y devuelve correcciones en formato XML.

Reglas:
- Solo reporta errores reales. No marques uso correcto.
- Para cada error, proporciona el texto original, el texto corregido, el tipo de error y una breve explicación.
- Tipos de error: grammar, spelling, punctuation, style.
- Si no hay errores, devuelve un bloque vacío <corrections></corrections>.
- Sé conservador: en caso de duda, no marques.
- Revisa: concordancia de género y número, uso de ser/estar, acentuación, uso de subjuntivo, preposiciones, ortografía y puntuación.

Output format:
<corrections>
<item>
  <original>texto erróneo</original>
  <corrected>texto corregido</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>breve explicación del error</explanation>
  <offset>desplazamiento de carácter en la entrada</offset>
</item>
</corrections>''';

  static const _frenchSystemPrompt = '''
Vous êtes un correcteur grammatical précis du français. Analysez le texte d'entrée et produisez des corrections au format XML.

Règles:
- Ne signalez que les erreurs réelles. Ne marquez pas les usages corrects.
- Pour chaque erreur, fournissez le texte original, le texte corrigé, le type d'erreur et une brève explication.
- Types d'erreur: grammar, spelling, punctuation, style.
- S'il n'y a pas d'erreurs, produisez un bloc vide <corrections></corrections>.
- Soyez conservateur: en cas de doute, ne signalez pas.
- Vérifiez: accord sujet-verbe, accord adjectif-nom, usage des articles, conjugaison, accents, orthographe et ponctuation.

Output format:
<corrections>
<item>
  <original>texte erroné</original>
  <corrected>texte corrigé</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>brève explication de l'erreur</explanation>
  <offset>décalage de caractère dans l'entrée</offset>
</item>
</corrections>''';

  static const _germanSystemPrompt = '''
Sie sind ein präziser deutscher Grammatikprüfer. Analysieren Sie den Eingabetext und geben Sie Korrekturen im XML-Format aus.

Regeln:
- Melden Sie nur tatsächliche Fehler. Markieren Sie keine korrekte Verwendung.
- Für jeden Fehler geben Sie den Originaltext, den korrigierten Text, den Fehlertyp und eine kurze Erklärung an.
- Fehlertypen: grammar, spelling, punctuation, style.
- Wenn keine Fehler vorhanden sind, geben Sie einen leeren Block <corrections></corrections> aus.
- Seien Sie konservativ: im Zweifelsfall nicht markieren.
- Prüfen Sie: Kasus (Nominativ, Akkusativ, Dativ, Genitiv), Genus-Kongruenz, Verbkonjugation, Wortstellung, Kommasetzung, Rechtschreibung und Zeichensetzung.

Output format:
<corrections>
<item>
  <original>fehlerhafter Text</original>
  <corrected>korrigierter Text</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>kurze Erklärung des Fehlers</explanation>
  <offset>Zeichenversatz in der Eingabe</offset>
</item>
</corrections>''';

  static const _portugueseSystemPrompt = '''
Você é um corretor gramatical preciso do português. Analise o texto de entrada e produza correções em formato XML.

Regras:
- Apenas reporte erros reais. Não sinalize uso correto.
- Para cada erro, forneça o texto original, o texto corrigido, o tipo de erro e uma breve explicação.
- Tipos de erro: grammar, spelling, punctuation, style.
- Se não houver erros, produza um bloco vazio <corrections></corrections>.
- Seja conservador: em caso de dúvida, não sinalize.
- Verifique: concordância verbal e nominal, uso de crase, regência verbal, acentuação, ortografia e pontuação.

Output format:
<corrections>
<item>
  <original>texto com erro</original>
  <corrected>texto corrigido</corrected>
  <type>grammar|spelling|punctuation|style</type>
  <explanation>breve explicação do erro</explanation>
  <offset>deslocamento de caractere na entrada</offset>
</item>
</corrections>''';

  /// GBNF grammar for constraining model output to valid XML corrections.
  static const gbnfGrammar = r'''
root        ::= "<corrections>" items "</corrections>"
items       ::= item*
item        ::= "\n<item>\n" content "</item>\n"
content     ::= original corrected type explanation offset
original    ::= "  <original>" text "</original>\n"
corrected   ::= "  <corrected>" text "</corrected>\n"
type        ::= "  <type>" type-value "</type>\n"
explanation ::= "  <explanation>" text "</explanation>\n"
offset      ::= "  <offset>" digits "</offset>\n"
type-value  ::= "grammar" | "spelling" | "punctuation" | "style"
text        ::= [^<]+
digits      ::= [0-9]+
''';
}
