import type {
  AnalyzeRequest,
  AnalyzeResponse,
  ContentMessage,
  BackgroundMessage,
} from '../shared/types';

const NATIVE_HOST_NAME = 'com.grammarlens.host';

let nativePort: chrome.runtime.Port | null = null;

/**
 * Connect to the native messaging host (GrammarLens desktop app).
 *
 * The native host is a compiled Dart executable that loads
 * the GGUF model and runs inference locally.
 */
function connectToNativeHost(): chrome.runtime.Port | null {
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);

    nativePort.onDisconnect.addListener(() => {
      console.log('[GrammarLens] Native host disconnected');
      nativePort = null;
    });

    console.log('[GrammarLens] Connected to native host');
    return nativePort;
  } catch (error) {
    console.error('[GrammarLens] Failed to connect to native host:', error);
    return null;
  }
}

/**
 * Send text to the native host for grammar analysis.
 */
function analyzeText(
  text: string,
  language?: string
): Promise<AnalyzeResponse> {
  return new Promise((resolve, reject) => {
    if (!nativePort) {
      nativePort = connectToNativeHost();
    }

    if (!nativePort) {
      reject(new Error('Native host not available. Is GrammarLens installed?'));
      return;
    }

    const request: AnalyzeRequest = {
      action: 'analyze',
      text,
      language,
    };

    const listener = (response: AnalyzeResponse) => {
      nativePort?.onMessage.removeListener(listener);
      resolve(response);
    };

    nativePort.onMessage.addListener(listener);
    nativePort.postMessage(request);

    // Timeout after 30 seconds
    setTimeout(() => {
      nativePort?.onMessage.removeListener(listener);
      reject(new Error('Analysis timed out'));
    }, 30000);
  });
}

// Listen for messages from content scripts
chrome.runtime.onMessage.addListener(
  (
    message: ContentMessage,
    sender: chrome.runtime.MessageSender,
    sendResponse: (response: BackgroundMessage) => void
  ) => {
    if (message.type === 'analyze' && message.text) {
      analyzeText(message.text, message.language)
        .then((response) => {
          sendResponse({
            type: 'corrections',
            corrections: response.corrections,
          });
        })
        .catch((error) => {
          sendResponse({
            type: 'error',
            error: error.message,
          });
        });

      // Return true to indicate async response
      return true;
    }

    if (message.type === 'status') {
      sendResponse({
        type: 'status',
        isConnected: nativePort !== null,
      });
      return false;
    }

    return false;
  }
);

console.log('[GrammarLens] Service worker initialized');
