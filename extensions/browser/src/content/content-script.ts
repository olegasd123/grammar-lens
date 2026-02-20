import type {
  Correction,
  ContentMessage,
  BackgroundMessage,
} from '../shared/types';

/**
 * GrammarLens Content Script
 *
 * Injected into every web page to:
 * 1. Detect editable text fields (textarea, input, contenteditable)
 * 2. Extract text when the user finishes typing (debounced)
 * 3. Send text to the service worker for analysis
 * 4. Render correction overlays (underlines + popups)
 */

const DEBOUNCE_MS = 800;
let debounceTimer: ReturnType<typeof setTimeout> | null = null;
let activeElement: HTMLElement | null = null;
let currentCorrections: Correction[] = [];

/**
 * Check if an element is an editable text field.
 */
function isEditableElement(element: Element | null): element is HTMLElement {
  if (!element) return false;

  if (element instanceof HTMLTextAreaElement) return true;
  if (
    element instanceof HTMLInputElement &&
    ['text', 'search', 'email', 'url'].includes(element.type)
  ) {
    return true;
  }
  if ((element as HTMLElement).isContentEditable) return true;

  return false;
}

/**
 * Extract text content from an editable element.
 */
function getElementText(element: HTMLElement): string {
  if (element instanceof HTMLTextAreaElement || element instanceof HTMLInputElement) {
    return element.value;
  }
  if (element.isContentEditable) {
    return element.innerText;
  }
  return '';
}

/**
 * Send text to the background service worker for analysis.
 */
function requestAnalysis(text: string): void {
  if (text.trim().length < 10) return; // Skip very short text

  const message: ContentMessage = {
    type: 'analyze',
    text,
  };

  chrome.runtime.sendMessage(message, (response: BackgroundMessage) => {
    if (chrome.runtime.lastError) {
      console.warn('[GrammarLens]', chrome.runtime.lastError.message);
      return;
    }

    if (response?.type === 'corrections' && response.corrections) {
      currentCorrections = response.corrections;
      renderCorrections(response.corrections);
    } else if (response?.type === 'error') {
      console.warn('[GrammarLens] Analysis error:', response.error);
    }
  });
}

/**
 * Render correction underlines on the page.
 *
 * For textarea/input elements, corrections are shown in a floating
 * panel below the element. For contenteditable, corrections can be
 * rendered as inline highlights.
 */
function renderCorrections(corrections: Correction[]): void {
  // Remove existing overlays
  clearOverlays();

  if (corrections.length === 0 || !activeElement) return;

  // Create a floating panel below the active element
  const panel = document.createElement('div');
  panel.className = 'grammarlens-panel';
  panel.setAttribute('data-grammarlens', 'true');

  const header = document.createElement('div');
  header.className = 'grammarlens-header';
  header.textContent = `GrammarLens: ${corrections.length} suggestion${corrections.length === 1 ? '' : 's'}`;
  panel.appendChild(header);

  for (const correction of corrections.slice(0, 5)) {
    const item = document.createElement('div');
    item.className = `grammarlens-item grammarlens-${correction.type}`;
    item.innerHTML = `
      <span class="grammarlens-original">${escapeHtml(correction.originalText)}</span>
      <span class="grammarlens-arrow">&rarr;</span>
      <span class="grammarlens-corrected">${escapeHtml(correction.correctedText)}</span>
      <div class="grammarlens-explanation">${escapeHtml(correction.explanation)}</div>
    `;
    panel.appendChild(item);
  }

  // Position below the active element
  const rect = activeElement.getBoundingClientRect();
  panel.style.position = 'fixed';
  panel.style.left = `${rect.left}px`;
  panel.style.top = `${rect.bottom + 4}px`;
  panel.style.zIndex = '2147483647';

  document.body.appendChild(panel);
}

/**
 * Remove all GrammarLens overlay elements.
 */
function clearOverlays(): void {
  document
    .querySelectorAll('[data-grammarlens]')
    .forEach((el) => el.remove());
}

/**
 * Escape HTML to prevent XSS.
 */
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.appendChild(document.createTextNode(text));
  return div.innerHTML;
}

// ── Event Listeners ──────────────────────────────────────────────────────

// Track focus on editable elements
document.addEventListener('focusin', (event) => {
  const target = event.target as Element;
  if (isEditableElement(target)) {
    activeElement = target;
  }
});

document.addEventListener('focusout', () => {
  // Delay to allow clicking on the correction panel
  setTimeout(() => {
    clearOverlays();
  }, 200);
});

// Debounced input monitoring
document.addEventListener('input', (event) => {
  const target = event.target as Element;
  if (!isEditableElement(target)) return;

  activeElement = target;

  if (debounceTimer) {
    clearTimeout(debounceTimer);
  }

  debounceTimer = setTimeout(() => {
    const text = getElementText(target);
    requestAnalysis(text);
  }, DEBOUNCE_MS);
});

console.log('[GrammarLens] Content script loaded');
