require('dotenv').config();
const zlib = require('zlib');

const API_KEY = process.env.OPENROUTER_API_KEY;
const MODEL = 'nvidia/nemotron-nano-12b-v2-vl:free';
const BASE_URL = 'https://openrouter.ai/api/v1/chat/completions';

async function callAPI(messages) {
  const response = await fetch(BASE_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'http://localhost:3000',
      'X-Title': 'Fridge Recipe App Test',
    },
    body: JSON.stringify({ model: MODEL, messages }),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(JSON.stringify(data.error ?? data));
  return data.choices?.[0]?.message?.content ?? '';
}

// ── 테스트 1: 텍스트 인식
async function testText() {
  console.log('\n========================================');
  console.log('테스트 1: 텍스트 인식');
  console.log('========================================');
  console.log('프롬프트: "냉장고에 계란, 우유, 당근이 있을 때 만들 수 있는 간단한 요리 1가지만 알려줘"');
  const result = await callAPI([
    { role: 'user', content: '냉장고에 계란, 우유, 당근이 있을 때 만들 수 있는 간단한 요리 1가지만 알려줘' },
  ]);
  console.log('\n응답:');
  console.log(result);
}

// PNG CRC32 계산
function crc32(buf) {
  const table = [];
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let j = 0; j < 8; j++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[i] = c;
  }
  let crc = 0xffffffff;
  for (const b of buf) crc = table[(crc ^ b) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

// Node.js 내장 모듈로 100x100 주황색 PNG 생성
function createOrangePNG() {
  const W = 100, H = 100;
  const raw = Buffer.alloc(H * (1 + W * 3));
  for (let y = 0; y < H; y++) {
    raw[y * (1 + W * 3)] = 0;
    for (let x = 0; x < W; x++) {
      const i = y * (1 + W * 3) + 1 + x * 3;
      raw[i] = 255; raw[i+1] = 107; raw[i+2] = 53; // #FF6B35
    }
  }
  const compressed = zlib.deflateSync(raw);

  const writeChunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const typeB = Buffer.from(type);
    const crcB = Buffer.alloc(4);
    crcB.writeUInt32BE(crc32(Buffer.concat([typeB, data])));
    return Buffer.concat([len, typeB, data, crcB]);
  };

  const ihdrData = Buffer.alloc(13);
  ihdrData.writeUInt32BE(W, 0); ihdrData.writeUInt32BE(H, 4);
  ihdrData[8]=8; ihdrData[9]=2; ihdrData[10]=0; ihdrData[11]=0; ihdrData[12]=0;

  const sig = Buffer.from([137,80,78,71,13,10,26,10]);
  const iend = writeChunk('IEND', Buffer.alloc(0));
  return Buffer.concat([sig, writeChunk('IHDR', ihdrData), writeChunk('IDAT', compressed), iend]);
}

// ── 테스트 2: 이미지 인식 (Node.js로 PNG 생성 후 base64 전달)
async function testImage() {
  console.log('\n========================================');
  console.log('테스트 2: 이미지 인식 (base64 방식)');
  console.log('========================================');

  const pngBuffer = createOrangePNG();
  const base64 = pngBuffer.toString('base64');
  console.log(`테스트 PNG 생성: 100x100px, ${pngBuffer.length} bytes → base64로 API 전달 중...`);

  const result = await callAPI([
    {
      role: 'user',
      content: [
        {
          type: 'image_url',
          image_url: { url: `data:image/png;base64,${base64}` },
        },
        {
          type: 'text',
          text: '이 이미지에서 무엇이 보이는지 한국어로 설명해줘.',
        },
      ],
    },
  ]);
  console.log('\n응답:');
  console.log(result);
}

// ── 실행
(async () => {
  console.log(`모델: ${MODEL}`);
  console.log(`API 키: ${API_KEY ? API_KEY.substring(0, 15) + '...' : '없음'}`);

  if (!API_KEY) {
    console.error('ERROR: OPENROUTER_API_KEY가 .env에 없습니다.');
    process.exit(1);
  }

  try {
    await testText();
  } catch (e) {
    console.error('텍스트 테스트 실패:', e.message);
  }

  try {
    await testImage();
  } catch (e) {
    console.error('이미지 테스트 실패:', e.message);
  }

  console.log('\n========================================');
  console.log('테스트 완료');
  console.log('========================================');
})();
