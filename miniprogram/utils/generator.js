// 猫咪生成器 — 纯 JS 移植自 Flutter CatGenerator
const RARITY = ['common', 'rare', 'epic', 'legendary'];
const RARITY_WEIGHTS = [0.60, 0.25, 0.12, 0.03];
const RARITY_INDEX = { common: 0, rare: 1, epic: 2, legendary: 3 };
const CAT_TYPES = ['agility', 'strength', 'endurance'];

const BASE_RANGES = {
  common: { hp: [60, 90], atk: [40, 65], def: [30, 50], spd: [35, 60], crit: [0, 8] },
  rare: { hp: [80, 115], atk: [55, 85], def: [45, 70], spd: [50, 80], crit: [2, 10] },
  epic: { hp: [100, 145], atk: [75, 110], def: [60, 90], spd: [65, 100], crit: [4, 12] },
  legendary: { hp: [130, 180], atk: [100, 140], def: [80, 115], spd: [85, 125], crit: [6, 15] },
};

const NAME_PREFIX = ['咪','喵','团','球','胖','奶','糯','糖','雪','墨','橘','灰','花','豆','丸','布','绒','桃','芝','芒','芋','栗','泡','沫'];
const NAME_SUFFIX = ['咪','喵','崽','仔','酱','球','团','圆','饼','包','丁','卷','糕','冻','贝','宝','萌','呆','憨','乖','猛','跳','跑','睡'];

// ===== 战斗技能池 (20个) =====
const BATTLE_SKILL_POOL = [
  // 攻击技 (12)
  { id: 'scratch', name: '猫爪连击', type: 'attack', power: 40, accuracy: 0.95, description: '连续挥爪攻击', minRarity: 'common' },
  { id: 'bite', name: '利齿撕咬', type: 'attack', power: 55, accuracy: 0.90, description: '锋利的牙齿造成较高伤害', minRarity: 'common' },
  { id: 'pounce', name: '猛扑', type: 'attack', power: 65, accuracy: 0.80, description: '全力猛扑，威力大但命中率稍低', minRarity: 'common' },
  { id: 'tail_whip', name: '尾鞭', type: 'attack', power: 30, accuracy: 1.0, description: '必定命中的尾鞭攻击', minRarity: 'common' },
  { id: 'shadow_strike', name: '暗影突袭', type: 'attack', power: 70, accuracy: 0.75, description: '暗影中突袭，暴击率+20%', minRarity: 'rare' },
  { id: 'fury_swipe', name: '狂暴乱抓', type: 'attack', power: 50, accuracy: 0.85, description: '陷入狂暴连续攻击，自伤10%', minRarity: 'rare', selfDamageRatio: 0.1 },
  { id: 'thunder_claw', name: '雷鸣爪', type: 'attack', power: 85, accuracy: 0.70, description: '带有雷鸣之力的爪击，15%概率麻痹', minRarity: 'epic' },
  { id: 'moonlight_fang', name: '月光牙', type: 'attack', power: 80, accuracy: 0.85, description: '月光加持的撕咬，回复造成伤害的20%', minRarity: 'epic' },
  { id: 'starfall', name: '流星坠落', type: 'attack', power: 95, accuracy: 0.65, description: '召唤流星之力，威力巨大但容易落空', minRarity: 'legendary' },
  { id: 'void_slash', name: '虚空斩', type: 'attack', power: 100, accuracy: 0.80, description: '无视20%防御的虚空斩击', minRarity: 'legendary' },
  { id: 'quick_swipe', name: '快速爪击', type: 'attack', power: 25, accuracy: 1.0, description: '若速度高于对手则伤害翻倍', minRarity: 'common' },
  { id: 'sneak_attack', name: '偷袭', type: 'attack', power: 45, accuracy: 0.95, description: '偷袭对手，暴击率+10%', minRarity: 'common' },

  // 防御技 (4)
  { id: 'curl_up', name: '蜷缩防御', type: 'defense', power: 0, accuracy: 1.0, description: '蜷缩身体，本回合受伤-40%', minRarity: 'common', defMod: 0.4, modDuration: 1 },
  { id: 'catnap', name: '打盹回血', type: 'defense', power: 0, accuracy: 1.0, description: '打个盹恢复15%HP', minRarity: 'common', healRatio: 0.15 },
  { id: 'fur_shield', name: '毛皮护盾', type: 'defense', power: 0, accuracy: 1.0, description: '竖起毛发形成护盾，2回合防御+30%', minRarity: 'rare', defMod: 0.3, modDuration: 2 },
  { id: 'nine_lives', name: '九命护体', type: 'defense', power: 0, accuracy: 1.0, description: '本回合免疫一次致命伤害并回复1HP', minRarity: 'legendary' },

  // 控制技 (4)
  { id: 'glare', name: '瞪视', type: 'control', power: 0, accuracy: 0.85, description: '锐利的目光瞪视对手，下回合ATK-25%', minRarity: 'common', atkMod: -0.25, modDuration: 1 },
  { id: 'hiss', name: '嘶吼威吓', type: 'control', power: 0, accuracy: 0.80, description: '发出嘶嘶声威吓对手，SPD-30%持续2回合', minRarity: 'rare', spdMod: -0.3, modDuration: 2 },
  { id: 'charm', name: '魅惑', type: 'control', power: 0, accuracy: 0.75, description: '卖萌魅惑对手，对方跳过下一回合', minRarity: 'epic' },
  { id: 'hypnosis', name: '催眠凝视', type: 'control', power: 0, accuracy: 0.60, description: '用深邃的眼神催眠对手，ATK-40%、DEF-20%', minRarity: 'epic', atkMod: -0.4, defMod: -0.2, modDuration: 2 },
];

// ===== 生活技能池 (10个) =====
const LIFE_SKILL_POOL = [
  { id: 'gold_nose', name: '寻宝嗅觉', effect: 'goldBonus', value: 0.15, description: '探索时额外获得15%金币', minRarity: 'common' },
  { id: 'lucky_star', name: '幸运之星', effect: 'itemDrop', value: 0.10, description: '触发路人赠送道具概率+10%', minRarity: 'common' },
  { id: 'smart_brain', name: '聪慧过人', effect: 'expBoost', value: 0.10, description: '战斗获得经验+10%', minRarity: 'common' },
  { id: 'cat_magnet', name: '猫缘深厚', effect: 'encounterRate', value: 0.05, description: '遇到稀有及以上猫咪概率+5%', minRarity: 'rare' },
  { id: 'quick_heal', name: '快速恢复', effect: 'healAfterBattle', value: 0.20, description: '战斗结束后恢复20%HP', minRarity: 'rare' },
  { id: 'energetic', name: '精力充沛', effect: 'staminaBoost', value: 2, description: '每日可对战次数+2', minRarity: 'common' },
  { id: 'radar_sense', name: '敏锐感知', effect: 'nearbyRadar', value: 0.30, description: '地图上猫咪探测范围扩大30%', minRarity: 'epic' },
  { id: 'charm_boost', name: '魅力四射', effect: 'charmBoost', value: 0.08, description: '捕捉成功率+8%', minRarity: 'rare' },
  { id: 'regen', name: '生命恢复', effect: 'hpRegen', value: 0.02, description: '每30秒自动恢复2%HP', minRarity: 'epic' },
  { id: 'crit_master', name: '致命一击', effect: 'critBoost', value: 0.05, description: '暴击率额外+5%', minRarity: 'legendary' },
];

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

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function rollSkills(rarity) {
  const rarityIdx = RARITY_INDEX[rarity];

  // 战斗技能数量
  let battleCount = 1;
  if (rarity === 'rare' || rarity === 'epic') battleCount++;
  if (rarity === 'legendary') battleCount += 2;
  if (Math.random() < 0.1) battleCount++;

  const available = BATTLE_SKILL_POOL.filter(s => RARITY_INDEX[s.minRarity] <= rarityIdx);
  const shuffled = shuffle(available);
  const battleSkills = shuffled.slice(0, Math.min(battleCount, shuffled.length));

  // 生活技能 1~2 个
  let lifeCount = 1 + (Math.random() < 0.3 ? 1 : 0);
  const availableLife = LIFE_SKILL_POOL.filter(s => RARITY_INDEX[s.minRarity] <= rarityIdx);
  const shuffledLife = shuffle(availableLife);
  const lifeSkills = shuffledLife.slice(0, Math.min(lifeCount, shuffledLife.length));

  return { battleSkills, lifeSkills };
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

    const skills = rollSkills(rarity);

    return {
      id: options.id || `cat_${Date.now()}`,
      name, rarity, type,
      baseHp, baseAtk, baseDef, baseSpd, baseCrit,
      cp,
      level: 1, exp: 0,
      battleSkills: skills.battleSkills,
      lifeSkills: skills.lifeSkills,
      imageUrl: options.imageUrl || '',
      cardImageUrl: options.cardImageUrl || '',
      captureLocation: options.captureLocation || { latitude: 0, longitude: 0 },
      capturedAt: new Date().toISOString(),
    };
  },
};
