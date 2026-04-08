require('dotenv').config();

const config = {
  port: process.env.PORT || 3000,
  openrouterApiKey: process.env.OPENROUTER_API_KEY,
};

if (!config.openrouterApiKey) {
  console.error('ERROR: OPENROUTER_API_KEY 환경 변수가 설정되지 않았습니다.');
  process.exit(1);
}

module.exports = { config };
