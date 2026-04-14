require('dotenv').config();
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const path = require('path');

// ── Config ──────────────────────────────────────────────
const {
  BOT_TOKEN,
  VPN_API_URL = 'http://localhost:8080',
  VPN_ADMIN_TOKEN,
  WEBAPP_URL = 'http://localhost:3000',
  PORT = 3000,
} = process.env;

if (!BOT_TOKEN) {
  console.error('❌ BOT_TOKEN не задан в .env');
  process.exit(1);
}
if (!VPN_ADMIN_TOKEN) {
  console.error('❌ VPN_ADMIN_TOKEN не задан в .env');
  process.exit(1);
}

// Optional second bot (polling). Default: off — use `telegram-bot` (Python) as the primary bot and
// keep this process as HTTPS static + `/api/*` proxy only.
const START_TELEGRAM_BOT_POLLING = String(process.env.START_TELEGRAM_BOT_POLLING || '').trim() === '1';

// ── Telegram Bot (optional) ─────────────────────────────
if (START_TELEGRAM_BOT_POLLING) {
  const TelegramBot = require('node-telegram-bot-api');
  const bot = new TelegramBot(BOT_TOKEN, { polling: true });

  bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const firstName = msg.from.first_name || 'друг';

    bot.sendMessage(chatId, `Привет, ${firstName}! 👋\n\nЯ — бот для управления VPN-подпиской.\nНажми кнопку ниже, чтобы открыть приложение.`, {
      reply_markup: {
        inline_keyboard: [[
          {
            text: '🔐 Открыть VPN',
            web_app: { url: WEBAPP_URL },
          },
        ]],
      },
    });
  });

  bot.onText(/\/help/, (msg) => {
    bot.sendMessage(msg.chat.id, [
      '📖 *Команды:*',
      '/start — открыть приложение',
      '/help — эта справка',
      '',
      'Всё управление через Mini App — нажми кнопку «Открыть VPN».',
    ].join('\n'), { parse_mode: 'Markdown' });
  });

  console.log('🤖 Telegram polling bot enabled (START_TELEGRAM_BOT_POLLING=1)');
} else {
  console.log('🤖 Telegram polling disabled (set START_TELEGRAM_BOT_POLLING=1 to enable node-telegram-bot-api)');
}

// ── Express (API proxy + static) ────────────────────────
const app = express();
app.use(cors());
app.use(express.json());

// Serve Mini App static files
app.use(express.static(path.join(__dirname, '..', 'webapp')));

// ── Auth: validate Telegram initData ────────────────────
function validateTelegramData(initData) {
  if (!initData) return null;

  try {
    const params = new URLSearchParams(initData);
    const hash = params.get('hash');
    if (!hash) return null;

    const authDateRaw = params.get('auth_date');
    const authDate = Number(authDateRaw);
    if (!Number.isFinite(authDate)) return null;
    const ageSec = Math.abs(Date.now() / 1000 - authDate);
    if (ageSec > 24 * 3600) return null;

    params.delete('hash');
    const entries = [...params.entries()].sort(([a], [b]) => a.localeCompare(b));
    const dataCheckString = entries.map(([k, v]) => `${k}=${v}`).join('\n');

    const secretKey = crypto
      .createHmac('sha256', 'WebAppData')
      .update(BOT_TOKEN)
      .digest();

    const checkHash = crypto
      .createHmac('sha256', secretKey)
      .update(dataCheckString)
      .digest('hex');

    if (checkHash !== hash) return null;

    const userStr = params.get('user');
    if (!userStr) return null;

    return JSON.parse(userStr);
  } catch {
    return null;
  }
}

// Middleware: extract Telegram user from initData header
function authMiddleware(req, res, next) {
  const initData = req.headers['x-telegram-init-data'];
  const user = validateTelegramData(initData);

  if (!user) {
    return res.status(401).json({ error: 'Unauthorized: invalid Telegram data' });
  }

  req.tgUser = user;
  req.vpnUserId = `tg_${user.id}`;
  next();
}

// ── API Routes ──────────────────────────────────────────

// Helper: call vpn-productd
async function vpnApi(method, endpoint, body) {
  const url = `${VPN_API_URL}${endpoint}`;
  const opts = {
    method,
    headers: {
      'Authorization': `Bearer ${VPN_ADMIN_TOKEN}`,
      'Content-Type': 'application/json',
    },
  };
  if (body) opts.body = JSON.stringify(body);

  const resp = await fetch(url, opts);
  const text = await resp.text();

  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }

  return { status: resp.status, data };
}

// GET /api/status — получить статус подписки текущего пользователя
app.get('/api/status', authMiddleware, async (req, res) => {
  try {
    const result = await vpnApi('GET', `/admin/user/${req.vpnUserId}/status`);
    if (result.status < 200 || result.status >= 300) {
      return res.status(result.status >= 400 ? result.status : 502).json(result.data);
    }
    res.json({
      userId: req.vpnUserId,
      tgUser: {
        id: req.tgUser.id,
        firstName: req.tgUser.first_name,
        username: req.tgUser.username,
      },
      ...result.data,
    });
  } catch (err) {
    console.error('Status error:', err);
    res.status(502).json({ error: 'VPN API unavailable' });
  }
});

// POST /api/subscribe — выдать/продлить подписку
app.post('/api/subscribe', authMiddleware, async (req, res) => {
  try {
    const result = await vpnApi('POST', '/admin/issue/link', {
      userId: req.vpnUserId,
      source: 'telegram_miniapp',
    });
    if (result.status < 200 || result.status >= 300) {
      return res.status(result.status >= 400 ? result.status : 502).json(result.data);
    }
    res.json(result.data);
  } catch (err) {
    console.error('Subscribe error:', err);
    res.status(502).json({ error: 'VPN API unavailable' });
  }
});

// GET /api/profile — данные профиля пользователя
app.get('/api/profile', authMiddleware, async (req, res) => {
  try {
    const result = await vpnApi('GET', `/admin/user/${req.vpnUserId}/profile`);
    if (result.status < 200 || result.status >= 300) {
      return res.status(result.status >= 400 ? result.status : 502).json(result.data);
    }
    res.json({
      userId: req.vpnUserId,
      tgUser: {
        id: req.tgUser.id,
        firstName: req.tgUser.first_name,
        lastName: req.tgUser.last_name,
        username: req.tgUser.username,
      },
      ...result.data,
    });
  } catch (err) {
    console.error('Profile error:', err);
    res.status(502).json({ error: 'VPN API unavailable' });
  }
});

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

// Fallback: serve index.html for SPA
app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, '..', 'webapp', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`🌐 Сервер запущен на порту ${PORT}`);
  console.log(`📱 Mini App URL: ${WEBAPP_URL}`);
});
