// Use the release publication time, with a bundled timestamp for offline visits.
(() => {
  const time = document.getElementById('last-updated');
  let updated = Date.parse(time.dateTime);
  function refresh() {
    const minutes = Math.max(0, Math.floor((Date.now() - updated) / 60000));
    const [count, unit] = minutes >= 1440 ? [Math.floor(minutes / 1440), 'day']
      : minutes >= 60 ? [Math.floor(minutes / 60), 'hour'] : [minutes, 'minute'];
    time.textContent = `${count} ${unit}${count === 1 ? '' : 's'} ago`;
    time.title = new Date(updated).toLocaleString();
  }
  refresh();
  setInterval(refresh, 60000);
  fetch('https://api.github.com/repos/GM-King/GratzGuild/releases/tags/v1.4.1')
    .then(response => { if (!response.ok) throw new Error('Release unavailable'); return response.json(); })
    .then(release => {
      const published = Date.parse(release.published_at);
      if (!Number.isFinite(published)) return;
      updated = published;
      time.dateTime = new Date(updated).toISOString();
      refresh();
    })
    .catch(() => {}); // Keep the bundled date if GitHub is unavailable or rate limited.
})();

(() => {
const lines = ["Mrrgl! You make this guild brighter!", "Gratz, champion. That level looks good on you!", "Big ding energy. Absolutely legendary.", "You showed up. You levelled up. You nailed it!", "Your guild is lucky to have you!", "Another level? Save some greatness for us!", "A gold star and a very enthusiastic mrrgl!", "You are doing better than you think!", "For the Horde. For your excellent self!", "That was all you, champion. Well done!", "Your effort deserves a whole bag of confetti!", "Tiny murloc. Enormous respect.", "Gratez! Even my fins are applauding!", "BIG DINGUS! Big achievement!", "One more step towards your next great adventure!", "You bring the good vibes. I bring the confetti!", "A proper guildmate. A proper legend.", "Keep going. Your next win is waiting!", "Every little victory counts. This one is yours!", "Ten out of ten. Would cheer for you again!", "You have earned a very happy murloc dance!", "That is some top-tier adventuring!", "Mrrgl-approved. Guildmate-certified.", "Gratz! Take a moment to enjoy this one!"];
let bag = [], last; const bubble = document.getElementById('praise'), mascot = document.getElementById('murloc'), confetti = document.getElementById('confetti'), motion = matchMedia('(prefers-reduced-motion: reduce)');
mascot.addEventListener('click', () => {
 if (!bag.length) { bag = [...lines]; for (let i=bag.length-1;i>0;i--) { const j=Math.floor(Math.random()*(i+1)); [bag[i],bag[j]]=[bag[j],bag[i]]; } if(bag[bag.length-1]===last) [bag[0],bag[bag.length-1]]=[bag[bag.length-1],bag[0]]; }
 last=bag.pop(); bubble.textContent=last; confetti.replaceChildren(); mascot.classList.remove('bounce');
 if(!motion.matches){ void mascot.offsetWidth; mascot.classList.add('bounce'); for(let i=0;i<16;i++){const bit=document.createElement('i');bit.style.left=(i*6)+'%';bit.style.background=['#edb940','#df7847','#43a69b'][i%3];bit.style.animationDelay=(i%4)*.025+'s';bit.addEventListener('animationend',()=>bit.remove(),{once:true});confetti.append(bit);}}
});
motion.addEventListener('change',()=>{if(motion.matches){confetti.replaceChildren();mascot.classList.remove('bounce');}});
const dialog=document.getElementById('preview'), large=dialog.querySelector('img');
if(typeof dialog.showModal==='function') document.querySelectorAll('[data-preview]').forEach(link=>link.addEventListener('click',e=>{if(e.ctrlKey||e.metaKey||e.shiftKey||e.altKey)return;e.preventDefault();large.src=link.href;large.alt=link.querySelector('img').alt;dialog.showModal();}));
document.getElementById('close').addEventListener('click',()=>dialog.close());
})();
