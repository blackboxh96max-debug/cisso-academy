#!/usr/bin/env python3
"""Assemble le build web Flutter en UN seul fichier HTML autonome.

Usage :
    flutter build web --release --no-web-resources-cdn --pwa-strategy=none
    python3 tool/build_single_html.py build/web cisso-academy.html

Le fichier obtenu s'ouvre par double-clic (adresse file://), sans serveur et
sans réseau. Tout y est embarqué, compressé en gzip puis encodé en base64 :
main.dart.js, CanvasKit (moteur de dessin, .js + .wasm), contenu, images,
polices. Au démarrage, un petit chargeur :
  1. décompresse le paquet (DecompressionStream du navigateur) ;
  2. remplace window.fetch pour servir les fichiers embarqués (le navigateur
     refuse les fetch vers file://) ;
  3. démarre CanvasKit à partir du .wasm embarqué et le range dans
     window.flutterCanvasKit, ce qui évite au moteur de le télécharger ;
  4. lance main.dart.js sans le chargeur flutter.js (démarrage automatique).

Les polices de secours des émojis et symboles (Noto Color Emoji, Noto Sans
Symbols, Noto Sans Math) que le moteur irait chercher sur fonts.gstatic.com
sont téléchargées une fois au moment de l'assemblage et embarquées aussi.
Option : 3e argument = dossier cache pour ces polices.
"""
import base64
import gzip
import json
import mimetypes
import os
import re
import sys
import urllib.request

MIME = {
    '.json': 'application/json',
    '.js': 'text/javascript',
    '.wasm': 'application/wasm',
    '.ttf': 'font/ttf',
    '.woff2': 'font/woff2',
    '.otf': 'font/otf',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.webp': 'image/webp',
    '.bin': 'application/octet-stream',
    '.frag': 'application/octet-stream',
}


def patch_canvaskit(src: str) -> str:
    """Module ES → script classique (pas d'import de module en file://)."""
    if 'export default CanvasKitInit;' not in src:
        sys.exit('canvaskit.js : export introuvable, format inattendu')
    src = src.replace('export default CanvasKitInit;',
                      'window.CanvasKitInit = CanvasKitInit;')
    return src.replace('import.meta.url', 'document.baseURI')


GSTATIC = 'https://fonts.gstatic.com/s/'
FALLBACK_FAMILIES = ('Emoji', 'Symbols', 'Math')


def fallback_fonts(main_js: str, cache_dir):
    """Polices de secours émojis/symboles connues du moteur → {chemin: octets}."""
    out = {}
    for name, path in re.findall(r'"(Noto [^"]+)","([a-z0-9]+/v\d+/[^"]+\.woff2)"', main_js):
        if not any(k in name for k in FALLBACK_FAMILIES):
            continue
        cached = os.path.join(cache_dir, path) if cache_dir else None
        if cached and os.path.exists(cached):
            data = open(cached, 'rb').read()
        else:
            with urllib.request.urlopen(GSTATIC + path, timeout=60) as r:
                data = r.read()
            if cached:
                os.makedirs(os.path.dirname(cached), exist_ok=True)
                open(cached, 'wb').write(data)
        out[path] = data
    if len(out) < 10:
        sys.exit(f'polices de secours : {len(out)} trouvées, format du moteur inattendu')
    return out


def main(web_dir: str, out_path: str, cache_dir=None) -> None:
    files = {}  # chemin relatif → octets
    files['main.dart.js'] = open(os.path.join(web_dir, 'main.dart.js'), 'rb').read()
    ck = open(os.path.join(web_dir, 'canvaskit', 'canvaskit.js'), encoding='utf-8').read()
    files['canvaskit/canvaskit.js'] = patch_canvaskit(ck).encode('utf-8')
    files['canvaskit/canvaskit.wasm'] = open(
        os.path.join(web_dir, 'canvaskit', 'canvaskit.wasm'), 'rb').read()
    assets_dir = os.path.join(web_dir, 'assets')
    for root, _, names in os.walk(assets_dir):
        for name in sorted(names):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, web_dir).replace(os.sep, '/')
            files[rel] = open(full, 'rb').read()

    for path, data in fallback_fonts(files['main.dart.js'].decode('utf-8'), cache_dir).items():
        files['gstatic/' + path] = data

    index, blob, offset = {}, bytearray(), 0
    for rel in sorted(files):
        data = files[rel]
        ext = os.path.splitext(rel)[1].lower()
        mime = MIME.get(ext) or mimetypes.guess_type(rel)[0] or 'application/octet-stream'
        index[rel] = [offset, len(data), mime]
        blob += data
        offset += len(data)
    packed = base64.b64encode(gzip.compress(bytes(blob), 9)).decode('ascii')

    icon = ''
    fav = os.path.join(web_dir, 'favicon.png')
    if os.path.exists(fav):
        icon = 'data:image/png;base64,' + base64.b64encode(open(fav, 'rb').read()).decode()

    html = TEMPLATE.replace('__ICON__', icon) \
                   .replace('__INDEX__', json.dumps(index, ensure_ascii=False)) \
                   .replace('__PACK__', packed)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f'{out_path} : {len(html) / 1e6:.1f} Mo ({len(files)} fichiers, '
          f'{len(blob) / 1e6:.1f} Mo avant compression)')


TEMPLATE = r'''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CISSO Academy</title>
<link rel="icon" type="image/png" href="__ICON__">
<style>
  html, body { margin: 0; height: 100%; background: #fdf8ef; }
  #cisso-loading { position: fixed; inset: 0; display: flex; flex-direction: column;
    align-items: center; justify-content: center; gap: 14px;
    font: 18px system-ui, sans-serif; color: #2b3a67; text-align: center; padding: 16px; }
  #cisso-loading .bar { width: 220px; height: 6px; border-radius: 3px; background: #e5dccb; overflow: hidden; }
  #cisso-loading .bar i { display: block; height: 100%; width: 40%; background: #e8590c;
    border-radius: 3px; animation: cisso-move 1.2s ease-in-out infinite; }
  @keyframes cisso-move { 0% { margin-left: -40%; } 100% { margin-left: 100%; } }
  #cisso-loading small { color: #6b6b6b; font-size: 14px; max-width: 420px; }
</style>
</head>
<body>
<div id="cisso-loading">
  <div><b>CISSO Academy</b></div>
  <div class="bar"><i></i></div>
  <small id="cisso-status">Ouverture de l'application, quelques secondes…</small>
</div>
<script id="cisso-index" type="application/json">__INDEX__</script>
<script id="cisso-pack" type="application/octet-stream">__PACK__</script>
<script>
(async function () {
  var statusEl = document.getElementById('cisso-status');
  function fail(msg) {
    statusEl.innerHTML = msg;
    document.querySelector('#cisso-loading .bar').style.display = 'none';
  }
  if (typeof DecompressionStream === 'undefined' || typeof WebAssembly === 'undefined') {
    fail("Ce navigateur est trop ancien. Ouvre ce fichier avec Chrome, Edge ou Firefox à jour.");
    return;
  }
  try {
    var index = JSON.parse(document.getElementById('cisso-index').textContent);
    var packEl = document.getElementById('cisso-pack');
    var b64 = packEl.textContent.trim();
    packEl.remove();
    var gz;
    if (Uint8Array.fromBase64) {
      gz = Uint8Array.fromBase64(b64);
    } else {
      var bin = atob(b64);
      gz = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) gz[i] = bin.charCodeAt(i);
    }
    b64 = null;
    var stream = new Blob([gz]).stream().pipeThrough(new DecompressionStream('gzip'));
    var all = new Uint8Array(await new Response(stream).arrayBuffer());
    gz = null;

    function file(path) {
      var e = index[path];
      return e ? all.subarray(e[0], e[0] + e[1]) : null;
    }
    function lookup(url) {
      var u;
      try { u = new URL(url, document.baseURI); } catch (e) { return null; }
      if (u.origin === 'https://fonts.gstatic.com' && u.pathname.indexOf('/s/') === 0) {
        var g = 'gstatic/' + u.pathname.slice(3);
        return index[g] ? g : null;
      }
      if (u.protocol !== 'file:' && u.origin !== location.origin) return null;
      var parts = u.pathname.split('/').map(function (p) {
        try { return decodeURIComponent(p); } catch (e) { return p; }
      });
      for (var i = 0; i < parts.length; i++) {
        var key = parts.slice(i).join('/');
        if (index[key]) return key;
      }
      return null;
    }

    // Les fichiers embarqués remplacent le réseau.
    var realFetch = window.fetch ? window.fetch.bind(window) : null;
    window.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : (input && (input.url || String(input)));
      var key = lookup(url);
      if (key) {
        var bytes = file(key);
        return Promise.resolve(new Response(bytes.slice(), {
          status: 200, headers: { 'Content-Type': index[key][2] }
        }));
      }
      if (realFetch) return realFetch(input, init);
      return Promise.reject(new TypeError('Hors ligne : ' + url));
    };

    function runScript(path) {
      return new Promise(function (resolve, reject) {
        var s = document.createElement('script');
        s.src = URL.createObjectURL(new Blob([file(path)], { type: 'text/javascript' }));
        s.onload = resolve;
        s.onerror = function () { reject(new Error('Échec du chargement de ' + path)); };
        document.body.appendChild(s);
      });
    }

    // Moteur de dessin CanvasKit, démarré à partir du .wasm embarqué.
    await runScript('canvaskit/canvaskit.js');
    var wasm = file('canvaskit/canvaskit.wasm');
    window.flutterCanvasKit = await window.CanvasKitInit({
      instantiateWasm: function (imports, done) {
        WebAssembly.instantiate(wasm, imports).then(function (r) {
          done(r.instance, r.module);
        });
        return {};
      }
    });

    // L'application. Sans flutter.js, le moteur démarre tout seul.
    await runScript('main.dart.js');
    var hide = setInterval(function () {
      if (document.querySelector('flt-glass-pane, flutter-view')) {
        clearInterval(hide);
        setTimeout(function () {
          var l = document.getElementById('cisso-loading');
          if (l) l.remove();
        }, 300);
      }
    }, 100);
  } catch (e) {
    console.error(e);
    fail("L'application n'a pas pu démarrer : " + (e && e.message ? e.message : e) +
         "<br>Essaie avec Chrome ou Edge à jour.");
  }
})();
</script>
</body>
</html>
'''

if __name__ == '__main__':
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    main(*sys.argv[1:])
