/**
 * Фон экранов IronPulse v2 («Ember Pulse»): свечение фазы, дуга пульса, кольцо отдыха.
 * Рисуется в <canvas> 466×466 под интерфейсом.
 */
const C = 233;          // центр
const R_HR = 218;       // радиус дуги пульса
const R_REST = 200;     // радиус кольца отдыха
const DEG = Math.PI / 180;
// Дуга пульса: от 220° до 140° по часовой (0° — верх), разрыв снизу под кнопку.
const HR_START = (220 - 90) * DEG;
const HR_SWEEP = 280 * DEG;

const GLOWS = {
  settings: [[0.5, 1.15, 'rgba(255,110,0,0.28)', null, 0.40]],
  menu: [[0.5, 0.5, 'rgba(255,140,0,0.30)', 'rgba(255,100,0,0.08)', 0.50], [0.5, 1.15, 'rgba(255,110,0,0.30)', null, 0.38]],
  ready: [[0.5, 0.62, 'rgba(0,230,118,0.20)', 'rgba(0,200,100,0.06)', 0.58], [0.5, 1.2, 'rgba(255,143,0,0.35)', null, 0.40]],
  set: [[0.5, 0.46, 'rgba(255,145,0,0.32)', 'rgba(255,110,0,0.10)', 0.60]],
  rest: [[0.5, 0.44, 'rgba(41,121,255,0.34)', 'rgba(0,176,255,0.10)', 0.62]],
  restLate: [[0.5, 0.44, 'rgba(255,160,0,0.30)', 'rgba(41,121,255,0.10)', 0.64]],
  panel: [[0.70, 0.46, 'rgba(255,23,68,0.22)', null, 0.38], [0.5, 0.84, 'rgba(255,171,0,0.16)', null, 0.34]],
  summary: [[0.5, 0.15, 'rgba(255,193,7,0.30)', 'rgba(255,143,0,0.08)', 0.50]],
  paused: [[0.5, 0.5, 'rgba(144,164,174,0.16)', null, 0.55]]
};

function glow(ctx, g) {
  const x = g[0] * 466;
  const y = g[1] * 466;
  const r = g[4] * 466 * 1.4;
  const grad = ctx.createRadialGradient(x, y, 0, x, y, r);
  grad.addColorStop(0, g[2]);
  if (g[3]) {
    grad.addColorStop(0.55, g[3]);
  }
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 466, 466);
}

function hrGradient(ctx) {
  const g = ctx.createLinearGradient(15, 0, 451, 0);
  g.addColorStop(0, '#00E676');
  g.addColorStop(0.5, '#FFC400');
  g.addColorStop(1, '#FF3D00');
  return g;
}

/**
 * Мягкое свечение без shadowBlur (на часах тень замкнутой фигуры заливает её целиком):
 * два широких полупрозрачных штриха под основным.
 */
function glowStroke(ctx, a0, a1, r, width, color) {
  const layers = [[width + 16, 0.10], [width + 8, 0.20]];
  layers.forEach((l) => {
    ctx.lineWidth = l[0];
    ctx.strokeStyle = color.replace('ALPHA', '' + l[1]);
    ctx.beginPath();
    ctx.arc(C, C, r, a0, a1, false);
    ctx.stroke();
  });
}

/** Дуга пульса: трек + заполнение до доли frac (0..1) со свечением цвета зоны. */
function hrArc(ctx, frac, width, glowColor, dim) {
  ctx.lineCap = 'round';
  ctx.lineWidth = width;
  ctx.strokeStyle = 'rgba(255,255,255,0.08)';
  ctx.beginPath();
  ctx.arc(C, C, R_HR, HR_START, HR_START + HR_SWEEP, false);
  ctx.stroke();
  if (frac > 0.005) {
    const a1 = HR_START + HR_SWEEP * frac;
    if (!dim) {
      glowStroke(ctx, HR_START, a1, R_HR, width, glowColor);
    }
    ctx.lineWidth = width;
    ctx.strokeStyle = hrGradient(ctx);
    ctx.globalAlpha = dim ? 0.85 : 1;
    ctx.beginPath();
    ctx.arc(C, C, R_HR, HR_START, a1, false);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }
}

/** Кольцо отдыха: шкала 0–5:00, метка на 3:00; после 5:00 — янтарное. */
function restRing(ctx, progress, marks) {
  ctx.lineCap = 'round';
  const w = 10;
  const late = marks >= 2;
  if (!late) {
    ctx.lineWidth = w;
    ctx.strokeStyle = 'rgba(41,182,246,0.12)';
    ctx.beginPath();
    ctx.arc(C, C, R_REST, 0, 2 * Math.PI, false);
    ctx.stroke();
  }
  const p = late ? 0.9999 : Math.max(0, Math.min(1, progress));
  const a0 = -Math.PI / 2;
  if (p > 0.003) {
    const a1 = a0 + 2 * Math.PI * p;
    glowStroke(ctx, a0, a1, R_REST, w, late ? 'rgba(255,171,0,ALPHA)' : 'rgba(41,182,246,ALPHA)');
    const g = ctx.createLinearGradient(C - R_REST, C - R_REST, C + R_REST, C + R_REST);
    if (late) {
      g.addColorStop(0, '#FFE082');
      g.addColorStop(0.5, '#FFAB00');
      g.addColorStop(1, '#FF6D00');
    } else {
      g.addColorStop(0, '#80F0FF');
      g.addColorStop(0.5, '#29B6F6');
      g.addColorStop(1, '#2962FF');
    }
    ctx.lineWidth = w;
    ctx.strokeStyle = g;
    ctx.beginPath();
    ctx.arc(C, C, R_REST, a0, a1, false);
    ctx.stroke();
  }
  if (!late) {
    // Метка 3:00 (60% шкалы)
    const am = a0 + 2 * Math.PI * 0.6;
    ctx.fillStyle = marks >= 1 ? '#FFFFFF' : 'rgba(255,255,255,0.55)';
    ctx.beginPath();
    ctx.arc(C + R_REST * Math.cos(am), C + R_REST * Math.sin(am), 7, 0, 2 * Math.PI, false);
    ctx.fill();
  }
}

function zoneGlowColor(zone) {
  if (zone === 2) {
    return 'rgba(255,61,0,ALPHA)';
  }
  if (zone === 1) {
    return 'rgba(255,171,0,ALPHA)';
  }
  return 'rgba(0,230,118,ALPHA)';
}

/** Меню: шкала по краю, два кольца и кнопка «СТАРТ» — всё концентрично центру экрана. */
function drawMenu(ctx) {
  // Шкала на 60 делений, каждое пятое — янтарное и длиннее.
  ctx.lineCap = 'round';
  for (let i = 0; i < 60; i++) {
    const a = i * Math.PI / 30 - Math.PI / 2;
    const major = i % 5 === 0;
    const r1 = major ? 203 : 207;
    const r2 = 214;
    ctx.lineWidth = major ? 3 : 2;
    ctx.strokeStyle = major ? 'rgba(255,171,0,0.75)' : 'rgba(255,255,255,0.16)';
    ctx.beginPath();
    ctx.moveTo(C + r1 * Math.cos(a), C + r1 * Math.sin(a));
    ctx.lineTo(C + r2 * Math.cos(a), C + r2 * Math.sin(a));
    ctx.stroke();
  }
  // Кольца
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(255,171,0,0.18)';
  ctx.beginPath();
  ctx.arc(C, C, 120, 0, 2 * Math.PI, false);
  ctx.stroke();
  ctx.lineWidth = 2;
  ctx.strokeStyle = 'rgba(255,171,0,0.42)';
  ctx.beginPath();
  ctx.arc(C, C, 104, 0, 2 * Math.PI, false);
  ctx.stroke();
  // Свечение кнопки — плавный радиальный градиент от края кнопки наружу
  const halo = ctx.createRadialGradient(C, C, 84, C, C, 124);
  halo.addColorStop(0, 'rgba(255,140,0,0.38)');
  halo.addColorStop(0.45, 'rgba(255,120,0,0.12)');
  halo.addColorStop(1, 'rgba(255,100,0,0)');
  ctx.fillStyle = halo;
  ctx.beginPath();
  ctx.arc(C, C, 124, 0, 2 * Math.PI, false);
  ctx.fill();
  // Кнопка: объёмный градиент с мягким бликом вверху слева
  const g = ctx.createRadialGradient(C - 26, C - 30, 18, C, C, 88);
  g.addColorStop(0, '#FFD36A');
  g.addColorStop(0.4, '#FFAB00');
  g.addColorStop(0.78, '#FF8F00');
  g.addColorStop(1, '#EF6C00');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(C, C, 88, 0, 2 * Math.PI, false);
  ctx.fill();
}

/**
 * Итог: кольцо зон пульса по краю — три дуги (восстановление / рабочая / пиковая),
 * длина пропорциональна времени в зоне; сверху — подложка кубка.
 */
function drawSummary(ctx, zoneMs) {
  const R = 212;
  const W = 10;
  const total = zoneMs ? zoneMs[0] + zoneMs[1] + zoneMs[2] : 0;
  ctx.lineCap = 'round';
  ctx.lineWidth = W;
  ctx.strokeStyle = 'rgba(255,255,255,0.07)';
  ctx.beginPath();
  ctx.arc(C, C, R, 0, 2 * Math.PI, false);
  ctx.stroke();
  if (total > 0) {
    const colors = [['#00C853', '#69F0AE', 'rgba(0,230,118,ALPHA)'],
      ['#FFB300', '#FFD54F', 'rgba(255,171,0,ALPHA)'],
      ['#FF3D00', '#FF6E40', 'rgba(255,61,0,ALPHA)']];
    const gap = 0.10;                         // зазор между дугами, рад (с учётом скруглённых концов)
    const parts = zoneMs.filter((ms) => ms > 0).length;
    const free = 2 * Math.PI - (parts > 1 ? gap * parts : 0);
    let a = -Math.PI / 2 + (parts > 1 ? gap / 2 : 0);
    for (let z = 0; z < 3; z++) {
      if (zoneMs[z] <= 0) {
        continue;
      }
      const sweep = Math.max(0.0001, free * zoneMs[z] / total - (parts > 1 ? 0 : 0.0001));
      glowStroke(ctx, a, a + sweep, R, W, colors[z][2]);
      const g = ctx.createLinearGradient(C - R, C - R, C + R, C + R);
      g.addColorStop(0, colors[z][1]);
      g.addColorStop(1, colors[z][0]);
      ctx.lineWidth = W;
      ctx.strokeStyle = g;
      ctx.beginPath();
      ctx.arc(C, C, R, a, a + sweep, false);
      ctx.stroke();
      a += sweep + (parts > 1 ? gap : 0);
    }
  }
  // Подложка кубка (иконка — поверх, в разметке)
  const halo = ctx.createRadialGradient(C, 70, 26, C, 70, 52);
  halo.addColorStop(0, 'rgba(255,179,0,0.35)');
  halo.addColorStop(1, 'rgba(255,179,0,0)');
  ctx.fillStyle = halo;
  ctx.beginPath();
  ctx.arc(C, 70, 52, 0, 2 * Math.PI, false);
  ctx.fill();
  const g = ctx.createRadialGradient(C - 9, 60, 4, C, 70, 30);
  g.addColorStop(0, '#FFE082');
  g.addColorStop(0.5, '#FFB300');
  g.addColorStop(1, '#FF8F00');
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(C, 70, 30, 0, 2 * Math.PI, false);
  ctx.fill();
}

/**
 * opts: { scene: 'menu'|'ready'|'set'|'rest'|'restLate'|'panel'|'summary'|'paused',
 *         hrFrac, zone, restProgress, restMarks, zoneMs }
 */
export function drawScene(ctx, opts) {
  ctx.clearRect(0, 0, 466, 466);
  ctx.fillStyle = '#000000';
  ctx.fillRect(0, 0, 466, 466);
  const glows = GLOWS[opts.scene] || [];
  glows.forEach((g) => glow(ctx, g));

  const scene = opts.scene;
  if (scene === 'menu') {
    drawMenu(ctx);
    return;
  }
  if (scene === 'summary') {
    drawSummary(ctx, opts.zoneMs);
    return;
  }
  if (scene === 'ready' || scene === 'set' || scene === 'paused') {
    hrArc(ctx, opts.hrFrac || 0, 12, zoneGlowColor(opts.zone), scene === 'paused');
    return;
  }
  if (scene === 'rest' || scene === 'restLate') {
    hrArc(ctx, opts.hrFrac || 0, 8, zoneGlowColor(opts.zone), true);
    restRing(ctx, opts.restProgress || 0, opts.restMarks || 0);
  }
}

/** Кольцо удержания вокруг кнопки «Завершить» (canvas 130×130). */
export function drawHoldRing(ctx, frac) {
  ctx.clearRect(0, 0, 130, 130);
  ctx.lineWidth = 4;
  ctx.lineCap = 'round';
  ctx.strokeStyle = 'rgba(255,82,82,0.25)';
  ctx.beginPath();
  ctx.arc(65, 65, 61, 0, 2 * Math.PI, false);
  ctx.stroke();
  if (frac > 0.003) {
    const a1 = -Math.PI / 2 + 2 * Math.PI * Math.min(0.9999, frac);
    ctx.lineWidth = 10;
    ctx.strokeStyle = 'rgba(255,255,255,0.18)';
    ctx.beginPath();
    ctx.arc(65, 65, 61, -Math.PI / 2, a1, false);
    ctx.stroke();
    ctx.lineWidth = 4;
    ctx.strokeStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(65, 65, 61, -Math.PI / 2, a1, false);
    ctx.stroke();
  }
}
