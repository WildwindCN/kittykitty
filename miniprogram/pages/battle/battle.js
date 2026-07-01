const api = require('../../utils/api');
const generator = require('../../utils/generator');
const sha256 = require('../../utils/sha256');

function pickSkill(cat) {
  const skills = cat.battleSkills;
  if (!skills || skills.length === 0) return null;
  // 加权随机：高威力技能概率更低
  const totalWeight = skills.reduce((s, sk) => s + (100 - (sk.power || 0)), 0) || skills.length;
  let roll = Math.random() * totalWeight;
  for (const sk of skills) {
    roll -= (100 - (sk.power || 0));
    if (roll <= 0) return sk;
  }
  return skills[skills.length - 1];
}

Page({
  data: {
    myCat: null, opponent: null,
    myHp: 0, oppHp: 0,
    myMaxHp: 0, oppMaxHp: 0,
    myHpPct: 100, oppHpPct: 100,
    myHpColor: '#4CAF50', oppHpColor: '#4CAF50',
    activeActor: '', currentRound: 0,
    progress: 0, log: [],
    finished: false, won: false,
    winner: '', rounds: 0,
    submitting: false,
  },

  onLoad(options) {
    if (options.id) this.startBattle(options.id);
  },

  async startBattle(catId) {
    try {
      const res = await api.getMyCats();
      if (res.code !== 200 || !res.data) throw new Error('load failed');

      const myCat = (res.data || []).find(c => c._id === catId || c.id === catId);
      if (!myCat) throw new Error('cat not found');

      // 优先从图鉴中选对手（排除自己），否则生成野猫
      const others = res.data.filter(c => (c._id || c.id) !== catId);
      const opponent = others.length > 0
        ? others[Math.floor(Math.random() * others.length)]
        : generator.generateCat();

      const myMaxHp = myCat.baseHp || 80;
      const oppMaxHp = opponent.baseHp || 80;

      this.setData({
        myCat, opponent,
        myMaxHp, oppMaxHp,
        myHp: myMaxHp, oppHp: oppMaxHp,
        myHpPct: 100, oppHpPct: 100,
        myHpColor: '#4CAF50', oppHpColor: '#4CAF50',
      });

      this.runBattle(myCat, opponent);
    } catch (e) {
      wx.showToast({ title: '加载失败', icon: 'none' });
    }
  },

  runBattle(myCat, opponent) {
    const maxRounds = 10;
    const dodgeChance = 0.05;
    const events = [];
    let myHp = myCat.baseHp || 80;
    let oppHp = opponent.baseHp || 80;
    const myMaxHp = myHp;
    const oppMaxHp = oppHp;

    // SPD 决定先手
    const mySpd = myCat.baseSpd || 50;
    const oppSpd = opponent.baseSpd || 50;
    const iGoFirst = mySpd >= oppSpd;

    for (let r = 1; r <= maxRounds; r++) {
      const attackers = iGoFirst ? ['me', 'opp'] : ['opp', 'me'];

      for (const who of attackers) {
        if (myHp <= 0 || oppHp <= 0) break;

        const attacker = who === 'me' ? myCat : opponent;
        const atk = attacker.baseAtk || 50;
        const defenderDef = who === 'me' ? (opponent.baseDef || 40) : (myCat.baseDef || 40);
        const attackerName = attacker.name;
        const defenderName = who === 'me' ? opponent.name : myCat.name;

        // 选择技能
        const skill = pickSkill(attacker);
        const skillPower = skill ? skill.power : 50;
        const skillName = skill ? skill.name : '普通攻击';
        let skillAcc = skill ? skill.accuracy : 1.0;

        // 命中判定
        if (Math.random() > skillAcc) {
          events.push({
            round: r, text: `${attackerName} 的 ${skillName} 未命中！`, color: '#888', attacker: who, dmg: 0,
            skillName,
          });
          continue;
        }

        let dmg = Math.round(atk * (skillPower / 70) * (1 - defenderDef / (defenderDef + 200)));
        dmg = Math.max(1, Math.round(dmg * (0.9 + Math.random() * 0.2)));

        if (Math.random() < dodgeChance) {
          events.push({ round: r, text: `${attackerName} 的 ${skillName} 被闪避！`, color: '#888', attacker: who, dmg: 0, skillName });
        } else {
          const crit = Math.random() < ((attacker.baseCrit || 0.05) + (skill && skill.id === 'shadow_strike' ? 0.2 : 0) + (skill && skill.id === 'sneak_attack' ? 0.1 : 0));
          const finalDmg = crit ? Math.round(dmg * 1.6) : dmg;
          if (who === 'me') {
            oppHp = Math.max(0, oppHp - finalDmg);
          } else {
            myHp = Math.max(0, myHp - finalDmg);
          }
          events.push({
            round: r,
            text: `${attackerName} 使用 ${skillName} → ${finalDmg}${crit ? ' 暴击!' : ''}`,
            color: crit ? '#FFD700' : (who === 'me' ? '#FFA726' : '#FF5252'),
            attacker: who, dmg: finalDmg,
            skillName,
            myHpAfter: myHp, oppHpAfter: oppHp,
          });
        }
      }

      if (myHp <= 0 || oppHp <= 0) break;
    }

    // 超时按 HP 百分比判胜负
    let won;
    if (myHp <= 0) won = false;
    else if (oppHp <= 0) won = true;
    else won = (myHp / myMaxHp) >= (oppHp / oppMaxHp);

    const winner = won ? myCat.name : opponent.name;
    const result = {
      events, myHp, oppHp, myMaxHp, oppMaxHp,
      winner, rounds: events.length > 0 ? events[events.length - 1].round : 1, won,
    };

    this.animateResult(result);
    this.submitResult(myCat, opponent, result);
  },

  animateResult(result) {
    const { events, myMaxHp, oppMaxHp, won, winner, rounds } = result;
    let i = 0;
    let curMyHp = myMaxHp;
    let curOppHp = oppMaxHp;

    const step = () => {
      if (i >= events.length) {
        const myHpPct = Math.round(curMyHp / myMaxHp * 100);
        const oppHpPct = Math.round(curOppHp / oppMaxHp * 100);
        this.setData({
          finished: true, won, winner, rounds,
          myHp: curMyHp, oppHp: curOppHp,
          myHpPct, oppHpPct,
          myHpColor: myHpPct > 50 ? '#4CAF50' : myHpPct > 25 ? '#FFA726' : '#F44336',
          oppHpColor: oppHpPct > 50 ? '#4CAF50' : oppHpPct > 25 ? '#FFA726' : '#F44336',
          progress: 100, activeActor: '',
        });
        return;
      }

      const e = events[i];
      // 应用本事件的血量变化
      if (e.myHpAfter !== undefined) curMyHp = e.myHpAfter;
      if (e.oppHpAfter !== undefined) curOppHp = e.oppHpAfter;

      const myHpPct = Math.round(curMyHp / myMaxHp * 100);
      const oppHpPct = Math.round(curOppHp / oppMaxHp * 100);

      this.setData({
        activeActor: e.attacker === 'me' ? (this.data.myCat && this.data.myCat._id) : (this.data.opponent && this.data.opponent.id),
        currentRound: e.round,
        myHp: curMyHp, oppHp: curOppHp,
        myHpPct, oppHpPct,
        myHpColor: myHpPct > 50 ? '#4CAF50' : myHpPct > 25 ? '#FFA726' : '#F44336',
        oppHpColor: oppHpPct > 50 ? '#4CAF50' : oppHpPct > 25 ? '#FFA726' : '#F44336',
        log: [...this.data.log, e],
        progress: Math.round((i + 1) / events.length * 100),
      });

      i++;
      setTimeout(step, 1200);
    };

    step();
  },

  async submitResult(myCat, opponent, result) {
    try {
      const seed = Date.now() % 10000;
      const attackerId = myCat._id || myCat.id;
      const defenderId = opponent._id || opponent.id;
      const { won, rounds } = result;
      const raw = `${attackerId}|${defenderId}|${rounds}|${seed}|${won ? 1 : 0}`;
      const battleHash = sha256(raw).substring(0, 16);
      await api.submitBattle({ attackerId, defenderId, won, rounds, seed, battleHash });
    } catch (_) {}
  },

  goBack() { wx.switchTab({ url: '/pages/collection/collection' }); },
});
