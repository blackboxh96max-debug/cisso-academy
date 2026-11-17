import 'dart:convert';

import '../models/content.dart';

/// Couleurs des grandes branches, les mêmes que dans l'application et le PDF.
const _branchColors = [
  '#3B82F6',
  '#8B5CF6',
  '#EC4899',
  '#F97316',
  '#22C55E',
  '#06B6D4',
];

String _toneHex(String? tone, String fallback) => switch (tone) {
  'blue' => _branchColors[0],
  'violet' => _branchColors[1],
  'pink' => _branchColors[2],
  'orange' => _branchColors[3],
  'green' => _branchColors[4],
  'turquoise' => _branchColors[5],
  'red' => '#EF4444',
  'yellow' => '#CA8A04',
  _ => fallback,
};

final _escape = const HtmlEscape();

/// Carte mentale en une seule page HTML autonome : aucun fichier, police ni
/// script extérieur, elle s'ouvre hors ligne dans n'importe quel navigateur.
/// Chaque branche se replie ou se déplie ; zoom, recherche et impression
/// sont intégrés.
String mindMapHtml({required String title, required MindNode root}) {
  final body = StringBuffer();
  var counter = 0;

  void node(MindNode n, int depth, String color) {
    final id = 'n${counter++}';
    final kids = n.children;
    final hidden = kids.isEmpty ? 0 : n.size - 1;
    body.write(
      '<li class="node d${depth > 3 ? 3 : depth}'
      '${kids.isNotEmpty && depth >= 2 ? ' closed' : ''}" '
      'style="--c:$color" id="$id">',
    );
    body.write('<div class="row">');
    body.write('<div class="bubble"');
    if (kids.isNotEmpty) {
      body.write(' role="button" tabindex="0" aria-expanded="true"');
    }
    body.write('>');
    body.write('<span class="label">');
    if (n.emoji != null) body.write('${_escape.convert(n.emoji!)} ');
    body.write(_escape.convert(n.label).replaceAll('\n', '<br>'));
    body.write('</span>');
    if (n.en != null) {
      body.write('<span class="en">EN ${_escape.convert(n.en!)}</span>');
    }
    if (n.detail != null) {
      body.write(
        '<span class="detail">'
        '${_escape.convert(n.detail!).replaceAll('\n', '<br>')}</span>',
      );
    }
    body.write('</div>');
    if (kids.isNotEmpty) {
      body.write(
        '<button class="toggle" type="button" '
        'data-count="$hidden" title="Replier ou déplier"></button>',
      );
    }
    body.write('</div>');
    if (kids.isNotEmpty) {
      body.write('<ul class="kids">');
      for (final (i, c) in kids.indexed) {
        final branch = depth == 0
            ? _toneHex(c.tone, _branchColors[i % _branchColors.length])
            : _toneHex(c.tone, color);
        node(c, depth + 1, branch);
      }
      body.write('</ul>');
    }
    body.write('</li>');
  }

  node(root, 0, '#8B5CF6');
  final safeTitle = _escape.convert(title);
  return '''<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$safeTitle</title>
<style>
:root{--bg:#f6f1e7;--paper:#fffdf8;--ink:#1f2937;--soft:#6b7280;--line:#d6cfc2;--en:#2563eb;--mark:#ffe066}
@media (prefers-color-scheme:dark){:root{--bg:#16181d;--paper:#1f2229;--ink:#e5e7eb;--soft:#9ca3af;--line:#3a3f4a;--en:#93c5fd;--mark:#8a6d00}}
*{box-sizing:border-box}
html,body{margin:0;height:100%}
body{background:var(--bg);color:var(--ink);font:15px/1.35 "Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;display:flex;flex-direction:column}
header{position:sticky;top:0;z-index:2;background:var(--paper);border-bottom:1px solid var(--line);padding:10px 16px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
h1{font-size:18px;margin:0 12px 0 0;flex:1 1 220px}
header button,header input{font:inherit;border:1px solid var(--line);background:var(--bg);color:var(--ink);border-radius:8px;padding:6px 10px;min-height:36px}
header button{cursor:pointer}
header button:hover{border-color:var(--soft)}
header input{min-width:160px;flex:0 1 220px}
#zoomValue{min-width:48px;text-align:center;color:var(--soft)}
#count{color:var(--soft);font-size:13px}
main{flex:1;overflow:auto;padding:24px 16px 48px}
#map{zoom:1;width:max-content}
ul{list-style:none;margin:0;padding:0}
.node{display:flex;align-items:center}
.row{display:flex;align-items:center;position:relative;z-index:1}
.bubble{border-radius:10px;padding:7px 11px;max-width:260px;border:2px solid var(--c);background:var(--paper);cursor:default}
.bubble[role=button]{cursor:pointer}
.label{display:block;font-weight:600}
.en{display:block;font-size:12px;font-style:italic;color:var(--en)}
.detail{display:block;font-size:12.5px;color:var(--soft);margin-top:2px}
.d0>.row>.bubble{background:var(--c);color:#fff;font-size:20px;border-radius:24px;padding:14px 22px;text-align:center;max-width:280px}
.d1>.row>.bubble{background:var(--c);color:#fff;font-size:16px}
.d0>.row>.bubble .en,.d1>.row>.bubble .en,.d0>.row>.bubble .detail,.d1>.row>.bubble .detail{color:#fff;opacity:.9}
.d2>.row>.bubble{background:color-mix(in srgb,var(--c) 16%,var(--paper))}
.d3>.row>.bubble .label{font-weight:500}
.toggle{width:30px;height:30px;margin-left:-4px;border-radius:50%;border:2px solid var(--c);background:var(--paper);color:var(--c);font-weight:700;cursor:pointer;flex:none;font-size:13px;padding:0}
.toggle::after{content:"−"}
.closed>.row>.toggle{width:auto;min-width:30px;padding:0 7px;border-radius:15px;background:var(--c);color:#fff}
.closed>.row>.toggle::after{content:"+" attr(data-count)}
.closed>.kids{display:none}
.kids{position:relative;padding-left:26px;display:flex;flex-direction:column}
.kids::before{content:"";position:absolute;left:0;top:50%;width:26px;border-top:2px solid var(--c)}
.kids>li{position:relative;padding:5px 0 5px 26px}
.kids>li::before{content:"";position:absolute;left:0;top:50%;width:26px;border-top:2px solid var(--c)}
.kids>li::after{content:"";position:absolute;left:0;top:0;bottom:0;border-left:2px solid var(--c)}
.kids>li:first-child::after{top:50%}
.kids>li:last-child::after{bottom:50%}
.kids>li:only-child::after{display:none}
.hit>.row>.bubble{box-shadow:0 0 0 4px var(--mark)}
mark{background:var(--mark);color:inherit;border-radius:3px}
footer{color:var(--soft);font-size:12px;padding:8px 16px;border-top:1px solid var(--line);background:var(--paper)}
@media print{header,footer{display:none}main{overflow:visible}body{background:#fff}}
</style>
</head>
<body>
<header>
<h1>$safeTitle</h1>
<button type="button" id="expand">Tout déplier</button>
<button type="button" id="collapse">Tout replier</button>
<button type="button" id="zoomOut" title="Dézoomer" aria-label="Dézoomer">−</button>
<span id="zoomValue">100 %</span>
<button type="button" id="zoomIn" title="Zoomer" aria-label="Zoomer">+</button>
<button type="button" id="zoomReset">100 %</button>
<input type="search" id="find" placeholder="Chercher dans la carte" aria-label="Chercher dans la carte">
<span id="count"></span>
<button type="button" id="print">Imprimer</button>
</header>
<main><div id="map"><ul class="tree">$body</ul></div></main>
<footer>CISSO MILE2 Academy · carte mentale hors ligne · touchez une bulle ou un rond pour replier ou déplier sa branche.</footer>
<script>
(function(){
var map=document.getElementById('map');
function nodes(){return map.querySelectorAll('.node');}
function sync(li){var b=li.querySelector(':scope>.row>.bubble[role=button]');if(b)b.setAttribute('aria-expanded',li.classList.contains('closed')?'false':'true');}
function toggle(li){li.classList.toggle('closed');sync(li);}
map.addEventListener('click',function(e){var t=e.target.closest('.toggle,.bubble[role=button]');if(!t)return;toggle(t.closest('.node'));});
map.addEventListener('keydown',function(e){if((e.key==='Enter'||e.key===' ')&&e.target.matches('.bubble[role=button]')){e.preventDefault();toggle(e.target.closest('.node'));}});
document.getElementById('expand').onclick=function(){nodes().forEach(function(li){li.classList.remove('closed');sync(li);});};
document.getElementById('collapse').onclick=function(){nodes().forEach(function(li){var deep=li.matches('.d2,.d3')&&li.querySelector(':scope>.kids');li.classList.toggle('closed',!!deep);sync(li);});};
var zoom=1;function setZoom(z){zoom=Math.min(2.5,Math.max(0.3,z));map.style.zoom=zoom;document.getElementById('zoomValue').textContent=Math.round(zoom*100)+' %';}
document.getElementById('zoomIn').onclick=function(){setZoom(zoom+0.1);};
document.getElementById('zoomOut').onclick=function(){setZoom(zoom-0.1);};
document.getElementById('zoomReset').onclick=function(){setZoom(1);};
document.getElementById('print').onclick=function(){document.getElementById('expand').click();window.print();};
var labels=[];map.querySelectorAll('.label,.en,.detail').forEach(function(el){labels.push([el,el.innerHTML]);});
function fold(s){return s.normalize('NFD').replace(/[\\u0300-\\u036f]/g,'').toLowerCase();}
function esc(s){return s.replace(/[&<>"]/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
document.getElementById('find').addEventListener('input',function(){
var q=fold(this.value.trim());var hits=0;
labels.forEach(function(p){p[0].innerHTML=p[1];});
nodes().forEach(function(li){li.classList.remove('hit');});
if(!q){document.getElementById('count').textContent='';return;}
labels.forEach(function(p){var el=p[0];var text=el.textContent;var f=fold(text);
function next(from){var i=f.indexOf(q,from);while(i>0&&/[a-z0-9]/.test(f.charAt(i-1)))i=f.indexOf(q,i+1);return i;}
var i=next(0);if(i<0)return;
var out='',pos=0;while(i>=0){out+=esc(text.slice(pos,i))+'<mark>'+esc(text.slice(i,i+q.length))+'</mark>';pos=i+q.length;i=next(pos);}
el.innerHTML=out+esc(text.slice(pos));var li=el.closest('.node');if(!li.classList.contains('hit')){li.classList.add('hit');hits++;}
for(var a=li.parentElement.closest('.node');a;a=a.parentElement.closest('.node')){a.classList.remove('closed');sync(a);}});
document.getElementById('count').textContent=hits?hits+' bulle'+(hits>1?'s':''):'Aucun résultat';
var first=map.querySelector('.hit');if(first)first.scrollIntoView({block:'center',inline:'center',behavior:'smooth'});
});
nodes().forEach(sync);
var root=map.querySelector('.d0>.row>.bubble');if(root)root.scrollIntoView({block:'center',inline:'start'});
})();
</script>
</body>
</html>
''';
}
