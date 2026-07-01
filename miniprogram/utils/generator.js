// 猫咪生成器 — 纯 JS 移植自 Flutter CatGenerator
const RARITY = ['common', 'rare', 'epic', 'legendary'];
const RARITY_WEIGHTS = [0.60, 0.25, 0.12, 0.03];
const CAT_TYPES = ['agility', 'strength', 'endurance'];

const BASE_RANGES = {
  common: { hp: [60, 90], atk: [40, 65], def: [30, 50], spd: [35, 60], crit: [0, 8] },
  rare: { hp: [80, 115], atk: [55, 85], def: [45, 70], spd: [50, 80], crit: [2, 10] },
  epic: { hp: [100, 145], atk: [75, 110], def: [60, 90], spd: [65, 100], crit: [4, 12] },
  legendary: { hp: [130, 180], atk: [100, 140], def: [80, 115], spd: [85, 125], crit: [6, 15] },
};

const NAME_PREFIX = ['咪','喵','团','球','胖','奶','糯','糖','雪','墨','橘','灰','花','豆','丸','布','绒','桃','芝','芒','芋','栗','泡','沫'];
const NAME_SUFFIX = ['咪','喵','崽','仔','酱','球','团','圆','饼','包','丁','卷','糕','冻','贝','宝','萌','呆','憨','乖','猛','跳','跑','睡'];

function rand(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function rollStat(min, max) {
  const mid = (min + max) / 2;
  const stdDev = (max - min) / 6;
  const u1 = Math.random(); const u2 = Math.random();
  const normal = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  let val = Math.round(mid + normal * stdDev);
  return Math.max(min, Math.min(max, val));
}

function rollRarity() {
  const r = Math.random();
  let c = 0;
  for (let i = 0; i < RARITY.length; i++) {
    c += RARITY_WEIGHTS[i];
    if (r <= c) return RARITY[i];
  }
  return 'common';
}

function generateName() {
  return NAME_PREFIX[Math.floor(Math.random() * NAME_PREFIX.length)] +
         NAME_SUFFIX[Math.floor(Math.random() * NAME_SUFFIX.length)];
}

module.exports = {
  generateCat(options = {}) {
    const rarity = options.rarity || rollRarity();
    const type = options.type || CAT_TYPES[Math.floor(Math.random() * CAT_TYPES.length)];
    const ranges = BASE_RANGES[rarity];
    const name = options.name || generateName();

    const baseHp = rollStat(ranges.hp[0], ranges.hp[1]);
    const baseAtk = rollStat(ranges.atk[0], ranges.atk[1]);
    const baseDef = rollStat(ranges.def[0], ranges.def[1]);
    const baseSpd = rollStat(ranges.spd[0], ranges.spd[1]);
    const baseCrit = (Math.random() * (ranges.crit[1] - ranges.crit[0]) + ranges.crit[0]) / 100;

    const rawCp = baseHp * 0.4 + baseAtk * 1.2 + baseDef * 0.8 + baseSpd * 0.6;
    const cpMultiplier = { common: 1.0, rare: 1.3, epic: 1.7, legendary: 2.2 }[rarity];
    const cp = Math.round(rawCp * cpMultiplier);

    return {
      id: options.id || `cat_${Date.now()}`,
      name, rarity, type,
      baseHp, baseAtk, baseDef, baseSpd, baseCrit,
      cp,
      level: 1, exp: 0,
      battleSkills: [], lifeSkills: [],
      imageUrl: options.imageUrl || '',
      cardImageUrl: options.cardImageUrl || '',
      captureLocation: options.captureLocation || { latitude: 0, longitude: 0 },
      capturedAt: new Date().toISOString(),
    };
  },
};
