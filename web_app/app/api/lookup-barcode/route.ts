import { NextRequest, NextResponse } from 'next/server';
import { lookupBarcode } from '@/lib/product-scanner/product-lookup';

export async function GET(request: NextRequest) {
  const barcode = request.nextUrl.searchParams.get('barcode');
  if (!barcode) {
    return NextResponse.json({ error: 'Missing barcode' }, { status: 400 });
  }

  try {
    const product = await lookupBarcode(barcode);
    if (!product) {
      return NextResponse.json({ barcode, name: barcode, source: 'barcode' });
    }
    return NextResponse.json(product);
  } catch (err) {
    console.error('lookup-barcode API error', err);
    return NextResponse.json({ barcode, name: barcode, source: 'barcode' });
  }
}
