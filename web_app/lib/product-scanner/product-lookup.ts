import type { ProductInfo } from './types';

// Open Food Facts — free, no key, covers food/grocery worldwide
async function tryOpenFoodFacts(barcode: string): Promise<ProductInfo | null> {
  try {
    const res = await fetch(
      `https://world.openfoodfacts.org/api/v2/product/${barcode}.json`,
      { signal: AbortSignal.timeout(4000) }
    );
    const data = await res.json();
    if (data.status !== 1 || !data.product) return null;
    const p = data.product;
    return {
      name: p.product_name || p.abbreviated_product_name,
      brand: p.brands,
      description: p.categories,
      imageUrl: p.image_front_small_url ?? p.image_url,
      barcode,
      source: 'barcode',
    };
  } catch {
    return null;
  }
}

// UPC Item DB — free trial (100 req/day), covers general retail
async function tryUpcItemDb(barcode: string): Promise<ProductInfo | null> {
  try {
    const res = await fetch(
      `https://api.upcitemdb.com/prod/trial/lookup?upc=${barcode}`,
      { signal: AbortSignal.timeout(4000) }
    );
    const data = await res.json();
    if (data.code !== 'OK' || !data.items?.length) return null;
    const item = data.items[0];
    return {
      name: item.title,
      brand: item.brand,
      description: item.description,
      imageUrl: item.images?.[0],
      barcode,
      source: 'barcode',
    };
  } catch {
    return null;
  }
}

export async function lookupBarcode(barcode: string): Promise<ProductInfo | null> {
  const food = await tryOpenFoodFacts(barcode);
  if (food?.name) return food;
  return tryUpcItemDb(barcode);
}
