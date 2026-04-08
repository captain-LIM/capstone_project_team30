const express = require('express');
const multer = require('multer');
const cors = require('cors');
const { config } = require('./config');

const app = express();

// 파일 업로드 설정 
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    // 모든 이미지 형식 허용 
    if (file.mimetype.startsWith('image/') || file.mimetype === 'application/octet-stream') {
      cb(null, true);
    } else {
      cb(new Error('이미지 파일만 업로드 가능합니다.'));
    }
  },
});

// 미들웨어
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// IP 기반 레이트 리밋 (분당 30회)
const rateLimitMap = new Map();
function rateLimiter(req, res, next) {
  const ip = req.ip;
  const now = Date.now();
  const windowMs = 60 * 1000;
  const maxRequests = 30;

  if (!rateLimitMap.has(ip)) rateLimitMap.set(ip, []);
  const requests = rateLimitMap.get(ip).filter((t) => now - t < windowMs);
  requests.push(now);
  rateLimitMap.set(ip, requests);

  if (requests.length > maxRequests) {
    return res.status(429).json({ error: '요청이 너무 많습니다. 잠시 후 다시 시도하세요.' });
  }
  next();
}

// OpenRouter API 호출 
async function callOpenRouter(messages, retries = 3, maxTokens = 1024) {
  for (let attempt = 0; attempt < retries; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 60000);

    try {
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.openrouterApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'http://localhost:3000',
          'X-Title': 'Fridge Recipe App',
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash',
          messages,
          max_tokens: maxTokens,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (response.status === 429 && attempt < retries - 1) {
        await new Promise((r) => setTimeout(r, 10000));
        continue;
      }

      return response;
    } catch (error) {
      clearTimeout(timeout);
      if (attempt === retries - 1) throw error;
      await new Promise((r) => setTimeout(r, 2000 * (attempt + 1)));
    }
  }
}

// JSON 파싱 헬퍼
function extractJson(text) {
  const match = text.match(/\{[\s\S]*\}/);
  if (match) return JSON.parse(match[0]);
  throw new Error('JSON을 찾을 수 없습니다.');
}

// 서버 상태 확인
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// 냉장고 이미지 분석
app.post('/api/analyze', rateLimiter, upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: '이미지 파일이 필요합니다.' });
  }

  const base64 = req.file.buffer.toString('base64');
  // 미지원 형식은 jpeg로 처리
  const rawMime = req.file.mimetype;
  const mimeType = rawMime.startsWith('image/') ? rawMime : 'image/jpeg';

  console.log(`[/api/analyze] 이미지 수신: ${req.file.size} bytes, ${rawMime} → ${mimeType}`);

  try {
    const response = await callOpenRouter([
      {
        role: 'user',
        content: [
          {
            type: 'image_url',
            image_url: { url: `data:${mimeType};base64,${base64}` },
          },
          {
            type: 'text',
            text: '이 냉장고 사진에서 보이는 모든 식재료를 한국어로 나열해주세요. 각 재료를 쉼표로 구분하여 재료 이름만 나열해주세요. 예시: 계란, 우유, 당근, 양파',
          },
        ],
      },
    ], 3, 300); // 재료 목록은 300 토큰으로 충분

    const data = await response.json();
    console.log(`[/api/analyze] OpenRouter 응답 status: ${response.status}`);

    if (!response.ok) {
      console.error('[/api/analyze] OpenRouter 오류:', JSON.stringify(data));
      return res.status(500).json({ error: `AI 오류: ${data.error?.message ?? response.status}` });
    }

    const text = data.choices?.[0]?.message?.content ?? '';
    console.log(`[/api/analyze] AI 응답: ${text}`);

    if (!text) {
      return res.status(500).json({ error: 'AI 응답이 비어있습니다. 다시 시도해주세요.' });
    }

    // 쉼표 구분 또는 줄바꿈 구분 모두 처리
    const raw = text.replace(/\n/g, ',');
    const ingredients = raw
      .split(',')
      .map((i) => i.trim().replace(/^[-•\d.\s]+/, '').replace(/[^\uAC00-\uD7A3a-zA-Z0-9\s]/g, '').trim())
      .filter((i) => i.length > 0 && i.length < 20);

    if (ingredients.length === 0) {
      return res.status(500).json({ error: '재료를 인식하지 못했습니다. 냉장고 내부가 잘 보이는 사진을 사용해주세요.' });
    }

    res.json({ ingredients });
  } catch (error) {
    console.error('[/api/analyze] 예외:', error.message);
    res.status(500).json({ error: `이미지 분석 실패: ${error.message}` });
  }
});

// 레시피 추천
app.post('/api/recipes', rateLimiter, async (req, res) => {
  const { ingredients, previousRecipes = [], profile = {} } = req.body;

  if (!Array.isArray(ingredients) || ingredients.length === 0) {
    return res.status(400).json({ error: '재료 목록이 필요합니다.' });
  }

  const allergiesInfo =
    profile.allergies?.length > 0 ? `알레르기: ${profile.allergies.join(', ')}` : '';
  const dietaryInfo =
    profile.dietaryRestriction && profile.dietaryRestriction !== '없음'
      ? `식이제한: ${profile.dietaryRestriction}`
      : '';
  const cuisineInfo =
    profile.preferredCuisines?.length > 0
      ? `선호 요리: ${profile.preferredCuisines.join(', ')}`
      : '';
  const userContext = [allergiesInfo, dietaryInfo, cuisineInfo].filter(Boolean).join(' / ');
  const prevInfo =
    previousRecipes.length > 0
      ? `\n이미 추천한 레시피(중복 제외): ${previousRecipes.join(', ')}`
      : '';

  const prompt = `당신은 전문 요리사입니다. 다음 재료로 만들 수 있는 레시피 3-5개를 추천해주세요.

사용 가능한 재료: ${ingredients.join(', ')}
${userContext ? `사용자 정보: ${userContext}` : ''}${prevInfo}

다음 JSON 형식으로만 응답해주세요:
{
  "recipes": [
    {
      "name": "레시피 이름",
      "difficulty": "쉬움",
      "time": "20분",
      "description": "간단한 설명 (1-2문장)",
      "available": ["보유 재료1", "보유 재료2"],
      "additional": ["추가 필요 재료1"]
    }
  ]
}`;

  try {
    const response = await callOpenRouter([
      { role: 'system', content: '전문 요리사로서 JSON 형식으로만 응답합니다.' },
      { role: 'user', content: prompt },
    ], 3, 1500); // 레시피 추천은 1500 토큰

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    const parsed = extractJson(text);
    res.json(parsed);
  } catch (error) {
    console.error('[/api/recipes]', error.message);
    res.status(500).json({ error: '레시피 추천에 실패했습니다.' });
  }
});

// 레시피 상세
app.post('/api/recipe-detail', rateLimiter, async (req, res) => {
  const { recipeName, ingredients = [] } = req.body;

  if (!recipeName) {
    return res.status(400).json({ error: '레시피 이름이 필요합니다.' });
  }

  const prompt = `${recipeName} 레시피의 상세한 조리 방법을 알려주세요.
${ingredients.length > 0 ? `사용 가능한 재료: ${ingredients.join(', ')}` : ''}

다음 JSON 형식으로만 응답해주세요:
{
  "name": "레시피 이름",
  "ingredients": ["재료1 (양)", "재료2 (양)"],
  "steps": ["1단계 설명", "2단계 설명", "3단계 설명"],
  "tips": "요리 팁 또는 주의사항",
  "youtubeQueries": ["검색어1", "검색어2", "검색어3"]
}

youtubeQueries는 이 레시피를 유튜브에서 검색할 때 좋은 한국어 검색어 3개입니다. 예: ["김치찌개 만들기", "김치찌개 황금레시피", "백종원 김치찌개"]`;

  try {
    const response = await callOpenRouter([
      { role: 'system', content: '전문 요리사로서 JSON 형식으로만 응답합니다.' },
      { role: 'user', content: prompt },
    ], 3, 2000); // 레시피 상세는 2000 토큰

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content ?? '';
    const parsed = extractJson(text);

    // youtubeQueries → 인기순(조회수) 정렬 YouTube 검색 URL로 변환
    const queries = Array.isArray(parsed.youtubeQueries) ? parsed.youtubeQueries : [];
    parsed.youtubeLinks = queries.map((q) => ({
      title: q,
      url: `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}&sp=CAM%3D`,
    }));
    delete parsed.youtubeQueries;

    res.json(parsed);
  } catch (error) {
    console.error('[/api/recipe-detail]', error.message);
    res.status(500).json({ error: '레시피 상세 정보를 가져오는데 실패했습니다.' });
  }
});

// Multer 에러 핸들러
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError || err.message.includes('허용')) {
    return res.status(400).json({ error: err.message });
  }
  console.error(err);
  res.status(500).json({ error: '서버 오류가 발생했습니다.' });
});

app.listen(config.port, '0.0.0.0', () => {
  console.log(`서버 실행 중: http://0.0.0.0:${config.port}`);
  console.log(`   Flutter 앱에서 접속 시 컴퓨터의 로컬 IP를 사용하세요.`);
});
