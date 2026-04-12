#!/bin/bash
# AI Daily Site - Auto Update Script
# Run by cron or manually to update the site content
# Usage: bash update-site.sh

set -e

SITE_DIR="$HOME/ai-daily-site"
DATA_DIR="$SITE_DIR/data"
CONTENT_FILE="$DATA_DIR/content.json"
KNOWLEDGE_DIR="$HOME/knowledge-base/raw"
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

echo "🔄 Updating AI Daily Site - $TIMESTAMP"

# Update stock data
echo "📈 Fetching stock data..."
/usr/bin/python3 -c "
import yfinance as yf, json
from datetime import datetime

tickers = {
    'USAR': {'group': '持仓', 'notes': '100股 @ \$16.75 不止损', 'cost': 16.75, 'shares': 100},
    'CRDO': {'group': '持仓', 'notes': '10股 @ \$119 第1笔✅ 目标\$199', 'cost': 119.00, 'shares': 10},
    'POET': {'group': 'A-技术分析', 'notes': '', 'tier': 3},
    'ALAB': {'group': 'A-技术分析', 'notes': '', 'tier': 2},
    'IREN': {'group': 'A-技术分析', 'notes': '', 'tier': 2},
    'RCAT': {'group': 'A-技术分析', 'notes': '', 'tier': 2},
    'ASTS': {'group': 'A-技术分析', 'notes': '', 'tier': 3},
    'APLD': {'group': 'A-技术分析', 'notes': '', 'tier': 3},
    'MP':   {'group': 'A-技术分析', 'notes': '', 'tier': 3},
    'AEVA': {'group': 'A-技术分析', 'notes': '', 'tier': 3},
    'RKLB': {'group': 'A-技术分析', 'notes': '', 'tier': 2},
    'VST':  {'group': 'B-2026计划', 'notes': '', 'tier': 2},
    'NVTS': {'group': 'B-2026计划', 'notes': '', 'tier': 2},
    'PSTG': {'group': 'B-2026计划', 'notes': '', 'tier': 2},
    'CIFR': {'group': 'B-2026计划', 'notes': '', 'tier': 3},
    'RDDT': {'group': 'B-2026计划', 'notes': '待建仓 \$3,000 第1笔\$130-140 目标\$230', 'tier': 1},
    'SYM':  {'group': 'B-2026计划', 'notes': '', 'tier': 3},
    'UUUU': {'group': 'B-2026计划', 'notes': '', 'tier': 3},
    'DXYZ': {'group': 'B-2026计划', 'notes': '', 'tier': 3},
    'RIOT': {'group': 'B-2026计划', 'notes': '', 'tier': 3},
    'WOLF': {'group': 'B-2026计划', 'notes': '', 'tier': 3},
}

results = []
for sym, meta in tickers.items():
    try:
        info = yf.Ticker(sym).info
        price = info.get('currentPrice') or info.get('regularMarketPrice') or info.get('previousClose', 0)
        if isinstance(price, str): price = float(price)
        prev_close = info.get('previousClose') or info.get('regularMarketPreviousClose', 0)
        if isinstance(prev_close, str): prev_close = float(prev_close)
        change_pct = ((price - prev_close) / prev_close * 100) if price and prev_close else 0
        mkt_cap = info.get('marketCap', 0)
        fwd_pe = info.get('forwardPE', 0)
        if isinstance(fwd_pe, str): fwd_pe = float(fwd_pe)
        rev_growth = info.get('revenueGrowth', 0)
        high52 = info.get('fiftyTwoWeekHigh', 0)
        low52 = info.get('fiftyTwoWeekLow', 0)
        rec = info.get('recommendationKey', '')
        target_mean = info.get('targetMeanPrice', 0)
        from_high = ((price / high52 - 1) * 100) if price and high52 else 0
        from_low = ((price / low52 - 1) * 100) if price and low52 else 0
        pnl = pnl_pct = 0
        if 'cost' in meta and price:
            pnl = round((price - meta['cost']) * meta.get('shares', 0), 2)
            pnl_pct = round((price / meta['cost'] - 1) * 100, 2)
        results.append({'sym': sym, 'group': meta['group'], 'price': round(price,2) if price else None,
            'change': round(change_pct,2), 'mkt_cap': round(mkt_cap/1e9,2) if mkt_cap else None,
            'fwd_pe': round(fwd_pe,1) if fwd_pe else None, 'rev_growth': round(rev_growth*100,1) if rev_growth else None,
            'high52': round(high52,2) if high52 else None, 'low52': round(low52,2) if low52 else None,
            'from_high': round(from_high,1), 'from_low': round(from_low,1),
            'rec': rec, 'target': round(target_mean,2) if target_mean else None,
            'notes': meta.get('notes',''), 'tier': meta.get('tier'),
            'cost': meta.get('cost'), 'shares': meta.get('shares'), 'pnl': pnl, 'pnl_pct': pnl_pct})
        print(f'  ✅ {sym}: \${price:.2f}')
    except Exception as e:
        print(f'  ❌ {sym}: {e}')
        results.append({'sym': sym, 'group': meta['group'], 'price': None, 'notes': meta.get('notes','')})

with open('$DATA_DIR/stocks.json', 'w') as f:
    json.dump({'lastUpdate': datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'totalSymbols': len(results), 'stocks': results}, f, ensure_ascii=False, indent=2)
print(f'  ✅ Saved {len(results)} stocks')
" 2>&1 | grep -v 'NotOpenSSLWarning\|urllib3\|ssl module'

# Ensure git repo exists
cd "$SITE_DIR"
if [ ! -d ".git" ]; then
    echo "📦 Initializing git repo..."
    git init
    git add -A
    git commit -m "Initial commit"
fi

# Check if there are changes
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    echo "✅ No changes to publish"
    exit 0
fi

# Commit and push
git add -A
git commit -m "🔄 Auto update - $TIMESTAMP" || true

# Push if remote is set
if git remote | grep -q origin; then
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "⚠️ Push failed, check remote"
else
    echo "ℹ️ No remote set. Set one with: cd ~/ai-daily-site && git remote add origin <url>"
fi

echo "✅ Site updated at $TIMESTAMP"
