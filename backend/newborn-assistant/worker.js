const ALLOWED_ORIGIN = 'https://mmostafa4.github.io';
const MAX_QUESTION_CHARS = 900;
const REQUESTS_PER_HOUR = 6;

const newbornInstructions = [
  'You provide general educational information for parents of newborns and infants.',
  'Answer in clear, brief Arabic unless the question is in another language.',
  'You are not a clinician. Do not diagnose, prescribe, recommend medication doses, or replace an in-person examination.',
  'Do not ask for the child’s name, address, phone number, or other identifying information.',
  'If the question suggests difficulty breathing, blue lips or face, seizure, unresponsiveness, severe lethargy, inability to feed, green or bloody vomit, or another immediate danger, begin with a clear instruction to contact local emergency services or go to emergency care now.',
  'A temperature of 38°C or higher in an infant younger than 3 months needs urgent in-person medical assessment. State this plainly when relevant.',
  'Do not invent country-specific vaccine dates or product choices. Direct vaccine-schedule questions to the app schedule and the local health center.',
  'For uncertain or individual medical concerns, advise contacting the child’s pediatrician or local health service.',
  'Use simple language and keep ordinary answers to 3–6 short lines.',
].join('\n');

function corsHeaders(origin) {
  const headers = new Headers({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Vary': 'Origin',
    'X-Content-Type-Options': 'nosniff',
  });
  if (origin === ALLOWED_ORIGIN) {
    headers.set('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
    headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Content-Type');
    headers.set('Access-Control-Max-Age', '600');
  }
  return headers;
}

function jsonResponse(status, value, origin) {
  return new Response(JSON.stringify(value), {
    status,
    headers: corsHeaders(origin),
  });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';

    if (request.method === 'OPTIONS') {
      if (origin !== ALLOWED_ORIGIN) {
        return new Response(null, { status: 403, headers: corsHeaders(origin) });
      }
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    const url = new URL(request.url);
    if (url.pathname === '/health' && request.method === 'GET') {
      return jsonResponse(200, { status: 'ok' }, origin);
    }
    if (url.pathname !== '/v1/newborn-qa' || request.method !== 'POST') {
      return jsonResponse(404, { error: 'Not found.' }, origin);
    }
    if (origin !== ALLOWED_ORIGIN) {
      return jsonResponse(403, { error: 'Origin not allowed.' }, origin);
    }
    const contentLength = Number(request.headers.get('Content-Length') || 0);
    if (contentLength > 5000) {
      return jsonResponse(413, { error: 'السؤال أكبر من الحد المسموح.' }, origin);
    }
    if (!env.OPENAI_API_KEY) {
      return jsonResponse(503, { error: 'خدمة المساعد لم تكتمل إعداداتها بعد.' }, origin);
    }
    if (!env.RATE_LIMITER) {
      return jsonResponse(503, { error: 'خدمة المساعد غير جاهزة بعد.' }, origin);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return jsonResponse(400, { error: 'أرسلي السؤال بصيغة صحيحة.' }, origin);
    }
    if (!body || typeof body.question !== 'string') {
      return jsonResponse(400, { error: 'اكتبي سؤالًا قبل الإرسال.' }, origin);
    }
    const question = body.question.trim();
    if (question.length < 2 || question.length > MAX_QUESTION_CHARS) {
      return jsonResponse(400, { error: 'يجب أن يكون السؤال بين حرفين و900 حرف.' }, origin);
    }

    const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
    const limiterId = env.RATE_LIMITER.idFromName(ip);
    const limiter = env.RATE_LIMITER.get(limiterId);
    const limitResponse = await limiter.fetch('https://rate-limit.internal/consume');
    if (limitResponse.status === 429) {
      return jsonResponse(429, { error: 'وصلنا إلى حد الأسئلة المؤقت. حاولي لاحقًا.' }, origin);
    }

    let modelResponse;
    try {
      modelResponse = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + env.OPENAI_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || 'gpt-5',
          instructions: newbornInstructions,
          input: question,
          max_output_tokens: 450,
          store: false,
        }),
      });
    } catch (_) {
      return jsonResponse(502, { error: 'تعذر الاتصال بخدمة الإجابة. حاولي لاحقًا.' }, origin);
    }

    if (!modelResponse.ok) {
      return jsonResponse(502, { error: 'لم تصل إجابة من النموذج. حاولي لاحقًا.' }, origin);
    }

    let result;
    try {
      result = await modelResponse.json();
    } catch (_) {
      return jsonResponse(502, { error: 'وصل رد غير صالح من خدمة الإجابة.' }, origin);
    }
    const answer = (result.output || [])
      .filter((item) => item.type === 'message')
      .flatMap((item) => item.content || [])
      .filter((item) => item.type === 'output_text')
      .map((item) => item.text || '')
      .join('\n')
      .trim();
    if (!answer) {
      return jsonResponse(502, { error: 'لم يصل رد نصي صالح من النموذج.' }, origin);
    }

    return jsonResponse(200, { answer }, origin);
  },
};

export class RateLimiter {
  constructor(state) {
    this.state = state;
  }

  async fetch() {
    const now = Date.now();
    const windowMs = 60 * 60 * 1000;
    const allowed = await this.state.storage.transaction(async (transaction) => {
      let bucket = await transaction.get('hourly');
      if (!bucket || now - bucket.startedAt >= windowMs) {
        bucket = { startedAt: now, count: 0 };
      }
      if (bucket.count >= REQUESTS_PER_HOUR) {
        await transaction.put('hourly', bucket);
        return false;
      }
      bucket.count += 1;
      await transaction.put('hourly', bucket);
      return true;
    });
    return new Response(null, { status: allowed ? 204 : 429 });
  }
}
