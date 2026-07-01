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

    // 属性修正追踪 { atkMul, defMul, spdMul, turns }
    let myMods = { atkMul: 1.0, defMul: 1.0, spdMul: 1.0, turns: 0 };
    let oppMods = { atkMul: 1.0, defMul: 1.0, spdMul: 1.0, turns: 0 };
    let mySkipNext = false;
    let oppSkipNext = false;
    let myNineLives = false;
    let oppNineLives = false;

    function getMods(who) { return who === 'me' ? myMods : oppMods; }
    function setMods(who, m) { if (who === 'me') myMods = m; else oppMods = m; }
    function skipNext(who) { return who === 'me' ? mySkipNext : oppSkipNext; }
    function setSkip(who, v) { if (who === 'me') mySkipNext = v; else oppSkipNext = v; }
    function hasNineLives(who) { return who === 'me' ? myNineLives : oppNineLives; }
    function useNineLives(who) { if (who === 'me') { myNineLives = false; myHp = 1; } else { oppNineLives = false; oppHp = 1; } }

    const mySpd = myCat.baseSpd || 50;
    const oppSpd = opponent.baseSpd || 50;
    const iGoFirst = mySpd >= oppSpd;

    for (let r = 1; r <= maxRounds; r++) {
      // 衰减修正回合
      if (myMods.turns > 0) { myMods.turns--; if (myMods.turns === 0) myMods = { atkMul: 1.0, defMul: 1.0, spdMul: 1.0, turns: 0 }; }
      if (oppMods.turns > 0) { oppMods.turns--; if (oppMods.turns === 0) oppMods = { atkMul: 1.0, defMul: 1.0, spdMul: 1.0, turns: 0 }; }

      const attackers = iGoFirst ? ['me', 'opp'] : ['opp', 'me'];

      for (const who of attackers) {
        if (myHp <= 0 || oppHp <= 0) break;

        // 跳过回合（魅惑效果）
        if (skipNext(who)) {
          const name = who === 'me' ? myCat.name : opponent.name;
          events.push({ round: r, text: `${name} 被魅惑，跳过回合！`, color: '#CE93D8', attacker: who, dmg: 0, skillName: '魅惑' });
          setSkip(who, false);
          continue;
        }

        const attacker = who === 'me' ? myCat : opponent;
        const defender = who === 'me' ? opponent : myCat;
        const defName = who === 'me' ? opponent.name : myCat.name;

        const atk = attacker.baseAtk || 50;
        const defenderDef = who === 'me' ? (opponent.baseDef || 40) : (myCat.baseDef || 40);
        const attackerName = attacker.name;
        const mods = getMods(who);
        const oppModsData = getMods(who === 'me' ? 'opp' : 'me');

        const skill = pickSkill(attacker);
        const skillType = skill ? skill.type : 'attack';
        const skillName = skill ? skill.name : '普通攻击';
        const skillPower = skill ? skill.power : 50;
        const skillAcc = skill ? skill.accuracy : 1.0;

        // === 防御技 / 控制技（对自己或对手的属性修正）===
        if (skill && skillType === 'defense') {
          if (skill.id === 'curl_up') {
            setMods(who, { atkMul: mods.atkMul, defMul: mods.defMul + 0.4, spdMul: mods.spdMul, turns: Math.max(mods.turns, 1) });
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，防御+40%！`, color: '#42A5F5', attacker: who, dmg: 0, skillName });
          } else if (skill.id === 'catnap') {
            const heal = Math.round(myMaxHp * (skill.healRatio || 0.15));
            if (who === 'me') myHp = Math.min(myMaxHp, myHp + heal);
            else oppHp = Math.min(oppMaxHp, oppHp + heal);
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，回复 ${heal} HP！`, color: '#4CAF50', attacker: who, dmg: 0, skillName, myHpAfter: myHp, oppHpAfter: oppHp });
          } else if (skill.id === 'fur_shield') {
            setMods(who, { atkMul: mods.atkMul, defMul: mods.defMul + 0.3, spdMul: mods.spdMul, turns: Math.max(mods.turns, 2) });
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，防御+30%(2回合)！`, color: '#42A5F5', attacker: who, dmg: 0, skillName });
          } else if (skill.id === 'nine_lives') {
            if (who === 'me') myNineLives = true; else oppNineLives = true;
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，获得一次免死！`, color: '#FFD700', attacker: who, dmg: 0, skillName });
          }
          continue;
        }

        if (skill && skillType === 'control') {
          if (skill.id === 'glare') {
            const target = who === 'me' ? 'opp' : 'me';
            const tMods = getMods(target);
            setMods(target, { atkMul: tMods.atkMul - 0.25, defMul: tMods.defMul, spdMul: tMods.spdMul, turns: Math.max(tMods.turns, 1) });
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，${defName} ATK-25%！`, color: '#AB47BC', attacker: who, dmg: 0, skillName });
          } else if (skill.id === 'hiss') {
            const target = who === 'me' ? 'opp' : 'me';
            const tMods = getMods(target);
            setMods(target, { atkMul: tMods.atkMul, defMul: tMods.defMul, spdMul: tMods.spdMul - 0.3, turns: Math.max(tMods.turns, 2) });
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，${defName} SPD-30%(2回合)！`, color: '#AB47BC', attacker: who, dmg: 0, skillName });
          } else if (skill.id === 'charm') {
            const target = who === 'me' ? 'opp' : 'me';
            setSkip(target, true);
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，${defName} 下回合跳过！`, color: '#CE93D8', attacker: who, dmg: 0, skillName });
          } else if (skill.id === 'hypnosis') {
            const target = who === 'me' ? 'opp' : 'me';
            const tMods = getMods(target);
            setMods(target, { atkMul: tMods.atkMul - 0.4, defMul: tMods.defMul - 0.2, spdMul: tMods.spdMul, turns: Math.max(tMods.turns, 2) });
            events.push({ round: r, text: `${attackerName} 使用 ${skillName}，${defName} ATK-40% DEF-20%！`, color: '#AB47BC', attacker: who, dmg: 0, skillName });
          }
          continue;
        }

        // === 攻击技 ===
        if (Math.random() > skillAcc) {
          events.push({ round: r, text: `${attackerName} 的 ${skillName} 未命中！`, color: '#888', attacker: who, dmg: 0, skillName });
          continue;
        }

        const effAtk = atk * mods.atkMul;
        const effDef = defenderDef * oppModsData.defMul;
        let dmg = Math.round(effAtk * (skillPower / 70) * (1 - effDef / (effDef + 200)));
        dmg = Math.max(1, Math.round(dmg * (0.9 + Math.random() * 0.2)));

        if (Math.random() < dodgeChance) {
          events.push({ round: r, text: `${attackerName} 的 ${skillName} 被闪避！`, color: '#888', attacker: who, dmg: 0, skillName });
        } else {
          const critBonus = (skill && skill.id === 'shadow_strike' ? 0.2 : 0) + (skill && skill.id === 'sneak_attack' ? 0.1 : 0);
          const crit = Math.random() < ((attacker.baseCrit || 0.05) + critBonus);
          let finalDmg = crit ? Math.round(dmg * 1.6) : dmg;
          if (who === 'me') {
            oppHp = Math.max(0, oppHp - finalDmg);
          } else {
            myHp = Math.max(0, myHp - finalDmg);
          }

          // 九命护体：免疫致命伤害
          if (who === 'me' && oppHp <= 0 && hasNineLives('opp')) {
            useNineLives('opp');
            finalDmg = 0;
            events.push({ round: r, text: `${defName} 触发九命护体，免疫致命伤害！`, color: '#FFD700', attacker: who, dmg: 0, skillName, myHpAfter: myHp, oppHpAfter: oppHp });
            continue;
          } else if (who === 'opp' && myHp <= 0 && hasNineLives('me')) {
            useNineLives('me');
            finalDmg = 0;
            events.push({ round: r, text: `${defName} 触发九命护体，免疫致命伤害！`, color: '#FFD700', attacker: who, dmg: 0, skillName, myHpAfter: myHp, oppHpAfter: oppHp });
            continue;
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
        activeActor: e.attacker === 'me' ? (this.data.myCat && this.data.myCat._id) : (this.data.opponent && (this.data.opponent._id || this.data.opponent.id)),
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
