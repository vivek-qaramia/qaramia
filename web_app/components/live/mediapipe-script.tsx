import Script from 'next/script';

// Loads MediaPipe Selfie Segmentation from CDN as a UMD global.
// Must be rendered on any page that uses SegmentationPipeline.
export function MediaPipeScript() {
  return (
    <Script
      src="https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation@0.1/selfie_segmentation.js"
      strategy="afterInteractive"
    />
  );
}
