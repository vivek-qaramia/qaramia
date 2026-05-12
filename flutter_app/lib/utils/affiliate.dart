/// Build an Amazon affiliate search URL.
///
/// Mirrors the web app's lib/affiliate.ts. The associate tag is read from a
/// build-time --dart-define (AMAZON_AFFILIATE_TAG=...). If unset, the URL
/// resolves to a plain Amazon search — clicks won't earn commission but the
/// link still works for users.
const _amazonAffiliateTag = String.fromEnvironment('AMAZON_AFFILIATE_TAG');

String affiliateUrl(String query) {
  final encoded = Uri.encodeQueryComponent(query);
  final base = 'https://www.amazon.com/s?k=$encoded';
  return _amazonAffiliateTag.isEmpty ? base : '$base&tag=$_amazonAffiliateTag';
}

/// Build a generic search URL when no affiliate is configured.
String googleSearchUrl(String query) =>
    'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
