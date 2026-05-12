import { BrowserMultiFormatReader, NotFoundException } from '@zxing/library';

let reader: BrowserMultiFormatReader | null = null;

function getReader(): BrowserMultiFormatReader {
  if (!reader) reader = new BrowserMultiFormatReader();
  return reader;
}

export async function scanBarcodeFromVideo(videoEl: HTMLVideoElement): Promise<string | null> {
  if (videoEl.readyState < 2 || !videoEl.videoWidth) return null;

  const canvas = document.createElement('canvas');
  canvas.width = videoEl.videoWidth;
  canvas.height = videoEl.videoHeight;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(videoEl, 0, 0);

  try {
    const result = await getReader().decodeFromImageUrl(canvas.toDataURL('image/png'));
    return result.getText();
  } catch (e) {
    if (e instanceof NotFoundException) return null;
    // ChecksumException / FormatException also mean "no barcode"
    return null;
  }
}
