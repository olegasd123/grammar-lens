/** A single grammar correction. */
export interface Correction {
  startOffset: number;
  endOffset: number;
  originalText: string;
  correctedText: string;
  type: 'grammar' | 'spelling' | 'punctuation' | 'style';
  explanation: string;
  confidence: number;
}

/** Request sent to the native messaging host. */
export interface AnalyzeRequest {
  action: 'analyze';
  text: string;
  language?: string;
}

/** Response from the native messaging host. */
export interface AnalyzeResponse {
  success: boolean;
  corrections: Correction[];
  language: string;
  analysisTimeMs: number;
  error?: string;
}

/** Message from content script to service worker. */
export interface ContentMessage {
  type: 'analyze' | 'status';
  tabId?: number;
  text?: string;
  language?: string;
}

/** Message from service worker to content script. */
export interface BackgroundMessage {
  type: 'corrections' | 'error' | 'status';
  corrections?: Correction[];
  error?: string;
  isConnected?: boolean;
}
