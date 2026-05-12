import { NextRequest, NextResponse } from 'next/server';
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

export async function POST(request: NextRequest) {
  const { image } = await request.json() as { image: string };

  if (!image) {
    return NextResponse.json({ products: [] }, { status: 400 });
  }

  try {
    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 512,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: { type: 'base64', media_type: 'image/jpeg', data: image },
            },
            {
              type: 'text',
              text: 'Identify any products, brands, or items visible in this image. Return ONLY valid JSON in this exact format: {"products": [{"name": "product name", "brand": "brand name", "description": "brief description", "category": "one of: beauty|food|tech|fitness|fashion|home|other"}]}. Include up to 3 products. If nothing identifiable, return {"products": []}.',
            },
          ],
        },
      ],
    });

    const text = response.content[0].type === 'text' ? response.content[0].text.trim() : '';

    // Strip markdown code fences if present
    const json = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
    const parsed = JSON.parse(json);
    return NextResponse.json(parsed);
  } catch (err) {
    console.error('scan-product API error', err);
    return NextResponse.json({ products: [] });
  }
}
