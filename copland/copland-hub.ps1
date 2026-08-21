# COPLAND OS -- Hub-Generator v2 (kommandozentrale)
# baut hub.html: gauges (limits), balance-donut, aktivitaets-heatmap,
# lebens-graph (canvas, force-directed), commit/werkstatt-timeline,
# bereiche/projekte, offene punkte, skills. alles inline, kein internet.
# aufruf: [h] -> [b] im launcher. 40_private: nur ordnernamen (ausser assistent).

$ErrorActionPreference = 'SilentlyContinue'
if (-not $env:USERPROFILE) { $env:USERPROFILE = $HOME }
$OD  = if ($env:COPLAND_ROOT) { $env:COPLAND_ROOT } else { Join-Path $env:USERPROFILE 'OneDrive' }
$out = "$OD\00_System\copland\hub.html"

$areas = @(
    @{ name = 'uni'; dir = '10_uni' }, @{ name = 'work'; dir = '20_work' },
    @{ name = 'venture'; dir = '30_venture' }, @{ name = 'private'; dir = '40_private' },
    @{ name = 'career'; dir = '50_career' }, @{ name = 'system'; dir = '00_System' }
)

# --- limits aus den panel-caches ---
$limits = @{ five = $null; seven = $null; scoped = @() }
$lc = Get-Content "$env:LOCALAPPDATA\copland-limits.json" -Raw | ConvertFrom-Json
if ($lc) {
    if ($null -ne $lc.five_hour.used_percentage) { $limits.five = [math]::Round($lc.five_hour.used_percentage) }
    if ($null -ne $lc.seven_day.used_percentage) { $limits.seven = [math]::Round($lc.seven_day.used_percentage) }
}
$uc = Get-Content "$env:LOCALAPPDATA\copland-usage.json" -Raw | ConvertFrom-Json
if ($uc) {
    foreach ($sl in @($uc.limits | Where-Object { $_.kind -eq 'weekly_scoped' -and $_.scope.model.display_name })) {
        $limits.scoped += @{ name = "$($sl.scope.model.display_name)".ToLower(); percent = [math]::Round($sl.percent) }
    }
}

# --- heatmap-daten (112 tage) + session-zaehler je projekt-pfad ---
$heat = @{}
$projSessions = @{}   # session-dir-name (lower) -> anzahl jsonl letzte 30 tage
Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory | ForEach-Object {
    $c30 = 0
    Get-ChildItem $_.FullName -File -Filter *.jsonl | ForEach-Object {
        if ($_.LastWriteTime -gt (Get-Date).AddDays(-112)) {
            $d = $_.LastWriteTime.Date.ToString('yyyy-MM-dd')
            $heat[$d] = [int]$heat[$d] + 1
        }
        if ($_.LastWriteTime -gt (Get-Date).AddDays(-30)) { $c30++ }
    }
    $projSessions[$_.Name.ToLower()] = $c30
}

# --- bereiche + projekte ---
$areaData = @()
$balance = @()
foreach ($a in $areas) {
    $projList = @()
    $bal7 = 0
    foreach ($p in @(Get-ChildItem (Join-Path $OD $a.dir) -Directory | Where-Object { $_.Name -notmatch '^[_.]' } | Sort-Object Name)) {
        $privat = ($a.dir -eq '40_private' -and $p.Name -ne 'assistent')
        $zweck = ''; $stand = ''
        $cmd = Join-Path $p.FullName 'CLAUDE.md'
        if (-not $privat -and (Test-Path $cmd)) {
            $sec = ''
            foreach ($l in (Get-Content $cmd -Encoding utf8)) {
                if ($l -match '^##\s+(\S+)') { $sec = $Matches[1].ToLower(); continue }
                if ($sec -eq 'zweck' -and -not $zweck -and $l.Trim() -and $l -notmatch '^#') { $zweck = $l.Trim() }
                if ($sec -eq 'stand' -and $l -match '^\s*-\s*(.+)') { $stand = $Matches[1] }
            }
        }
        $t = $p.LastWriteTime
        if (Test-Path $cmd) { $ct = (Get-Item $cmd).LastWriteTime; if ($ct -gt $t) { $t = $ct } }
        $days = [int]((Get-Date) - $t).TotalDays
        # session-dir-name aus dem pfad ableiten (mangling: : \ _ -> -)
        $sname = ($p.FullName -replace '[:\\_]', '-').ToLower()
        $s30 = [int]$projSessions[$sname]
        # sessions der letzten 7 tage grob fuer balance (anteilig via s30 zu ungenau -> eigener zaehler)
        $sdirFull = "$env:USERPROFILE\.claude\projects\$sname"
        if (Test-Path $sdirFull) {
            $bal7 += @(Get-ChildItem $sdirFull -File -Filter *.jsonl |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }).Count
        }
        if ($zweck.Length -gt 160) { $zweck = $zweck.Substring(0, 159) + '~' }
        if ($stand.Length -gt 160) { $stand = $stand.Substring(0, 159) + '~' }
        $projList += @{ name = $p.Name; days = $days; zweck = $zweck; stand = $stand; s30 = $s30; privat = [bool]$privat }
    }
    $areaData += @{ name = $a.name; dir = $a.dir; projects = $projList }
    $balance += @{ name = $a.name; count = $bal7 }
}

# --- commits (30 tage) + werkstatt ---
$commits = @()
foreach ($cl in (git -C "$OD\00_System" log --since='30 days ago' --pretty=format:'%ad|%s' --date=format:'%Y-%m-%d')) {
    $cd, $cm = $cl -split '\|', 2
    if ($cm.Length -gt 70) { $cm = $cm.Substring(0, 69) + '~' }
    $commits += @{ d = $cd; m = $cm }
}
$werk = @()
foreach ($wf in @(Get-ChildItem "$OD\00_System\werkstatt\html\*.html", "$OD\00_System\werkstatt\pdf\*.pdf" -File |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) })) {
    $werk += @{ d = $wf.LastWriteTime.ToString('yyyy-MM-dd'); m = $wf.BaseName }
}

# --- offene punkte + skills ---
$offen = @()
$sec = ''
foreach ($l in (Get-Content "$OD\00_System\offene-punkte.md" -Encoding utf8)) {
    if ($l -match '^##\s+(.*)') { $sec = $Matches[1] }
    elseif ($sec -and $l -match '^\s*-\s*(.+)') { $offen += @{ sec = $sec.ToLower(); text = $Matches[1] } }
}
$skills = @(Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory | ForEach-Object { "/$($_.Name)" }) +
          @(Get-ChildItem "$env:USERPROFILE\.claude\commands" -File -Filter *.md | ForEach-Object { "/$($_.BaseName)" })

$data = @{
    generated = (Get-Date -Format 'ddd dd.MM. HH:mm').ToLower()
    limits = $limits; heat = $heat; areas = $areaData; balance = $balance
    commits = $commits; werk = $werk; offen = $offen; skills = $skills
} | ConvertTo-Json -Depth 6 -Compress

$template = @'
<!doctype html><html lang="de"><head><meta charset="utf-8">
<title>copland hub</title>
<style>
  :root { --fg:#B8C4CE; --ac:#8CABC6; --dim:#4A5866; --warn:#C2848F; --line:#1C2731; }
  body { background:#000; color:var(--fg); font-family:"Departure Mono","Consolas",monospace;
         font-size:13px; line-height:1.5; margin:0; padding:26px 34px; }
  h1 { color:var(--ac); font-size:15px; font-weight:normal; margin:0; }
  h2 { color:var(--ac); font-size:13px; font-weight:normal; margin:0 0 8px; }
  .dim { color:var(--dim); } .warn { color:var(--warn); }
  .sep { color:var(--dim); margin:20px 0 10px; letter-spacing:2px; }
  .row { display:flex; gap:28px; flex-wrap:wrap; align-items:flex-start; }
  .gauge { text-align:center; }
  .gauge svg { display:block; margin:0 auto 4px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(330px,1fr)); gap:10px; }
  .card { border:1px solid var(--line); padding:10px 12px; }
  .card b { color:var(--ac); font-weight:normal; }
  .card .meta { color:var(--dim); float:right; }
  .card p { margin:4px 0 0; }
  .card .stand { color:var(--dim); margin-top:4px; }
  .heatwrap { display:grid; grid-auto-flow:column; grid-template-rows:repeat(7,13px); gap:2px; }
  .hc { width:11px; height:11px; background:var(--line); }
  .hc.l1{background:#2A3B4C}.hc.l2{background:#3F5A73}.hc.l3{background:#5F82A0}.hc.l4{background:#8CABC6}
  canvas { display:block; border:1px solid var(--line); }
  ul { margin:4px 0; padding-left:18px; } li { margin:2px 0; }
  svg text { font-family:inherit; }
</style></head><body>
<h1>copland hub</h1>
<div class="dim" id="gen"></div>

<div class="sep">..........................................................................</div>
<div class="row" id="gauges"></div>

<div class="sep">..........................................................................</div>
<div class="row">
  <div><h2>aktivitaet <span class="dim">16 wochen</span></h2><div class="heatwrap" id="heat"></div></div>
  <div><h2>balance <span class="dim">sessions 7 tage</span></h2><svg id="donut" width="220" height="160"></svg></div>
</div>

<div class="sep">..........................................................................</div>
<h2>lebens-graph <span class="dim">bereiche und projekte, groesse = aktivitaet 30 tage</span></h2>
<canvas id="graph" width="1200" height="420"></canvas>

<div class="sep">..........................................................................</div>
<h2>timeline <span class="dim">30 tage -- commits (akzent) und werkstatt (grau)</span></h2>
<svg id="tl" width="1200" height="110"></svg>

<div class="sep">..........................................................................</div>
<div id="areas"></div>

<div class="sep">..........................................................................</div>
<div class="row">
  <div style="min-width:420px"><h2>offene punkte</h2><div id="offen"></div></div>
  <div><h2>skills</h2><div class="dim" id="skills"></div></div>
</div>

<div class="sep">..........................................................................</div>
<div class="dim">present day. present time.</div>

<script>
const D = __DATA__;
const AC='#8CABC6', FG='#B8C4CE', DIM='#4A5866', WARN='#C2848F';
document.getElementById('gen').textContent = 'kommandozentrale · stand ' + D.generated;

// --- gauges ---
function gauge(label, pct) {
  const r=30, c=2*Math.PI*r, off=c*(1-pct/100);
  const col = pct>=80 ? WARN : AC;
  return '<div class="gauge"><svg width="84" height="84">'
    + '<circle cx="42" cy="42" r="'+r+'" fill="none" stroke="#1C2731" stroke-width="7"/>'
    + '<circle cx="42" cy="42" r="'+r+'" fill="none" stroke="'+col+'" stroke-width="7" '
    + 'stroke-dasharray="'+c+'" stroke-dashoffset="'+off+'" transform="rotate(-90 42 42)" stroke-linecap="butt"/>'
    + '<text x="42" y="47" text-anchor="middle" fill="'+FG+'" font-size="14">'+pct+'%</text></svg>'
    + '<div class="dim">'+label+'</div></div>';
}
let g='';
if (D.limits.five!=null)  g+=gauge('5h', D.limits.five);
if (D.limits.seven!=null) g+=gauge('7d', D.limits.seven);
(D.limits.scoped||[]).forEach(s=>{ g+=gauge(s.name, s.percent); });
document.getElementById('gauges').innerHTML = g || '<span class="dim">keine limit-daten</span>';

// --- heatmap: spalten = wochen, zeilen = mo-so ---
(function(){
  const wrap=document.getElementById('heat');
  const today=new Date(); today.setHours(0,0,0,0);
  const monday=new Date(today); monday.setDate(today.getDate()-((today.getDay()+6)%7));
  const start=new Date(monday); start.setDate(monday.getDate()-15*7);
  for (let wk=0; wk<16; wk++) for (let dw=0; dw<7; dw++) {
    const d=new Date(start); d.setDate(start.getDate()+wk*7+dw);
    const cell=document.createElement('div'); cell.className='hc';
    if (d<=today) {
      const key=d.toISOString().slice(0,10);
      const v=D.heat[key]||0;
      const lvl=v>=7?4:v>=4?3:v>=2?2:v>=1?1:0;
      if (lvl) cell.classList.add('l'+lvl);
      cell.title=key+' · '+v+' sessions';
    } else { cell.style.visibility='hidden'; }
    wrap.appendChild(cell);
  }
})();

// --- balance-donut ---
(function(){
  const svg=document.getElementById('donut');
  const shades=['#8CABC6','#6E8CA6','#9CC0D2','#4A5866','#B8C4CE','#3F5A73'];
  const total=D.balance.reduce((s,b)=>s+b.count,0);
  if (!total) { svg.outerHTML='<span class="dim">keine sessions diese woche</span>'; return; }
  const r=48, c=2*Math.PI*r; let acc=0, parts='';
  D.balance.forEach((b,i)=>{
    if (!b.count) return;
    const frac=b.count/total;
    parts+='<circle cx="80" cy="80" r="'+r+'" fill="none" stroke="'+shades[i%6]+'" stroke-width="16" '
      +'stroke-dasharray="'+(c*frac-1)+' '+(c-c*frac+1)+'" stroke-dashoffset="'+(-c*acc)+'" transform="rotate(-90 80 80)"/>';
    acc+=frac;
  });
  let leg=''; D.balance.forEach((b,i)=>{
    leg+='<text x="170" y="'+(30+i*20)+'" fill="'+(b.count?FG:DIM)+'" font-size="12">'
      +'<tspan fill="'+shades[i%6]+'">■</tspan> '+b.name+' '+b.count+'</text>';
  });
  svg.setAttribute('width','300');
  svg.innerHTML=parts+leg;
})();

// --- lebens-graph: force-directed ---
(function(){
  const cv=document.getElementById('graph'), ctx=cv.getContext('2d');
  cv.width=Math.min(1400, document.body.clientWidth-70);
  const W=cv.width, H=cv.height;
  const nodes=[], links=[];
  D.areas.forEach((a,i)=>{
    const ang=i/D.areas.length*2*Math.PI;
    const an={id:'a'+i, label:a.name, area:true, x:W/2+Math.cos(ang)*W/4, y:H/2+Math.sin(ang)*H/4, vx:0, vy:0,
              r: 9+Math.sqrt(a.projects.reduce((s,p)=>s+p.s30,0))*1.2};
    nodes.push(an);
    a.projects.forEach(p=>{
      const pn={label:p.name, x:an.x+(Math.random()-.5)*80, y:an.y+(Math.random()-.5)*80, vx:0, vy:0,
                r: 3+Math.sqrt(p.s30)*2.2, dim:p.s30===0};
      nodes.push(pn); links.push([an,pn]);
    });
  });
  let ticks=0;
  function step(){
    ticks++;
    for (let i=0;i<nodes.length;i++) for (let j=i+1;j<nodes.length;j++){
      const a=nodes[i], b=nodes[j];
      let dx=b.x-a.x, dy=b.y-a.y, d2=dx*dx+dy*dy+40, d=Math.sqrt(d2);
      const f=1400/d2;
      dx/=d; dy/=d;
      a.x-=dx*f; a.y-=dy*f; b.x+=dx*f; b.y+=dy*f;
    }
    links.forEach(([a,b])=>{
      let dx=b.x-a.x, dy=b.y-a.y, d=Math.sqrt(dx*dx+dy*dy)||1;
      const f=(d-70)*0.02;
      dx/=d; dy/=d;
      a.x+=dx*f; a.y+=dy*f; b.x-=dx*f; b.y-=dy*f;
    });
    nodes.forEach(n=>{
      n.x+= (W/2-n.x)*0.002; n.y+=(H/2-n.y)*0.002;
      n.x=Math.max(20,Math.min(W-20,n.x)); n.y=Math.max(14,Math.min(H-14,n.y));
    });
    ctx.clearRect(0,0,W,H);
    ctx.strokeStyle='#1C2731';
    links.forEach(([a,b])=>{ ctx.beginPath(); ctx.moveTo(a.x,a.y); ctx.lineTo(b.x,b.y); ctx.stroke(); });
    nodes.forEach(n=>{
      ctx.beginPath(); ctx.arc(n.x,n.y,n.r,0,7);
      ctx.fillStyle = n.area ? AC : (n.dim ? '#22303C' : '#5F82A0');
      ctx.fill();
      ctx.fillStyle = n.area ? FG : DIM;
      ctx.font = (n.area?'12':'10')+'px "Departure Mono",monospace';
      ctx.fillText(n.label, n.x+n.r+4, n.y+3);
    });
    if (ticks<600) requestAnimationFrame(step);
  }
  step();
})();

// --- timeline ---
(function(){
  const svg=document.getElementById('tl');
  svg.setAttribute('width', Math.min(1400, document.body.clientWidth-70));
  const W=+svg.getAttribute('width'), H=110, pad=40;
  const now=new Date(); now.setHours(0,0,0,0);
  const x=d=>{ const t=(new Date(d)-now)/86400000; return pad+(t+30)/30*(W-2*pad); };
  let s='<line x1="'+pad+'" y1="80" x2="'+(W-pad)+'" y2="80" stroke="#1C2731"/>';
  for (let i=30;i>=0;i-=7){
    const d=new Date(now); d.setDate(now.getDate()-i);
    s+='<text x="'+x(d)+'" y="100" fill="'+DIM+'" font-size="10" text-anchor="middle">'
      +String(d.getDate()).padStart(2,'0')+'.'+String(d.getMonth()+1).padStart(2,'0')+'.</text>';
  }
  (D.commits||[]).forEach(c=>{
    s+='<circle cx="'+x(c.d)+'" cy="60" r="4" fill="'+AC+'"><title>'+c.d+' · '+c.m.replace(/&/g,'&amp;').replace(/</g,'&lt;')+'</title></circle>';
  });
  (D.werk||[]).forEach(w=>{
    s+='<rect x="'+(x(w.d)-3)+'" y="34" width="6" height="6" fill="'+DIM+'"><title>'+w.d+' · '+w.m+'</title></rect>';
  });
  svg.innerHTML=s;
})();

// --- bereiche/projekte als karten ---
(function(){
  const el=document.getElementById('areas');
  let s='';
  D.areas.forEach(a=>{
    s+='<h2 style="margin-top:14px">'+a.name+' <span class="dim">'+a.dir+' · '+a.projects.length+' projekte</span></h2><div class="grid">';
    a.projects.forEach(p=>{
      const rel = p.days===0?'heute':p.days===1?'gestern':'vor '+p.days+'t';
      s+='<div class="card"><span class="meta">'+rel+'</span><b>'+p.name+'</b>';
      if (p.zweck) s+='<p>'+p.zweck.replace(/&/g,'&amp;').replace(/</g,'&lt;')+'</p>';
      else if (p.privat) s+='<p class="dim">privat</p>';
      else s+='<p class="dim">keine CLAUDE.md</p>';
      if (p.stand) s+='<div class="stand">stand: '+p.stand.replace(/&/g,'&amp;').replace(/</g,'&lt;')+'</div>';
      s+='</div>';
    });
    s+='</div>';
  });
  el.innerHTML=s;
})();

// --- offene punkte + skills ---
(function(){
  let s='', cur='';
  (D.offen||[]).forEach(o=>{
    if (o.sec!==cur){ if(cur)s+='</ul>'; cur=o.sec; s+='<div class="dim">'+o.sec+'</div><ul>'; }
    s+='<li>'+o.text.replace(/&/g,'&amp;').replace(/</g,'&lt;')+'</li>';
  });
  if (cur) s+='</ul>';
  document.getElementById('offen').innerHTML=s;
  document.getElementById('skills').textContent=(D.skills||[]).join('   ');
})();
</script>
</body></html>
'@

Set-Content $out ($template.Replace('__DATA__', $data)) -Encoding utf8
Write-Output "hub -> $out"
