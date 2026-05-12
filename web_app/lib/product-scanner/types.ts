export interface ProductInfo {
  name?: string;
  brand?: string;
  description?: string;
  imageUrl?: string;
  barcode?: string;
  source: 'barcode' | 'vision' | 'speech';
  category?: string;
}
