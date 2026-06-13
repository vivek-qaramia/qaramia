"""Generate two self-contained HTML pitch decks (Founders Fund + Benchmark)."""
import html
import json

LOGO_SVG = '''<svg viewBox="0 0 320 320" width="46" height="46" aria-hidden="true">
  <defs>
    <linearGradient id="stem" gradientUnits="userSpaceOnUse" x1="124" y1="72" x2="124" y2="248">
      <stop offset="0%" stop-color="#FFD166"/><stop offset="45%" stop-color="#FF8A5C"/><stop offset="100%" stop-color="#E94560"/>
    </linearGradient>
    <linearGradient id="bowl" x1="25%" y1="10%" x2="75%" y2="90%">
      <stop offset="0%" stop-color="#FF6B81"/><stop offset="100%" stop-color="#C9184A"/>
    </linearGradient>
  </defs>
  <path d="M 124 72 A 58 58 0 0 1 124 188" fill="none" stroke="url(#bowl)" stroke-width="30" stroke-linecap="round"/>
  <line x1="124" y1="72" x2="124" y2="248" stroke="url(#stem)" stroke-width="30" stroke-linecap="round"/>
</svg>'''

# ── Shared slide content ──────────────────────────────────────────────────────
FF = {
    'fund': 'Founders Fund',
    'lens': 'Contrarian secret → proprietary tech → monopoly (Zero to One). Vision-led.',
    'slides': [
        ('The one-liner', 'A contrarian belief stated as fact. Make the partner lean in.', [
            'Every product shown OR spoken in a live stream becomes a shoppable ad in real time.',
            'Western platforms have live + short video — nobody connected the camera to the checkout.',
            'peekuu turns the content itself into ad inventory.']),
        ('The secret', 'The non-obvious truth others miss + why it is hard (so it is defensible).', [
            'Live commerce in the West fails on attribution: matching the right product/ad to the moment is a hard multimodal problem.',
            'We solved it: barcode + Claude Vision (what is seen) + speech detection (what is said) → product + targeted ad in ~2s.',
            'Only became cheap to solve now — that is the unfair timing.']),
        ('Why now', 'Inevitability — the wave is forming and we are early.', [
            'AI made real-time multimodal detection cheap and accurate.',
            'TikTok Shop proved Western appetite for social commerce — and left the attribution layer open.',
            'Regulatory tailwind: EU Accessibility Act + ADA make captions mandatory — we ship them as a feature.']),
        ('The opportunity gap — 20x and wide open', 'Why the white space exists and why it is defensible.', [
            'Asia’s live commerce is ~$370B; the US is ~$17B — a ~20x gap that is structural, not a demand problem.',
            'In China the feed-first model won: Douyin took 47% of live-commerce GMV while marketplace-native Taobao trailed — content out-converts the store.',
            'In the West the four pieces — feed, live, danmaku, shoppability — sit in four separate apps; peekuu is the only one fusing all four.',
            'The piece even Asia has not productized: automatic vision+speech product detection. TikTok’s pilot is vision-only and opt-in — peekuu ships the full auto-detect.']),
        ('The magic moment', 'One live demo that makes the secret undeniable.', [
            'A streamer says “I love this Stanley cup” — 2 seconds later a shoppable card + matched ad appears for every viewer.',
            'No tagging, no setup. Vision + voice did it automatically.',
            'This single demo IS the pitch.']),
        ('Monopoly thesis — the compounding moat', 'Why this becomes a monopoly, not a feature a giant clones.', [
            'Flywheel: more streams → bigger product catalog + transcript corpus + advertiser network → detection accuracy improves on BOTH signals → better targeting → more advertisers + creators.',
            'The moat is the proprietary multimodal dataset, not the UI.',
            'Switching costs accrue: creator earnings + audience, advertiser performance history.']),
        ('The second act is the real prize', 'The 10x-bigger business hiding behind the consumer app.', [
            'Brand-intelligence SaaS: “every mention of my brand or competitor across peekuu last week.”',
            'Comparables (Sprinklr, Talkwalker) charge $20K–$200K/year — pure-margin SaaS on top of the ad model.',
            'Live commerce is the consumer wedge; the data layer is the monopoly.']),
        ('Market: wedge to monopoly', 'A definite, large vision — power-law sized.', [
            'Wedge: creator live commerce. [Insert live-commerce / creator-economy TAM + source.]',
            'Expansion: every video platform needs shoppable + attribution + accessibility — peekuu is the layer.',
            'End state: the commerce-and-attention graph for live video in the West.']),
        ('Business model — many layers, one viewer action', 'Multiple revenue layers compounding on one action.', [
            'Ads ($25 CPM floor) + affiliate clicks on detected products.',
            'Gifting: coins → creator diamonds → cash-out (platform take rate); sponsored brand gifts.',
            'Brand-intelligence SaaS (the second act).']),
        ('Traction — built, fast', 'Velocity + the hard tech already works.', [
            'Shipped in weeks: mobile (iOS/Android) + web studio + Firebase backend + Agora RTC.',
            'Live: multimodal detection, gifting + payouts, co-host, virtual-background rooms, post-stream editor, record-to-feed.',
            '[Insert early usage / pilot creators / waitlist — or state pre-launch honestly.]']),
        ('Team', 'Why YOU are the inevitable founder for this secret.', [
            '[Founder background: why you see this secret others do not.]',
            '[Unfair advantages: domain, distribution, technical depth.]']),
        ('The ask', 'Specific raise + the singular milestone it buys.', [
            '[Raising $X to reach Y — e.g., live-commerce GMV / retained creators in N months.]',
            'Use of funds: [detection accuracy, creator acquisition, advertiser pilots].']),
    ],
}

BM = {
    'fund': 'Benchmark',
    'lens': 'Engagement loop → cohort retention → network effects (Sarah Tavel). Metrics-led.',
    'slides': [
        ('The one-liner', 'A consumer network with an escalating loop — not a feature.', [
            'peekuu is a live + short-video commerce network where watching turns into chatting, gifting, and buying.',
            'Every product shown or spoken becomes shoppable in real time — the loop monetizes itself.']),
        ('The engagement loop', 'Escalating engagement + accruing benefits + rising switching costs.', [
            'Watch → danmaku comment → send gift → tip earned coins → creator earns → creator streams more → richer feed.',
            'Accruing benefits: coin balance, follow graph, creator earnings + audience.',
            'Switching costs rise the more a user engages — on both sides.']),
        ('Retention is the thesis', 'A cohort retention curve that FLATTENS. The slide Benchmark buys on.', [
            '[Insert D1 / D7 / D30 cohort retention curve — the flattening tail is the whole pitch.]',
            '[Viewer retention AND creator retention, shown separately.]',
            'If the curve is not flat yet, that is the #1 thing to prove before this meeting.']),
        ('The magic moment', 'Show the loop firing + the commerce hook landing in seconds.', [
            'Streamer says “I love this Stanley cup” → shoppable card + matched ad for every viewer in ~2s.',
            'Viewer gifts → creator earns → appears on the live leaderboard / gift goal.',
            'Engagement and monetization in one motion.']),
        ('Why it is a network, not a feature', 'Defensibility vs. a giant bolting on a clone.', [
            'Two-sided: creators bring audiences; advertisers bring demand; product catalog + advertiser graph compound.',
            'Multimodal detection improves with usage — a data network effect, not just UI.',
            'A clone cannot replicate creator earnings history, audience, or the detection corpus.']),
        ('The white space — 20x gap, no fused competitor', 'The market is proven in Asia and structurally open in the West.', [
            'Asia ~$370B live commerce vs. US ~$17B — proven demand, not a hypothesis.',
            'Feed-first beats store-first: Douyin 47% of China live-commerce GMV vs. marketplace-native Taobao trailing.',
            'No Western app fuses feed + live + danmaku + auto-shopping + gifting — TikTok, Twitch, Whatnot, YouTube each own one fragment.',
            'TikTok pays creators as little as ~40% on gifts vs. Twitch/YouTube ~70% — peekuu’s tiered split is a direct creator-acquisition wedge.']),
        ('Unit economics of one viewer action', 'Engagement converts to durable, expanding margin per user.', [
            'Gifting: coins → diamonds → cash-out, platform take rate [insert %].',
            'Ads ($25 CPM floor) + affiliate clicks; sponsored brand gifts.',
            '[Insert ARPDAU / contribution margin per active stream.]']),
        ('The detection moat (brief)', 'The proprietary layer that makes the network compound.', [
            'Barcode + Claude Vision + speech detection turns content into ad inventory automatically.',
            'Accuracy compounds with the catalog + transcript corpus → a widening data moat.']),
        ('Market', 'Large enough for a venture-scale network outcome.', [
            'Wedge: creator live commerce. [Insert TAM / SAM + source.]',
            'Adjacent: short-video commerce + creator monetization + brand intelligence.']),
        ('Traction & metrics', 'Early signal of product-market fit — proof, not promises.', [
            '[Core funnel: DAU/WAU, sessions/day, stream length, gift conversion, GMV.]',
            '[Creator metrics: active creators, repeat-stream rate, earnings.]',
            'Shipped end-to-end on mobile + web (live, gifting, payouts, detection, editor).']),
        ('Team', 'Why this team out-executes on a consumer network.', [
            '[Founder background + why you understand this loop.]',
            '[Shipping velocity as evidence — full stack live in weeks.]']),
        ('The ask', 'Specific raise tied to the retention/network milestone.', [
            '[Raising $X to reach Y retained creators / cohort-retention target in N months.]',
            'Use of funds: [creator growth, retention loops, detection accuracy].']),
    ],
}

CSS = '''
*{margin:0;padding:0;box-sizing:border-box}
:root{--peach:#FF7043;--gold:#FFD166;--love:#E94560;--wine:#1F0B14;--wine2:#14060C}
html,body{height:100%}
body{font-family:'Inter',system-ui,Segoe UI,Roboto,sans-serif;background:var(--wine2);color:#fff;overflow:hidden}
.wordmark{font-family:'Playfair Display',Georgia,serif;font-style:italic;font-weight:600;
  background:linear-gradient(135deg,#FF8A5C,#E94560);-webkit-background-clip:text;background-clip:text;color:transparent}
#deck{position:relative;height:100vh;width:100vw}
.slide{position:absolute;inset:0;display:none;flex-direction:column;justify-content:center;
  padding:7vh 9vw;background:radial-gradient(120% 120% at 30% 10%,#2a0f1c 0%,var(--wine) 45%,var(--wine2) 100%)}
.slide.active{display:flex;animation:fade .35s ease}
@keyframes fade{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
.kicker{font-size:13px;letter-spacing:3px;font-weight:800;color:#ffffff66;margin-bottom:18px}
h1{font-size:min(6vw,52px);line-height:1.08;color:var(--peach);margin-bottom:26px;font-weight:800}
ul{list-style:none;max-width:1000px}
li{font-size:min(2.5vw,23px);line-height:1.5;color:#f2e9ec;margin:14px 0;padding-left:26px;position:relative}
li::before{content:'';position:absolute;left:0;top:13px;width:9px;height:9px;border-radius:50%;
  background:linear-gradient(135deg,var(--gold),var(--love))}
.note{position:absolute;left:9vw;right:9vw;bottom:8vh;font-size:14px;color:var(--gold);font-style:italic;
  border-left:3px solid var(--gold);padding-left:12px;display:none}
body.notes .note{display:block}
.brand{position:absolute;top:4vh;left:9vw;display:flex;align-items:center;gap:10px}
.brand .wordmark{font-size:26px}
.counter{position:absolute;bottom:4vh;right:5vw;font-size:13px;color:#ffffff55;font-weight:600}
.bar{position:absolute;top:0;left:0;height:4px;background:linear-gradient(90deg,var(--gold),var(--peach),var(--love));transition:width .3s}
.hint{position:absolute;bottom:4vh;left:5vw;font-size:12px;color:#ffffff33}
/* cover */
.cover{align-items:flex-start;justify-content:center}
.cover .big{font-size:min(13vw,120px);line-height:1}
.cover .tag{font-size:min(3vw,26px);color:#f2e9ec;margin-top:18px}
.cover .fund{margin-top:40px;font-size:min(3vw,24px);font-weight:800;color:var(--gold)}
.cover .lens{margin-top:8px;font-size:16px;color:#ffffff88;max-width:760px}
.cover .fillnote{margin-top:30px;font-size:13px;color:#ffffff55;font-style:italic;max-width:760px}
'''

JS = '''
const slides=[...document.querySelectorAll('.slide')];let i=0;
const bar=document.getElementById('bar');
function show(n){i=Math.max(0,Math.min(slides.length-1,n));
  slides.forEach((s,k)=>s.classList.toggle('active',k===i));
  bar.style.width=((i)/(slides.length-1)*100)+'%';}
document.addEventListener('keydown',e=>{
  if(['ArrowRight',' ','ArrowDown','PageDown'].includes(e.key)){show(i+1);e.preventDefault();}
  else if(['ArrowLeft','ArrowUp','PageUp'].includes(e.key)){show(i-1);e.preventDefault();}
  else if(e.key==='n'||e.key==='N'){document.body.classList.toggle('notes');}
  else if(e.key==='f'||e.key==='F'){if(!document.fullscreenElement)document.documentElement.requestFullscreen();else document.exitFullscreen();}
});
document.getElementById('deck').addEventListener('click',e=>{if(e.clientX<window.innerWidth*0.25)show(i-1);else show(i+1);});
show(0);
'''


def esc(s):
    return html.escape(s)


def build(data, out_path):
    total = len(data['slides']) + 1  # + cover
    parts = []
    # cover
    parts.append(f'''<section class="slide cover active">
      <div class="big wordmark">peekuu</div>
      <div class="tag">Live Streaming &amp; Commerce — the camera connected to the checkout</div>
      <div class="fund">Pitch cut for: {esc(data['fund'])}</div>
      <div class="lens">{esc(data['lens'])}</div>
      <div class="fillnote">[brackets] = insert real figures before sending. Press <b>N</b> for coaching notes, <b>F</b> for fullscreen, arrows / click to navigate.</div>
    </section>''')
    for n, (title, note, bullets) in enumerate(data['slides'], start=1):
        lis = ''.join(f'<li>{esc(b)}</li>' for b in bullets)
        parts.append(f'''<section class="slide">
      <div class="kicker">SLIDE {n} / {total - 1}</div>
      <h1>{esc(title)}</h1>
      <ul>{lis}</ul>
      <div class="note"><b>What this slide must land:</b> {esc(note)}</div>
    </section>''')
    slides_html = '\n'.join(parts)
    doc = f'''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>peekuu — {esc(data['fund'])} pitch</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&family=Playfair+Display:ital,wght@1,600&display=swap" rel="stylesheet">
<style>{CSS}</style></head>
<body>
<div class="bar" id="bar"></div>
<div id="deck">
  <div class="brand">{LOGO_SVG}<span class="wordmark">peekuu</span></div>
  {slides_html}
  <div class="counter" id="counter"></div>
  <div class="hint">← → navigate · N notes · F fullscreen</div>
</div>
<script>{JS}</script>
</body></html>'''
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(doc)
    print('Wrote', out_path)


build(FF, 'E:/claude/qaramia-v2/Peekuu-Pitch-FoundersFund.html')
build(BM, 'E:/claude/qaramia-v2/Peekuu-Pitch-Benchmark.html')
'''DONE'''
