# AI Prompt & Parameter Improvement Proposals

Analysis of the current prompt system, inference parameters, and response handling in GrammarLens, with concrete proposals for more correct and stable AI output.

---

## [Done] 1. Enable GBNF Constrained Generation (High Impact)

**Problem:** `grammarGbnf` is defined in `InferenceConfig` and a GBNF grammar exists in `PromptBuilder.gbnfGrammar`, but it is never actually passed to the inference engine. The default is `null`, and `_buildInferenceConfig()` in `editor_page.dart` doesn't set it. The model is free to generate arbitrary text, relying entirely on prompt adherence.

**Proposal:** Wire up the existing GBNF grammar so the model is structurally forced to produce valid XML:

```dart
// editor_page.dart – _buildInferenceConfig()
return const InferenceConfig.grammar().copyWith(
  temperature: temperature,
  topP: topP,
  topK: topK,
  repeatPenalty: repeatPenalty,
  grammarGbnf: PromptBuilder.gbnfGrammar, // <-- add this
);
```

**Why:** This is the single highest-impact change. GBNF-constrained decoding eliminates malformed XML, missing tags, hallucinated prose outside the `<corrections>` block, and most parsing failures. It turns the XML format from a request into a guarantee.

**Caveat:** Test with each model — some quantizations (especially Q2_K) may produce worse content quality under GBNF constraints because the reduced probability space interacts poorly with heavy quantization. If so, enable it only for Q4_K_M+.

---

## [Done] 2. Reduce Temperature to 0.0 for Determinism

**Current:** `temperature = 0.1`

**Proposal:** Default to `temperature = 0.0` (greedy decoding).

**Why:** Grammar correction is a deterministic task — there is a single correct answer for any given error. Even `0.1` introduces sampling randomness that causes:
- Inconsistent results across runs for the same input
- Occasional hallucinated corrections that wouldn't appear with greedy decoding
- Non-reproducible behavior that makes debugging harder

With GBNF enabled, temperature 0.0 + constrained grammar gives the most predictable output. The user setting slider can remain 0.0–1.0 for advanced users who want to experiment.

---

## 3. Add Few-Shot Examples to System Prompts

**Problem:** The current prompts show the output format as a template with placeholder values (`erroneous text span`, `fixed text span`). Small models (Phi-3-mini, Mistral-7B) frequently repeat these placeholders verbatim, which is why `_placeholderOriginalTexts` / `_placeholderCorrectedTexts` / `_placeholderExplanations` exist as post-hoc filters in `grammar_analyzer.dart`.

**Proposal:** Replace the placeholder-based format description with concrete few-shot examples. This teaches the model the format through demonstration rather than description.

For the English prompt, change the output format section from:

```
Output format:
<corrections>
<item>
  <original>erroneous text span</original>
  ...
</item>
</corrections>
```

To:

```
Example 1 – text with errors:
Input: "He dont likes the cake."
<corrections>
<item>
  <original>dont likes</original>
  <corrected>doesn't like</corrected>
  <type>grammar</type>
  <explanation>Subject-verb agreement: third person singular requires "doesn't like"</explanation>
  <offset>3</offset>
</item>
</corrections>

Example 2 – text without errors:
Input: "The weather is beautiful today."
<corrections></corrections>

Now analyze the user's text using the same format.
```

**Why:**
- Small models learn far better from examples than from abstract format descriptions
- Eliminates the root cause of placeholder regurgitation (no more placeholders in the prompt to copy)
- The "no errors" example explicitly teaches the empty output case, reducing false positives
- The offset example teaches correct offset calculation by demonstration

Apply the same pattern to all language-specific prompts with language-appropriate examples.

---

## 4. Improve Offset Instruction Clarity

**Problem:** The prompt says `<offset>character offset in input</offset>`. Models frequently produce wrong offsets — the fallback `_findOffsetByText()` in `correction_parser.dart` is hit regularly. The concept of "character offset" is ambiguous for small models (byte offset? word index? line number?).

**Proposal:** Two options (can combine both):

**Option A — Better instruction:**
Replace `<offset>character offset in input</offset>` with an explicit instruction in the rules:

```
- The <offset> is the zero-based character position where the erroneous text starts in the input. Count characters from the beginning of the input text, starting at 0. For example, in "He dont like", the word "dont" starts at offset 3.
```

**Option B — Remove offset from model output entirely:**
Since `_findOffsetByText()` already works as a reliable fallback, consider removing `<offset>` from the prompt and GBNF grammar. This simplifies the model's task (one fewer field to generate), reduces token count, and avoids wrong offsets that could override correct text-search results.

If taking Option B, update the GBNF grammar:
```gbnf
content ::= original corrected type explanation
```

**Recommendation:** Option B is simpler and more robust. The text-search approach is already the reliable path; model-generated offsets are unreliable and sometimes harmful (they can point to the wrong location).

---

## [Done] 5. Tighten the topK Parameter

**Current:** `topK = 40`

**Proposal:** Reduce to `topK = 10` for grammar correction.

**Why:** With a structured output task (XML with a fixed vocabulary of tags and error types), 40 top-K candidates is unnecessarily wide. Narrowing to 10 keeps the model focused on the most likely tokens, which for structured output are almost always in the top 5. This reduces:
- Random XML formatting variations
- Unlikely token insertions that break parsing
- Generation latency (fewer candidates to evaluate)

Combined with temperature 0.0, a topK of 10 (or even 0 = disabled, deferring to topP) gives stable output.

---

## 6. Add a Prefill / Prompt Priming Token

**Problem:** The Phi-3 prompt ends with `<|assistant|>\n`, leaving the model to decide how to start its response. Small models sometimes begin with preamble ("Sure, let me analyze...", "Here are the corrections:") before the XML.

**Proposal:** Append the opening tag as a prefill after `<|assistant|>\n`:

```dart
static String _buildPhi3Prompt({...}) {
  return '<|system|>\n'
      '$systemPrompt\n'
      '<|end|>\n'
      '<|user|>\n'
      '$userInstruction\n\n'
      '"""\n'
      '$sentenceText\n'
      '"""\n'
      '<|end|>\n'
      '<|assistant|>\n'
      '<corrections>';  // <-- prefill
}
```

And add `<corrections>` as a prefix to prepend to the parsed output (since the model won't generate it — it's already in the prompt):

```dart
final rawOutput = '<corrections>' + await onInfer(prompt);
```

**Why:** By starting the assistant turn with `<corrections>`, the model is guided to continue with the XML body immediately. This eliminates preamble chatter and ensures the response starts in the correct format. This is a standard technique (often called "prefilling") that works well with small models.

**Note:** If using GBNF (proposal #1), the grammar already forces `<corrections>` as the first output, making this partially redundant. But combining both provides defense-in-depth.

---

## 7. Reduce `sentencesPerBatch` from 3 to 1–2

**Current:** `sentencesPerBatch = 3`

**Proposal:** Default to `sentencesPerBatch = 2` (or even 1 for Q2_K models).

**Why:** Phi-3-mini has a 4K context and Mistral-7B has 32K, but the effective "attention quality" of small quantized models degrades with longer inputs. With 3 sentences:
- The model may miss errors in the second or third sentence
- Cross-sentence confusion increases (reporting corrections for the wrong sentence)
- Offset calculation becomes harder for the model

Smaller batches trade throughput for accuracy. Since grammar correction is not latency-critical (the user types → debounce → analyze), the extra inference calls are acceptable.

For Q2_K models specifically, `sentencesPerBatch = 1` would maximize accuracy per sentence.

---

## 8. Add `<|end|>` Stop Token for Phi-3

**Current stop tokens:** `['</corrections>']`

**Proposal:** Add Phi-3's end-of-turn token:

```dart
stopTokens = const ['</corrections>', '<|end|>', '<|endoftext|>'],
```

**Why:** If the model finishes the corrections block and continues generating (e.g., starts a new `<|user|>` turn or adds commentary), the current stop condition won't trigger until `</corrections>` appears again (if it does). Adding `<|end|>` catches the model's natural turn-ending token, preventing runaway generation and saving compute.

---

## 9. Add Negative Examples to Reduce False Positives

**Problem:** The prompts say "Be conservative: when unsure, do not flag" — but small models don't always follow meta-instructions well. False positives (flagging correct text) are a common complaint with small grammar models.

**Proposal:** Add explicit negative examples in the system prompt:

```
Do NOT flag these as errors:
- Intentional stylistic choices (e.g., sentence fragments for emphasis)
- Proper nouns and brand names that look like misspellings
- Domain-specific terminology
- Informal but grammatically acceptable constructions ("gonna", "wanna" in casual text)
- Oxford comma presence or absence (both are correct)
```

And in the few-shot examples, include a tricky-but-correct input:

```
Example 3 – informal but correct text:
Input: "I'm gonna grab coffee, wanna come?"
<corrections></corrections>
```

**Why:** Small models respond better to explicit "don't do X" with examples than to vague "be conservative." Concrete negative examples calibrate the model's correction threshold.

---

## 10. Validate `original` Text Exists in Input Before Accepting

**Current:** `_isValidCorrection()` checks `sourceText.contains(originalLower)` which is good, but uses case-insensitive matching. The `startOffset` resolution in `_parseItem` also uses case-insensitive fallback.

**Problem:** Case-insensitive matching can cause a correction for "The" to match a different "the" in the text, leading to the correction being applied at the wrong position.

**Proposal:** Strengthen validation by first requiring case-sensitive match:

```dart
// In _findOffsetByText:
// 1. Try exact (case-sensitive) match first
for (final sentence in sentences) {
  final index = sentence.text.indexOf(text);
  if (index >= 0) return sentence.startOffset + index;
}
// 2. Only fall back to case-insensitive if exact match fails
```

This is already the current behavior in the code — good. But additionally, after resolving the offset, verify that the text at that position actually matches `original`:

```dart
// After computing startOffset, verify:
final actualText = fullText.substring(startOffset, startOffset + original.length);
if (actualText != original && actualText.toLowerCase() != original.toLowerCase()) {
  return null; // reject this correction
}
```

---

## 11. Add Retry Logic for Empty/Malformed Output

**Current:** If the model returns garbage or an empty string, the batch produces zero corrections and moves on silently.

**Proposal:** Add a single retry for batches that produce unparseable output:

```dart
var rawOutput = await onInfer(prompt);
var corrections = CorrectionParser.parse(rawOutput, batch, baseOffset: ...);

// Retry once if output looks malformed
if (rawOutput.trim().isNotEmpty &&
    !rawOutput.contains('<corrections') &&
    retryCount == 0) {
  rawOutput = await onInfer(prompt);
  corrections = CorrectionParser.parse(rawOutput, batch, baseOffset: ...);
}
```

**Why:** Small models occasionally produce degenerate output on a single run (especially Q2_K). A single retry is cheap and often produces a valid result. Limit to 1 retry to avoid infinite loops.

---

## 12. Use Model-Specific Prompt Formats

**Current:** All models use `PromptFormat.phi3Chat` regardless of the actual model.

**Problem:** The Mistral-7B model (used for Ukrainian) uses a different chat template than Phi-3. Using Phi-3 tokens (`<|system|>`, `<|user|>`, `<|assistant|>`) with Mistral may produce suboptimal results since Mistral expects `[INST]...[/INST]` formatting.

**Proposal:** Add a Mistral prompt format and select based on the loaded model:

```dart
enum PromptFormat {
  phi3Chat,
  mistralInstruct,
  plainInstruction,
}
```

With Mistral format:
```
<s>[INST] {systemPrompt}

{userInstruction}

"""
{sentenceText}
"""
[/INST]
```

Select the format based on model ID:
```dart
final format = modelId.contains('Mistral')
    ? PromptFormat.mistralInstruct
    : PromptFormat.phi3Chat;
```

**Why:** Using the correct chat template for each model family significantly improves instruction following. Mistral with Phi-3 tokens works "okay" but loses the benefit of the model's fine-tuned instruction-following behavior.

---

## 13. Cap `maxTokens` Relative to Input Length

**Current:** `maxTokens = 512` always.

**Proposal:** Scale `maxTokens` based on input size:

```dart
// Rough heuristic: corrections XML is typically 3-5x the error text length,
// and most text has <10% errors, so maxTokens ~ inputTokens * 0.5 + baseline
final estimatedMaxTokens = (promptTokenCount * 0.5 + 64).clamp(128, 1024).toInt();
```

**Why:**
- For short inputs (single sentence), 512 tokens is wasteful — the model may "fill" the budget with hallucinated corrections
- For long inputs, 512 may not be enough
- Dynamically scaling prevents both failure modes

---

## Summary: Priority Order

| # | Proposal | Impact | Effort |
|---|----------|--------|--------|
| 1 | Enable GBNF constrained generation | Very High | Low |
| 2 | Temperature → 0.0 | High | Trivial |
| 3 | Few-shot examples in prompts | High | Medium |
| 6 | Prefill `<corrections>` tag | High | Low |
| 12 | Model-specific prompt formats (Mistral) | High | Medium |
| 4 | Remove `<offset>` from model task | Medium | Low |
| 8 | Add `<\|end\|>` stop token | Medium | Trivial |
| 5 | Reduce topK to 10 | Medium | Trivial |
| 7 | Reduce sentencesPerBatch to 2 | Medium | Trivial |
| 9 | Negative examples for false positives | Medium | Medium |
| 11 | Single retry for malformed output | Medium | Low |
| 10 | Stricter offset validation | Low | Low |
| 13 | Dynamic maxTokens | Low | Low |
