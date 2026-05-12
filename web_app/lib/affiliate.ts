const TAG = process.env.NEXT_PUBLIC_AMAZON_AFFILIATE_TAG;

export function affiliateUrl(query: string): string {
  const url = `https://www.amazon.com/s?k=${encodeURIComponent(query)}`;
  return TAG ? `${url}&tag=${TAG}` : url;
}
