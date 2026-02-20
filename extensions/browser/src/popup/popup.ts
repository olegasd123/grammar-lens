import type { BackgroundMessage } from '../shared/types';

// Check connection status
chrome.runtime.sendMessage({ type: 'status' }, (response: BackgroundMessage) => {
  const dot = document.getElementById('statusDot')!;
  const text = document.getElementById('statusText')!;

  if (chrome.runtime.lastError || !response) {
    dot.className = 'status-dot disconnected';
    text.textContent = 'Not connected — install GrammarLens desktop app';
    return;
  }

  if (response.isConnected) {
    dot.className = 'status-dot connected';
    text.textContent = 'Connected — checking grammar in real-time';
  } else {
    dot.className = 'status-dot disconnected';
    text.textContent = 'Not connected — open GrammarLens app';
  }
});
