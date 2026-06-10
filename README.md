# MONOLOG — bymonolog.com

Автономна (offline-ready) копія сайту брендингової студії **MONOLOG**.
Сайт спочатку був зроблений у Webflow; ця версія повністю відв'язана від Webflow
та всіх зовнішніх CDN — усі ресурси (CSS, JS, шрифти, зображення, відео, звук)
зберігаються локально в `assets/`. Бекенду немає — це статичний сайт.

## Як запустити

Будь-який статичний сервер. Найпростіше:

```bash
python3 -m http.server 8765
# відкрити http://localhost:8765/index.html
```

> Відкривати файл напряму через `file://` не варто — частина ресурсів (шрифти,
> модулі) вимагає HTTP через політику CORS браузера.

## Структура

```
.
├── index.html              # єдина сторінка сайту (відформатований Webflow-експорт)
├── robots.txt
├── assets/
│   ├── css/
│   │   ├── main.css        # головні стилі Webflow (+ підключені локальні шрифти)
│   │   └── custom.css      # кастомні стилі (винесені з inline <style> в HTML)
│   ├── fonts/              # 3 шрифти: Animo, KHTeka, SuisseIntlMono (.woff2)
│   ├── img/                # 50 зображень (.avif/.svg/.png) + favicon/OG/webclip
│   ├── video/              # 10 фонових/проєктних відео (.mp4)
│   ├── audio/              # звуки UI: bgm.mp3 (фон) + tap/select кліки
│   └── js/                 # див. нижче
└── .backup/
    └── index.original.html # незмінений оригінальний експорт (на всяк випадок)
```

## JavaScript

Порядок підключення в кінці `index.html` важливий — бібліотеки мають
завантажитися ДО `odyn-bundle.js`.

| Файл | Призначення |
|------|-------------|
| `jquery-3.5.1.min.js` | jQuery (потрібен для `webflow.js`) |
| `webflow.js` | рушій інтеракцій Webflow |
| `gsap.min.js` + `ScrollTrigger` / `SplitText` / `CustomEase` | анімаційний движок GSAP та плагіни |
| `init.js` | реєстрація GSAP-плагінів (`gsap.registerPlugin(...)`) — винесено з inline |
| `three.min.js` | Three.js — 3D / WebGL (лого, фон) |
| `lenis.min.js` | плавний скрол |
| `howler.min.js` | звук |
| `barba.umd.js` | переходи між сторінками |
| **`odyn-bundle.js`** | **головний кастомний код сайту** — preloader, усі анімації, 3D, звукова логіка, переходи. ~36 КБ. Спочатку вантажився зі стороннього `cdn.odyn.dev`; тут локальний. Звуки в ньому посилаються на `./assets/audio/`. |

## Що було змінено відносно оригіналу

- Усі посилання на CDN (`cdn.prod.website-files.com`, `byhuy.b-cdn.net`,
  `cdn.odyn.dev`, jsdelivr, cloudfront) переписано на локальні `./assets/...`.
- Прибрано SRI-атрибути `integrity`/`crossorigin` (хеші не збігалися з локальними
  копіями і блокували CSS/JS).
- Видалено сторонній Google Tag Manager / Analytics (трекінг `G-NZ1SEFWY0E`).
- Inline `<style>` винесено в `assets/css/custom.css`,
  inline init-скрипт — у `assets/js/init.js`.
- HTML відформатовано (Prettier, strict whitespace — рендеринг не змінився).

## Деплой

Папка самодостатня — викладається на будь-який статичний хостинг
(Netlify / Vercel / GitHub Pages / власний сервер) перетягуванням.

Перед деплоєм на справжній домен варто:
- повернути **абсолютний URL** для `og:image` / `twitter:image` (зараз локальний
  відносний шлях — соцмережі не покажуть прев'ю з відносним шляхом);
- оновити або прибрати `Sitemap:` в `robots.txt`, якщо домен зміниться.
