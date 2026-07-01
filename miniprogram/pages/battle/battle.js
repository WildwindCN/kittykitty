const api = require('../../utils/api');
const generator = require('../../utils/generator');

// 简易对战引擎 (移植自 Flutter BattleEngine)
function simulateBattle(myCat, opponent) {
  const maxRounds = 10;
  const dodgeChance = 0.05;
  let myHp = myCat.baseHp;
  let oppHp = opponent.baseHp;
  const events = [];

  for (let r = 1; r <= maxRounds; r++) {
    // 我方攻击
    if (myHp > 0 && oppHp > 0) {
      const atk = (myCat.baseAtk || 50);
      const def = (opponent.baseDef || 40);
      let dmg = Math.round(atk * (randomSkillPower() / 100) * (1 - def / (def + 200)));
      dmg = Math.max(1, Math.round(dmg * (0.9 + Math.random() * 0.2)));
      if (Math.random() < dodgeChance) {
        events.push({ round: r, text: `${myCat.name} 的攻击被闪避！`, color: '#888' });
      } else {
        oppHp = Math.max(0, oppHp - dmg);
        const crit = Math.random() < (myCat.baseCrit || 0.05);
        events.push({ round: r, text: `${myCat.name} 攻击 → ${dmg}伤害`, color: crit ? '#FFD700' : '#FFA726' });
      }
    }

    // 对手攻击
    if (myHp > 0 && oppHp > 0) {
      const atk = (opponent.baseAtk || 45);
      const def = (myCat.baseDef || 40);
      let dmg = Math.round(atk * (randomSkillPower() / 100) * (1 - def / (def + 200)));
      dmg = Math.max(1, Math.round(dmg * (0.9 + Math.random() * 0.2)));
      if (Math.random() < dodgeChance) {
        events.push({ round: r, text: `${opponent.name} 的攻击被闪避！`, color: '#888' });
      } else {
        myHp = Math.max(0, myHp - dmg);
        events.push({ round: r, text: `${opponent.name} 攻击 → ${dmg}伤害`, color: '#FF5252' });
      }
    }

    if (myHp <= 0 || oppHp <= 0) {
      const winner = myHp > oppHp ? myCat.name : opponent.name;
      return { events, myHp, oppHp, maxHp: myCat.baseHp, oppMaxHp: opponent.baseHp, winner, rounds: r, won: myHp > oppHp };
    }
  }

  // 超时判 HP 百分比
  const myPct = myHp / myCat.baseHp, oppPct = oppHp / opponent.baseHp;
  const won = myPct >= oppPct;
  return { events, myHp, oppHp, maxHp: myCat.baseHp, oppMaxHp: opponent.baseHp, winner: won ? myCat.name : opponent.name, rounds: maxRounds, won };
}

function randomSkillPower() { return 40 + Math.floor(Math.random() * 60); }

Page({
  data: { myCat: null, opponent: null, myHp: 0, oppHp: 0, activeActor: '', currentRound: 0, maxRounds: 10, progress: 0, log: [], finished: false, won: false, winner: '', rounds: 0, myHpPct: 100, oppHpPct: 100, myHpColor: '#4CAF50', oppHpColor: '#4CAF50' },

  onLoad(options) {
    if (options.id) this.startBattle(options.id);
  },

  async startBattle(catId) {
    try {
      const res = await api.getMyCats();
      if (res.code === 200) {
        const myCat = (res.data || []).find(c => c._id === catId);
        if (myCat) {
          const opponent = generator.generateCat();
          const result = simulateBattle(myCat, opponent);
          this.setData({ myCat, opponent, maxRounds: 10 });
          this.animate(result);
          return;
        }
      }
    } catch (_) {}
    wx.showToast({ title: '加载失败', icon: 'none' });
  },

  animate(result) {
    const { events, myHp, oppHp, maxHp, oppMaxHp, winner, rounds, won } = result;
    let i = 0;

    const step = () => {
      if (i >= events.length) {
        this.setData({
          finished: true, won, winner, rounds,
          myHp, oppHp,
          myHpPct: Math.round(myHp / maxHp * 100),
          oppHpPct: Math.round(oppHp / oppMaxHp * 100),
          myHpColor: myHp / maxHp > 0.5 ? '#4CAF50' : myHp / maxHp > 0.25 ? '#FFA726' : '#F44336',
          oppHpColor: oppHp / oppMaxHp > 0.5 ? '#4CAF50' : oppHp / oppMaxHp > 0.25 ? '#FFA726' : '#F44336',
          progress: 100,
        });
        return;
      }

      const e = events[i];
      // Calculate intermediate HP
      let curMyHp = maxHp, curOppHp = oppMaxHp;
      for (let j = 0; j <= i; j++) {
        const ev = events[j];
        if (ev.text.includes('对手') || ev.text.includes(winner)) {
          // Simplified: track based on event content
        }
      }

      this.setData({
        activeActor: e.text.includes(this.data.myCat.name) ? this.data.myCat._id : this.data.opponent.id,
        currentRound: e.round,
        log: [...this.data.log, e],
        progress: Math.round((i + 1) / events.length * 100),
      });

      i++;
      setTimeout(step, 1200);
    };

    step();
  },

  goBack() { wx.switchTab({ url: '/pages/collection/collection' }); },
});
