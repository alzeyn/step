import { useState, useEffect, useRef } from "react";

// ─────────────────────────────────────────────
// BLOCK DEFINITIONS
// ─────────────────────────────────────────────
const BD = {
  movement: [
    { id: "mfwd", l: "Движение вперёд", c: "#059669", p: [{ k: "sec", l: "сек", d: 2 }] },
    { id: "mbwd", l: "Движение назад", c: "#059669", p: [{ k: "sec", l: "сек", d: 2 }] },
    { id: "tr", l: "Поворот вправо", c: "#10b981", p: [{ k: "deg", l: "°", d: 90 }] },
    { id: "tl", l: "Поворот влево", c: "#10b981", p: [{ k: "deg", l: "°", d: 90 }] },
    { id: "stop", l: "Стоп", c: "#dc2626", p: [] },
    { id: "spd", l: "Скорость", c: "#22c55e", p: [{ k: "pct", l: "%", d: 50 }] },
  ],
  control: [
    { id: "wait", l: "Ждать", c: "#ea580c", p: [{ k: "sec", l: "сек", d: 1 }] },
    { id: "rpt", l: "Повторить", c: "#c2410c", p: [{ k: "n", l: "раз", d: 3 }], ctr: true },
    { id: "ifthen", l: "Если … то", c: "#9a3412", p: [], ctr: true },
  ],
  sound: [
    { id: "beep", l: "Звуковой сигнал", c: "#7c3aed", p: [{ k: "sec", l: "сек", d: 1 }] },
    { id: "vol", l: "Громкость", c: "#6d28d9", p: [{ k: "v", l: "%", d: 50 }] },
    { id: "nosnd", l: "Стоп звука", c: "#5b21b6", p: [] },
  ],
  events: [
    { id: "start", l: "Когда запущена", c: "#d97706", p: [], isStart: true },
    { id: "btn", l: "При нажатии кнопки", c: "#b45309", p: [] },
  ],
  sensors: [
    { id: "touch", l: "Датчик касания", c: "#2563eb", p: [] },
    { id: "dist", l: "Расстояние", c: "#1d4ed8", p: [{ k: "cm", l: "см", d: 10 }] },
    { id: "clr", l: "Датчик цвета", c: "#1e40af", p: [] },
  ],
  ops: [
    { id: "gt", l: "Больше чем", c: "#65a30d", p: [{ k: "v", l: "", d: 5 }] },
    { id: "lt", l: "Меньше чем", c: "#4d7c0f", p: [{ k: "v", l: "", d: 5 }] },
  ],
};
const CATS = [
  { id: "movement", l: "Движение", c: "#059669" },
  { id: "control", l: "Управление", c: "#ea580c" },
  { id: "sound", l: "Звук", c: "#7c3aed" },
  { id: "events", l: "События", c: "#d97706" },
  { id: "sensors", l: "Сенсоры", c: "#2563eb" },
  { id: "ops", l: "Операторы", c: "#65a30d" },
];
function bdef(id) {
  for (const bs of Object.values(BD)) { const f = bs.find(b => b.id === id); if (f) return f; }
  return null;
}

// ─────────────────────────────────────────────
// SIMULATOR ENGINE
// ─────────────────────────────────────────────
const DORD = ["right", "down", "left", "up"];
const DD = { right: [1, 0], down: [0, 1], left: [-1, 0], up: [0, -1] };

function runSim(prog, field) {
  const ws = new Set((field.walls || []).map(w => `${w.x},${w.y}`));
  let pos = [field.rx, field.ry];
  let di = DORD.indexOf(field.rdir || "right");
  const states = [{ pos: [...pos], di, ev: "init" }];
  let sc = 0;
  function mv(n, rev = false) {
    const dii = rev ? (di + 2) % 4 : di;
    const [dx, dy] = DD[DORD[dii]];
    for (let i = 0; i < Math.min(n, 12); i++) {
      if (sc++ > 180) return;
      const nx = pos[0] + dx, ny = pos[1] + dy;
      if (nx < 0 || ny < 0 || nx >= field.sz || ny >= field.sz) break;
      if (ws.has(`${nx},${ny}`)) break;
      pos = [nx, ny];
      states.push({ pos: [...pos], di, ev: "mv" });
    }
  }
  function ex(b) {
    if (sc > 180) return;
    const pv = b.pv || {};
    if (b.bid === "mfwd") mv(pv.sec || 2);
    else if (b.bid === "mbwd") mv(pv.sec || 2, true);
    else if (b.bid === "tr") { di = (di + 1) % 4; states.push({ pos: [...pos], di, ev: "turn" }); }
    else if (b.bid === "tl") { di = (di + 3) % 4; states.push({ pos: [...pos], di, ev: "turn" }); }
    else if (b.bid === "stop") states.push({ pos: [...pos], di, ev: "stop" });
    else if (b.bid === "wait") states.push({ pos: [...pos], di, ev: "wait" });
    else if (b.bid === "beep") states.push({ pos: [...pos], di, ev: "beep" });
    else if (b.bid === "rpt") { const n = pv.n || 3; for (let i = 0; i < n; i++) (b.inner || []).forEach(ex); }
  }
  prog.forEach(ex);
  return states;
}

// ─────────────────────────────────────────────
// TOPICS DATA
// ─────────────────────────────────────────────
let _wid = 0;
function mkWB(bid) {
  const def = bdef(bid) || {};
  const pv = {};
  (def.p || []).forEach(p => { pv[p.k] = p.d; });
  return { wid: `w${++_wid}`, bid, pv, inner: [] };
}

const TOPICS = [
  {
    id: "t1", title: "Движение робота", color: "#2563eb", bg: "#EFF6FF", icon: "🤖",
    goal: "Научиться давать роботу команды движения в нужном порядке",
    levels: [
      {
        id: "l1", title: "Жизненная ситуация", type: "seq", color: "#2563eb", tasks: [
          {
            id: "a", title: "Почисти зубы",
            inst: "Каждое утро Миша чистит зубы. Помоги ему сделать всё по порядку!",
            scene: { bg: "#dbeafe", emoji: "🪥", sub: "Ванная комната" },
            items: ["Взять зубную щётку", "Нанести пасту", "Чистить зубы", "Прополоскать рот"],
            correct: [0, 1, 2, 3], comp: ["Последовательность"],
          },
          {
            id: "b", title: "Вымой руки перед едой",
            inst: "Перед едой всегда нужно мыть руки! Расставь шаги в правильном порядке.",
            scene: { bg: "#dcfce7", emoji: "🧼", sub: "Умывальник" },
            items: ["Открыть кран", "Намочить руки", "Намылить мылом", "Смыть мыло", "Закрыть кран", "Вытереть руки"],
            correct: [0, 1, 2, 3, 4, 5], comp: ["Последовательность"],
          },
          {
            id: "c", title: "Оденься на прогулку",
            inst: "На улице холодно! Что надевают сначала, а что потом? Расставь по порядку.",
            scene: { bg: "#fde8d8", emoji: "🧥", sub: "Прихожая" },
            items: ["Надеть свитер", "Надеть куртку", "Обуть ботинки", "Надеть шапку", "Надеть варежки"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность", "Декомпозиция"],
          },
        ],
      },
      {
        id: "l2", title: "Визуальный алгоритм", type: "grid", color: "#16a34a", tasks: [
          {
            id: "d", title: "Проведи робота к флажку",
            inst: "Нажимай на стрелки и строй путь для робота. Доведи его до флажка!",
            gtype: "path", gs: 6, rx: 0, ry: 5,
            goals: [{ x: 5, y: 0, t: "flag" }], walls: [{ x: 2, y: 2 }, { x: 3, y: 3 }],
            comp: ["Составление алгоритма", "Последовательность"],
          },
          {
            id: "e", title: "Найди пропущенную команду",
            inst: "В алгоритме пропущен один шаг. Какой?",
            gtype: "choice", gs: 5, rx: 0, ry: 4,
            goals: [{ x: 4, y: 0, t: "flag" }], walls: [],
            path: ["↑", "↑", "→", "?", "→", "↑"], opts: ["↑ Вверх", "↓ Вниз", "← Влево", "→ Вправо"], corr: 0,
            comp: ["Поиск ошибок"],
          },
          {
            id: "f", title: "Где окажется робот?",
            inst: "Прочитай алгоритм и кликни на клетку, где окажется робот.",
            gtype: "predict", gs: 6, rx: 0, ry: 5, goals: [], walls: [],
            path: ["up", "up", "right", "right", "up", "right"], cdest: { x: 3, y: 2 },
            comp: ["Последовательность"],
          },
        ],
      },
      {
        id: "l3", title: "Программирование EV3", type: "prog", color: "#f97316", tasks: [
          {
            id: "g", title: "Доедь до флажка",
            inst: "Собери программу из блоков и нажми ▶ Запустить!",
            field: { sz: 8, rx: 0, ry: 4, rdir: "right", goals: [{ x: 6, y: 4, t: "flag" }], walls: [] },
            hint: "Попробуй: [Когда запущена] → [Движение вперёд: 6 сек] → [Стоп]",
            comp: ["Составление алгоритма"],
          },
          {
            id: "h", title: "Найди ошибку в программе",
            inst: "Роботу дали неправильную программу — он едет не туда! Найди и замени ошибочный блок.",
            field: { sz: 8, rx: 0, ry: 4, rdir: "right", goals: [{ x: 6, y: 4, t: "flag" }], walls: [] },
            pre: [{ id: "p1", bid: "start", pv: {} }, { id: "p2", bid: "mbwd", pv: { sec: 3 } }, { id: "p3", bid: "stop", pv: {} }],
            hint: "Какой блок заставляет робота ехать НАЗАД вместо вперёд?",
            comp: ["Поиск ошибок"],
          },
          {
            id: "i", title: "Доставь подарок к домику",
            inst: "Объедь дерево и доставь подарок к домику! Нужно 6+ блоков.",
            field: { sz: 8, rx: 0, ry: 6, rdir: "right", goals: [{ x: 7, y: 2, t: "house" }], walls: [{ x: 3, y: 6 }, { x: 3, y: 5 }, { x: 3, y: 4 }], trees: [{ x: 3, y: 3 }] },
            hint: "Маршрут: Вперёд → Поворот вправо → Вперёд → Поворот влево → Вперёд → Поворот влево → Вперёд → Стоп",
            comp: ["Составление алгоритма", "Декомпозиция"],
          },
        ],
      },
    ],
  },
  {
    id: "t2", title: "Программирование движений", color: "#16a34a", bg: "#F0FDF4", icon: "⚙️",
    goal: "Научиться управлять скоростью, поворотами и повторением движений",
    levels: [
      {
        id: "l1", title: "Жизненная ситуация", type: "seq", color: "#16a34a", tasks: [
          {
            id: "a", title: "Сделай бутерброд",
            inst: "Катя хочет сделать бутерброд с маслом. Помоги ей — расставь шаги по порядку!",
            scene: { bg: "#cffafe", emoji: "🥪", sub: "Кухня" },
            items: ["Взять хлеб", "Намазать масло", "Положить на тарелку", "Съесть бутерброд"],
            correct: [0, 1, 2, 3], comp: ["Последовательность"],
          },
          {
            id: "b", title: "Нарисуй рисунок",
            inst: "Ваня хочет нарисовать домик. Расставь шаги рисования по порядку.",
            scene: { bg: "#fdf2f8", emoji: "🎨", sub: "Урок рисования" },
            items: ["Взять лист бумаги", "Взять карандаши", "Нарисовать домик", "Раскрасить рисунок", "Убрать карандаши"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность"],
          },
          {
            id: "c", title: "Полей цветок",
            inst: "Цветок на подоконнике хочет пить! Расставь шаги полива в правильном порядке.",
            scene: { bg: "#f0fdf4", emoji: "🌷", sub: "Класс" },
            items: ["Взять лейку", "Набрать воду", "Подойти к цветку", "Полить цветок", "Убрать лейку"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность", "Декомпозиция"],
          },
        ],
      },
      {
        id: "l2", title: "Визуальный алгоритм", type: "grid", color: "#16a34a", tasks: [
          {
            id: "d", title: "Объедь квадратный трек",
            inst: "Составь маршрут, чтобы робот объехал периметр квадрата и вернулся домой.",
            gtype: "path", gs: 5, rx: 0, ry: 4, goals: [{ x: 4, y: 0, t: "flag" }], walls: [],
            comp: ["Составление алгоритма", "Последовательность"],
          },
          {
            id: "e", title: "Найди ошибку в алгоритме",
            inst: "Робот попал не туда — найди ошибочную команду!",
            gtype: "choice", gs: 5, rx: 0, ry: 4, goals: [{ x: 4, y: 0, t: "flag" }], walls: [],
            path: ["↑", "↑", "→", "↑", "→", "?", "↑"], opts: ["↑ Вверх", "↓ Вниз", "← Влево", "→ Вправо"], corr: 3,
            comp: ["Поиск ошибок"],
          },
          {
            id: "f", title: "Найди паттерн движения",
            inst: "Что повторяется в этом длинном алгоритме? Выбери правильный ответ.",
            gtype: "choice", gs: 5, rx: 2, ry: 2, goals: [{ x: 2, y: 2, t: "flag" }], walls: [],
            path: ["↑", "→", "↓", "←", "↑", "→", "↓", "←", "↑", "→", "↓", "←"],
            opts: ["Повторить 3 раза: [↑ → ↓ ←]", "Повторить 4 раза: [↑ ↑]", "12 разных команд", "Повторить 2 раза: [→ ↑ ← ↓ → ↑]"], corr: 0,
            comp: ["Декомпозиция", "Составление алгоритма"],
          },
        ],
      },
      {
        id: "l3", title: "Программирование EV3", type: "prog", color: "#f97316", tasks: [
          {
            id: "g", title: "Объедь зоопарк",
            inst: "Собери длинную программу чтобы объехать зоопарк! (нужно 8+ блоков)",
            field: { sz: 8, rx: 1, ry: 6, rdir: "right", goals: [{ x: 1, y: 1, t: "flag" }], walls: [{ x: 2, y: 5 }, { x: 5, y: 5 }, { x: 2, y: 2 }, { x: 5, y: 2 }] },
            hint: "Вперёд → Поворот влево → Вперёд → Поворот влево → Вперёд → Поворот влево → Вперёд → Поворот влево",
            comp: ["Составление алгоритма", "Декомпозиция"],
          },
          {
            id: "h", title: "Используй цикл",
            inst: "Используй блок «Повторить», чтобы сделать программу короче и умнее!",
            field: { sz: 8, rx: 0, ry: 7, rdir: "right", goals: [{ x: 7, y: 0, t: "flag" }], walls: [] },
            hint: "Помести [Движение вперёд] + [Поворот вправо] в блок «Повторить 4 раза»",
            comp: ["Составление алгоритма"],
          },
          {
            id: "i", title: "Спаси игрушку в лабиринте",
            inst: "Помоги роботу пробраться через лабиринт к игрушке! Нужно 10+ блоков.",
            field: { sz: 8, rx: 0, ry: 7, rdir: "right", goals: [{ x: 7, y: 0, t: "toy" }], walls: [{ x: 2, y: 7 }, { x: 2, y: 6 }, { x: 2, y: 5 }, { x: 4, y: 2 }, { x: 4, y: 3 }, { x: 4, y: 4 }, { x: 6, y: 5 }, { x: 6, y: 6 }] },
            hint: "Используй кнопку «Шаг» чтобы проверять каждый блок по очереди!",
            comp: ["Составление алгоритма", "Декомпозиция", "Поиск ошибок"],
          },
        ],
      },
    ],
  },
  {
    id: "t3", title: "Запуск программы", color: "#f97316", bg: "#FFF7ED", icon: "▶️", locked: true,
    goal: "Научиться запускать программы и управлять их выполнением",
    levels: [
      {
        id: "l1", title: "Жизненная ситуация", type: "seq", color: "#f97316", tasks: [
          {
            id: "a", title: "Покорми собаку",
            inst: "Пёс Шарик хочет есть! Расставь шаги кормления собаки по порядку.",
            scene: { bg: "#fed7aa", emoji: "🐶", sub: "Дома на кухне" },
            items: ["Возьми миску", "Насыпь корм", "Налей воды в другую миску", "Позови собаку"],
            correct: [0, 1, 2, 3], comp: ["Последовательность"],
          },
          {
            id: "b", title: "Собери пазл",
            inst: "Разберём пазл вместе! Расставь шаги сборки в правильном порядке.",
            scene: { bg: "#fed7aa", emoji: "🧩", sub: "За столом" },
            items: ["Высыпь кусочки на стол", "Переверни все лицом вверх", "Найди угловые кусочки", "Собери края", "Заполни середину"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность"],
          },
          {
            id: "c", title: "Приготовь какао",
            inst: "Холодный день — время какао! Расставь шаги приготовления по порядку.",
            scene: { bg: "#fed7aa", emoji: "☕", sub: "Кухня" },
            items: ["Налей молоко в кружку", "Добавь ложку какао", "Перемешай ложкой", "Подогрей в микроволновке", "Остуди и выпей"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность"],
          },
        ],
      },
      {
        id: "l2", title: "Визуальный алгоритм", type: "grid", color: "#f97316", tasks: [
          { id: "d", title: "Маршрут к старту", inst: "Проведи ракету к стартовой площадке.", gtype: "path", gs: 5, rx: 0, ry: 4, goals: [{ x: 4, y: 0, t: "flag" }], walls: [{ x: 2, y: 2 }], comp: ["Составление алгоритма"] },
          { id: "e", title: "Найди пропуск", inst: "Какой команды не хватает?", gtype: "choice", gs: 4, rx: 0, ry: 3, goals: [{ x: 3, y: 0, t: "flag" }], walls: [], path: ["↑", "→", "?", "→"], opts: ["↑ Вверх", "↓ Вниз", "← Влево", "→ Вправо"], corr: 0, comp: ["Поиск ошибок"] },
          { id: "f", title: "Где остановится?", inst: "Кликни на клетку, где окажется робот.", gtype: "predict", gs: 5, rx: 0, ry: 4, goals: [], walls: [], path: ["up", "right", "up", "right"], cdest: { x: 2, y: 2 }, comp: ["Последовательность"] },
        ],
      },
      {
        id: "l3", title: "Программирование EV3", type: "prog", color: "#f97316", tasks: [
          { id: "g", title: "Простая программа", inst: "Собери базовую программу!", field: { sz: 7, rx: 0, ry: 3, rdir: "right", goals: [{ x: 5, y: 3, t: "flag" }], walls: [] }, hint: "Начало → Движение вперёд → Стоп", comp: ["Составление алгоритма"] },
          { id: "h", title: "С поворотом", inst: "Добавь поворот в программу!", field: { sz: 7, rx: 0, ry: 6, rdir: "right", goals: [{ x: 5, y: 2, t: "flag" }], walls: [] }, hint: "Используй блок Поворот вправо или влево!", comp: ["Составление алгоритма"] },
          { id: "i", title: "Длинный путь", inst: "Составь длинную программу с объездом!", field: { sz: 8, rx: 0, ry: 7, rdir: "right", goals: [{ x: 7, y: 0, t: "flag" }], walls: [{ x: 3, y: 5 }, { x: 5, y: 3 }] }, hint: "Думай пошагово — планируй маршрут заранее!", comp: ["Составление алгоритма", "Декомпозиция"] },
        ],
      },
    ],
  },
  {
    id: "t4", title: "Звук для робота", color: "#7c3aed", bg: "#F5F3FF", icon: "🔊", locked: true,
    goal: "Научиться добавлять звуковые команды в программы",
    levels: [
      {
        id: "l1", title: "Жизненная ситуация", type: "seq", color: "#7c3aed", tasks: [
          {
            id: "a", title: "Сыграй на барабане",
            inst: "Пора на урок музыки! Расставь шаги подготовки к игре по порядку.",
            scene: { bg: "#ede9fe", emoji: "🥁", sub: "Музыкальный класс" },
            items: ["Сядь за барабан", "Возьми палочки", "Отсчитай ритм: раз-два-три", "Начни играть"],
            correct: [0, 1, 2, 3], comp: ["Последовательность"],
          },
          {
            id: "b", title: "Испеки печенье",
            inst: "Мама испечёт печенье! Расставь шаги выпечки по порядку.",
            scene: { bg: "#ede9fe", emoji: "🍪", sub: "Кухня" },
            items: ["Смешай муку и масло", "Добавь сахар", "Вылепи фигурки", "Поставь в духовку", "Достань и дай остыть"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность"],
          },
          {
            id: "c", title: "Встань по будильнику",
            inst: "Завтра важный день! Расставь шаги утреннего подъёма по порядку.",
            scene: { bg: "#ede9fe", emoji: "⏰", sub: "Утро" },
            items: ["Услышать будильник", "Выключить будильник", "Потянуться", "Встать с кровати", "Открыть шторы"],
            correct: [0, 1, 2, 3, 4], comp: ["Последовательность"],
          },
        ],
      },
      {
        id: "l2", title: "Визуальный алгоритм", type: "grid", color: "#7c3aed", tasks: [
          { id: "d", title: "Нотный маршрут", inst: "Проведи нотку к финишу!", gtype: "path", gs: 5, rx: 0, ry: 4, goals: [{ x: 4, y: 0, t: "flag" }], walls: [], comp: ["Составление алгоритма"] },
          { id: "e", title: "Найди пропуск в нотах", inst: "Где ошибка в алгоритме?", gtype: "choice", gs: 4, rx: 0, ry: 3, goals: [{ x: 3, y: 0, t: "flag" }], walls: [], path: ["↑", "→", "?", "→"], opts: ["↑", "↓", "←", "→"], corr: 0, comp: ["Поиск ошибок"] },
          { id: "f", title: "Предскажи позицию", inst: "Где окажется персонаж после алгоритма?", gtype: "predict", gs: 5, rx: 0, ry: 4, goals: [], walls: [], path: ["up", "right", "up", "right"], cdest: { x: 2, y: 2 }, comp: ["Последовательность"] },
        ],
      },
      {
        id: "l3", title: "Программирование EV3", type: "prog", color: "#7c3aed", tasks: [
          { id: "g", title: "Робот гудит у флажка", inst: "Добавь звук когда робот доедет до флажка!", field: { sz: 7, rx: 0, ry: 3, rdir: "right", goals: [{ x: 5, y: 3, t: "flag" }], walls: [] }, hint: "Движение вперёд → Звуковой сигнал → Стоп", comp: ["Составление алгоритма"] },
          { id: "h", title: "Музыкальный робот", inst: "Добавь несколько звуковых блоков в программу!", field: { sz: 7, rx: 0, ry: 3, rdir: "right", goals: [{ x: 5, y: 3, t: "flag" }], walls: [] }, hint: "Используй несколько блоков Звуковой сигнал", comp: ["Составление алгоритма"] },
          { id: "i", title: "Сигнализация в пути", inst: "Робот должен подавать сигналы во время движения!", field: { sz: 8, rx: 0, ry: 4, rdir: "right", goals: [{ x: 7, y: 4, t: "flag" }], walls: [] }, hint: "Чередуй: Движение + Звук + Движение + Звук...", comp: ["Составление алгоритма", "Декомпозиция"] },
        ],
      },
    ],
  },
  {
    id: "t5", title: "Практическая работа", color: "#d97706", bg: "#FFFBEB", icon: "🏆", locked: true,
    goal: "Применить все знания в сложных творческих заданиях",
    levels: [
      {
        id: "l1", title: "Жизненная ситуация", type: "seq", color: "#d97706", tasks: [
          { id: "a", title: "Накрой стол к обеду", inst: "Помоги накрыть стол! Расставь шаги по порядку.", scene: { bg: "#fef3c7", emoji: "🍽️", sub: "Столовая" }, items: ["Постели скатерть", "Разложи тарелки", "Разложи ложки", "Поставь стаканы", "Принеси хлеб"], correct: [0, 1, 2, 3, 4], comp: ["Последовательность"] },
          { id: "b", title: "Приготовь рабочее место", inst: "Урок начинается! Расставь шаги подготовки по порядку.", scene: { bg: "#fef3c7", emoji: "📚", sub: "Классная комната" }, items: ["Сядь за парту", "Достань учебник", "Достань тетрадь", "Положи пенал на стол", "Приготовься слушать"], correct: [0, 1, 2, 3, 4], comp: ["Последовательность"] },
          { id: "c", title: "Сделай снежинку из бумаги", inst: "Смастерим красивую снежинку! Расставь шаги по порядку.", scene: { bg: "#fef3c7", emoji: "❄️", sub: "Урок труда" }, items: ["Возьми квадратный лист", "Сложи по диагонали", "Сложи ещё раз", "Вырежи узоры по краям", "Разверни — вот снежинка!"], correct: [0, 1, 2, 3, 4], comp: ["Последовательность"] },
        ],
      },
      {
        id: "l2", title: "Визуальный алгоритм", type: "grid", color: "#d97706", tasks: [
          { id: "d", title: "Сложный лабиринт", inst: "Проведи робота через весь лабиринт!", gtype: "path", gs: 6, rx: 0, ry: 5, goals: [{ x: 5, y: 0, t: "flag" }], walls: [{ x: 2, y: 3 }, { x: 3, y: 3 }, { x: 2, y: 4 }, { x: 4, y: 1 }, { x: 4, y: 2 }], comp: ["Составление алгоритма", "Поиск ошибок"] },
          { id: "e", title: "Что пропущено?", inst: "Найди пропущенную команду!", gtype: "choice", gs: 5, rx: 0, ry: 4, goals: [{ x: 4, y: 0, t: "flag" }], walls: [], path: ["↑", "→", "↑", "?", "↑"], opts: ["↑", "↓", "←", "→"], corr: 3, comp: ["Поиск ошибок"] },
          { id: "f", title: "Финальный алгоритм", inst: "Составь длинный маршрут к цели!", gtype: "path", gs: 6, rx: 0, ry: 5, goals: [{ x: 5, y: 0, t: "flag" }], walls: [], comp: ["Составление алгоритма"] },
        ],
      },
      {
        id: "l3", title: "Финальный проект", type: "prog", color: "#d97706", tasks: [
          { id: "g", title: "Робот-спасатель", inst: "Доберись до игрушки через препятствия!", field: { sz: 8, rx: 0, ry: 7, rdir: "right", goals: [{ x: 7, y: 0, t: "toy" }], walls: [{ x: 2, y: 6 }, { x: 2, y: 5 }, { x: 4, y: 4 }, { x: 4, y: 3 }, { x: 6, y: 2 }] }, hint: "Планируй маршрут заранее — это сложное задание!", comp: ["Составление алгоритма", "Декомпозиция"] },
          { id: "h", title: "Робот-доставщик", inst: "Объедь препятствия и доставь посылку!", field: { sz: 8, rx: 0, ry: 4, rdir: "right", goals: [{ x: 7, y: 4, t: "house" }], walls: [{ x: 2, y: 3 }, { x: 2, y: 4 }, { x: 2, y: 5 }, { x: 5, y: 3 }, { x: 5, y: 4 }, { x: 5, y: 5 }] }, hint: "Объезжай препятствия сверху или снизу!", comp: ["Составление алгоритма", "Декомпозиция"] },
          { id: "i", title: "Свободный проект", inst: "Придумай сам! Сделай что-то интересное с роботом.", field: { sz: 8, rx: 3, ry: 4, rdir: "right", goals: [{ x: 7, y: 0, t: "flag" }, { x: 7, y: 7, t: "flag" }], walls: [{ x: 5, y: 2 }, { x: 5, y: 5 }] }, hint: "Это твой проект — дерзай! Попробуй добраться до любого из флажков.", comp: ["Составление алгоритма", "Декомпозиция", "Условные конструкции"] },
        ],
      },
    ],
  },
];

const BADGE_DEFS = [
  { id: "first", icon: "⭐", title: "Первый шаг", desc: "Выполнил первое задание", c: "#f59e0b" },
  { id: "streak", icon: "🔥", title: "В ритме", desc: "3 задания подряд без подсказок", c: "#ef4444" },
  { id: "master", icon: "🏆", title: "Мастер уровня", desc: "Прошёл все 3 уровня темы", c: "#8b5cf6" },
  { id: "detective", icon: "🔍", title: "Сыщик", desc: "Нашёл ошибку в программе", c: "#3b82f6" },
  { id: "coder", icon: "🚀", title: "Программист", desc: "Собрал программу из 8+ блоков", c: "#16a34a" },
  { id: "perfect", icon: "🌟", title: "Отличник", desc: "Прошёл тему без подсказок", c: "#f59e0b" },
  { id: "explorer", icon: "👾", title: "Исследователь", desc: "Прошёл все 5 тем", c: "#8b5cf6" },
];

// ─────────────────────────────────────────────
// SEQUENCE TASK
// ─────────────────────────────────────────────
function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function SequenceTask({ task, onSuccess }) {
  const correctItems = task.correct.map(i => task.items[i]);
  const [items, setItems] = useState(() => {
    let s = shuffle([...task.items]);
    if (JSON.stringify(s) === JSON.stringify(correctItems) && s.length > 1) [s[0], s[1]] = [s[1], s[0]];
    return s;
  });
  const [checked, setChecked] = useState(false);
  const [dragIdx, setDragIdx] = useState(null);
  const [showHint, setShowHint] = useState(false);

  const isCorrect = checked && JSON.stringify(items) === JSON.stringify(correctItems);
  const isWrong = checked && !isCorrect;

  function check() {
    setChecked(true);
    if (JSON.stringify(items) === JSON.stringify(correctItems)) setTimeout(() => onSuccess(), 900);
  }
  function reset() {
    let s = shuffle([...task.items]);
    if (JSON.stringify(s) === JSON.stringify(correctItems) && s.length > 1) [s[0], s[1]] = [s[1], s[0]];
    setItems(s); setChecked(false);
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <div style={{ borderRadius: 16, padding: "20px 24px", display: "flex", alignItems: "center", gap: 20, background: task.scene.bg }}>
        <span style={{ fontSize: 60 }}>{task.scene.emoji}</span>
        <div>
          <div style={{ fontWeight: 800, fontSize: 18, color: "#1e293b" }}>{task.scene.sub}</div>
          <div style={{ color: "#475569", fontSize: 14, marginTop: 4 }}>{task.inst}</div>
        </div>
      </div>
      <div style={{ fontSize: 13, color: "#64748b", padding: "4px 0" }}>
        Перетащи карточки, чтобы расставить их в правильный порядок:
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {items.map((item, i) => {
          const ok = checked && item === correctItems[i];
          const bad = checked && item !== correctItems[i];
          return (
            <div key={item} draggable
              onDragStart={() => setDragIdx(i)}
              onDragOver={e => e.preventDefault()}
              onDrop={() => {
                if (dragIdx === null || dragIdx === i) return;
                const a = [...items]; const [el] = a.splice(dragIdx, 1); a.splice(i, 0, el);
                setItems(a); setChecked(false); setDragIdx(null);
              }}
              style={{
                display: "flex", alignItems: "center", gap: 12, padding: "12px 16px",
                borderRadius: 12, cursor: "grab", userSelect: "none",
                background: ok ? "#dcfce7" : bad ? "#fee2e2" : "white",
                border: `2px solid ${ok ? "#16a34a" : bad ? "#dc2626" : "#e2e8f0"}`,
                transition: "background 0.3s, border-color 0.3s",
                boxShadow: dragIdx === i ? "0 4px 12px rgba(0,0,0,0.15)" : "none",
              }}>
              <span style={{ width: 28, height: 28, borderRadius: 8, background: "#f1f5f9", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, fontSize: 13, color: "#94a3b8", flexShrink: 0 }}>{i + 1}</span>
              <span style={{ fontSize: 18, flexShrink: 0 }}>⠿</span>
              <span style={{ fontWeight: 500, color: "#1e293b", fontSize: 15 }}>{item}</span>
              {ok && <span style={{ marginLeft: "auto", color: "#16a34a", fontWeight: 700, fontSize: 18 }}>✓</span>}
              {bad && <span style={{ marginLeft: "auto", color: "#dc2626", fontWeight: 700, fontSize: 18 }}>✗</span>}
            </div>
          );
        })}
      </div>
      {isCorrect && <div style={{ borderRadius: 16, padding: 16, textAlign: "center", fontWeight: 800, fontSize: 20, color: "#166534", background: "#dcfce7", border: "2px solid #86efac" }}>🎉 Правильно! Отличная работа!</div>}
      {isWrong && <div style={{ borderRadius: 12, padding: 12, color: "#991b1b", fontSize: 14, background: "#fee2e2" }}>Некоторые шаги стоят не на своём месте. Попробуй ещё раз!</div>}
      {showHint && <div style={{ borderRadius: 12, padding: 12, color: "#1e40af", fontSize: 14, background: "#dbeafe" }}>💡 Подумай: что нужно сделать самым первым? А что — в самую последнюю очередь?</div>}
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button onClick={check} style={{ padding: "10px 24px", borderRadius: 12, fontWeight: 700, color: "white", background: "#2563eb", border: "none", cursor: "pointer", fontSize: 15 }}>✓ Проверить</button>
        <button onClick={() => setShowHint(!showHint)} style={{ padding: "10px 20px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>💡 Подсказка</button>
        <button onClick={reset} style={{ padding: "10px 20px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>↺ Сбросить</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// GRID TASK
// ─────────────────────────────────────────────
const DMAP = { right: [1, 0], left: [-1, 0], up: [0, -1], down: [0, 1] };
const DARR = { right: "→", left: "←", up: "↑", down: "↓" };

function walkPath(dirs, rx, ry, gs, walls) {
  const ws = new Set((walls || []).map(w => `${w.x},${w.y}`));
  let pos = [rx, ry];
  for (const d of dirs) {
    const [dx, dy] = DMAP[d] || [0, 0];
    const nx = pos[0] + dx, ny = pos[1] + dy;
    if (nx >= 0 && ny >= 0 && nx < gs && ny < gs && !ws.has(`${nx},${ny}`)) pos = [nx, ny];
  }
  return pos;
}

function GridTask({ task, onSuccess }) {
  const [path, setPath] = useState([]);
  const [chosen, setChosen] = useState(null);
  const [clickedCell, setClickedCell] = useState(null);
  const [checked, setChecked] = useState(false);
  const [robPos, setRobPos] = useState([task.rx, task.ry]);
  const [running, setRunning] = useState(false);
  const [showHint, setShowHint] = useState(false);

  const gs = task.gs || 6;
  const CZ = Math.min(60, Math.floor(360 / gs));
  const goalMap = {};
  (task.goals || []).forEach(g => { goalMap[`${g.x},${g.y}`] = g.t; });
  const walls = new Set((task.walls || []).map(w => `${w.x},${w.y}`));

  const goalEmoji = t => t === "flag" ? "🚩" : t === "house" ? "🏠" : t === "toy" ? "🧸" : "🎯";

  function check() {
    if (task.gtype === "choice") {
      setChecked(true);
      if (chosen === task.corr) setTimeout(() => onSuccess(), 700);
    } else if (task.gtype === "predict") {
      setChecked(true);
      if (clickedCell && clickedCell[0] === task.cdest.x && clickedCell[1] === task.cdest.y) setTimeout(() => onSuccess(), 700);
    } else {
      setRunning(true);
      setRobPos([task.rx, task.ry]);
      const ws = new Set((task.walls || []).map(w => `${w.x},${w.y}`));
      let pos = [task.rx, task.ry];
      const steps = [[...pos]];
      for (const d of path) {
        const [dx, dy] = DMAP[d] || [0, 0];
        const nx = pos[0] + dx, ny = pos[1] + dy;
        if (nx >= 0 && ny >= 0 && nx < gs && ny < gs && !ws.has(`${nx},${ny}`)) { pos = [nx, ny]; steps.push([...pos]); }
      }
      let i = 0;
      const iv = setInterval(() => {
        if (i < steps.length) { setRobPos(steps[i]); i++; }
        else {
          clearInterval(iv); setRunning(false);
          const reached = Object.keys(goalMap).some(k => k === `${pos[0]},${pos[1]}`);
          setChecked(true);
          if (reached) setTimeout(() => onSuccess(), 700);
        }
      }, 280);
    }
  }

  function reset() { setPath([]); setChecked(false); setRobPos([task.rx, task.ry]); setChosen(null); setClickedCell(null); }

  const isSuccess = checked && (
    task.gtype === "choice" ? chosen === task.corr :
      task.gtype === "predict" ? (clickedCell && clickedCell[0] === task.cdest.x && clickedCell[1] === task.cdest.y) :
        Object.keys(goalMap).some(k => k === `${robPos[0]},${robPos[1]}`)
  );

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <div style={{ borderRadius: 12, padding: 12, background: "#f0fdf4", border: "1px solid #bbf7d0", color: "#166534", fontSize: 14 }}>{task.inst}</div>

      <div style={{ display: "flex", gap: 24, flexWrap: "wrap", alignItems: "flex-start" }}>
        {/* Grid */}
        <div>
          <div style={{ display: "grid", gridTemplateColumns: `repeat(${gs}, ${CZ}px)`, gap: 2 }}>
            {Array.from({ length: gs }, (_, y) => Array.from({ length: gs }, (_, x) => {
              const key = `${x},${y}`;
              const isWall = walls.has(key);
              const isGoal = goalMap[key];
              const isRobot = robPos[0] === x && robPos[1] === y;
              const isClicked = task.gtype === "predict" && clickedCell && clickedCell[0] === x && clickedCell[1] === y;
              const isCdest = task.gtype === "predict" && task.cdest && checked && task.cdest.x === x && task.cdest.y === y;
              return (
                <div key={key}
                  onClick={() => task.gtype === "predict" && !running && setClickedCell([x, y])}
                  style={{
                    width: CZ, height: CZ, borderRadius: 6,
                    background: isWall ? "#374151" : isClicked ? "#bfdbfe" : isCdest ? "#dcfce7" : "#f9fafb",
                    border: "1.5px solid #d1d5db",
                    display: "flex", alignItems: "center", justifyContent: "center",
                    fontSize: CZ * 0.48, cursor: task.gtype === "predict" ? "pointer" : "default",
                    transition: "background 0.2s",
                    position: "relative",
                  }}>
                  {isRobot && <span style={{ fontSize: CZ * 0.58, transition: "all 0.25s" }}>🤖</span>}
                  {isGoal && !isRobot && <span>{goalEmoji(isGoal)}</span>}
                </div>
              );
            }))}
          </div>

          {/* Direction buttons for path mode */}
          {task.gtype === "path" && (
            <div style={{ marginTop: 12, display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
              <button onClick={() => !running && setPath(p => [...p, "up"])} disabled={running}
                style={{ width: 44, height: 44, borderRadius: 10, fontWeight: 700, fontSize: 20, background: "#2563eb", color: "white", border: "none", cursor: "pointer" }}>↑</button>
              <div style={{ display: "flex", gap: 6 }}>
                <button onClick={() => !running && setPath(p => [...p, "left"])} disabled={running}
                  style={{ width: 44, height: 44, borderRadius: 10, fontWeight: 700, fontSize: 20, background: "#2563eb", color: "white", border: "none", cursor: "pointer" }}>←</button>
                <button onClick={() => !running && setPath(p => [...p, "down"])} disabled={running}
                  style={{ width: 44, height: 44, borderRadius: 10, fontWeight: 700, fontSize: 20, background: "#2563eb", color: "white", border: "none", cursor: "pointer" }}>↓</button>
                <button onClick={() => !running && setPath(p => [...p, "right"])} disabled={running}
                  style={{ width: 44, height: 44, borderRadius: 10, fontWeight: 700, fontSize: 20, background: "#2563eb", color: "white", border: "none", cursor: "pointer" }}>→</button>
              </div>
            </div>
          )}
        </div>

        {/* Right panel */}
        <div style={{ flex: 1, minWidth: 200, display: "flex", flexDirection: "column", gap: 10 }}>
          {/* Path display */}
          {task.gtype === "path" && (
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, color: "#64748b", marginBottom: 6 }}>Мой путь:</div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 4, minHeight: 36, padding: 8, borderRadius: 10, background: "#f1f5f9", border: "1px dashed #cbd5e1" }}>
                {path.length === 0 && <span style={{ color: "#94a3b8", fontSize: 13 }}>Строй путь кнопками слева...</span>}
                {path.map((d, i) => <span key={i} style={{ display: "inline-flex", width: 28, height: 28, alignItems: "center", justifyContent: "center", borderRadius: 6, background: "#2563eb", color: "white", fontWeight: 700, fontSize: 14 }}>{DARR[d]}</span>)}
              </div>
              <button onClick={() => setPath(p => p.slice(0, -1))} style={{ marginTop: 6, padding: "4px 12px", borderRadius: 8, fontSize: 13, background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer", color: "#475569" }}>↩ Отмена</button>
            </div>
          )}

          {/* Given path for choice/predict */}
          {(task.gtype === "choice" || task.gtype === "predict") && task.path && (
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, color: "#64748b", marginBottom: 6 }}>Алгоритм:</div>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                {(task.path || []).map((s, i) => (
                  <span key={i} style={{ padding: "2px 8px", borderRadius: 6, background: s === "?" ? "#fef3c7" : "#dbeafe", color: s === "?" ? "#92400e" : "#1e40af", fontWeight: 700, fontFamily: "monospace", fontSize: 15 }}>{s}</span>
                ))}
              </div>
            </div>
          )}

          {/* Choice options */}
          {task.gtype === "choice" && (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 8 }}>
              {task.opts.map((opt, i) => (
                <button key={i} onClick={() => { setChosen(i); setChecked(false); }}
                  style={{
                    padding: "12px 8px", borderRadius: 12, fontWeight: 700, fontSize: 15,
                    background: chosen === i ? "#2563eb" : "white",
                    color: chosen === i ? "white" : "#374151",
                    border: `2px solid ${chosen === i ? "#2563eb" : "#e5e7eb"}`,
                    cursor: "pointer", transition: "all 0.2s",
                  }}>{opt}</button>
              ))}
            </div>
          )}

          {/* Predict instruction */}
          {task.gtype === "predict" && (
            <div style={{ fontSize: 13, color: "#475569", padding: "8px 12px", borderRadius: 10, background: "#f8fafc", border: "1px solid #e2e8f0" }}>
              👆 Кликни на клетку сетки, где окажется робот после выполнения алгоритма
            </div>
          )}
        </div>
      </div>

      {isSuccess && <div style={{ borderRadius: 16, padding: 16, textAlign: "center", fontWeight: 800, fontSize: 20, color: "#166534", background: "#dcfce7", border: "2px solid #86efac" }}>🎉 Правильно! Молодец!</div>}
      {checked && !isSuccess && <div style={{ borderRadius: 12, padding: 12, color: "#991b1b", fontSize: 14, background: "#fee2e2" }}>Не совсем верно. Попробуй ещё раз!</div>}
      {showHint && <div style={{ borderRadius: 12, padding: 12, color: "#1e40af", fontSize: 14, background: "#dbeafe" }}>💡 Двигайся по клеточкам шаг за шагом и следи за позицией робота.</div>}

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button onClick={check} disabled={running || (task.gtype === "path" && path.length === 0)}
          style={{ padding: "10px 24px", borderRadius: 12, fontWeight: 700, color: "white", background: "#16a34a", border: "none", cursor: "pointer", fontSize: 15, opacity: (running || (task.gtype === "path" && path.length === 0)) ? 0.5 : 1 }}>
          {task.gtype === "path" ? "▶ Запустить" : "✓ Проверить"}
        </button>
        <button onClick={() => setShowHint(!showHint)} style={{ padding: "10px 16px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>💡</button>
        <button onClick={reset} style={{ padding: "10px 16px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>↺</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// PROGRAMMING TASK — Block + Work Area + Sim
// ─────────────────────────────────────────────

function EV3Block({ block, idx, onParam, onRemove, active, onDragStart, onDragOver, onDrop }) {
  const def = bdef(block.bid) || { l: block.bid, c: "#6b7280", p: [] };
  return (
    <div draggable
      onDragStart={() => onDragStart(idx)}
      onDragOver={e => { e.preventDefault(); onDragOver(idx); }}
      onDrop={() => onDrop(idx)}
      style={{
        flexShrink: 0, borderRadius: 12, padding: "10px 12px", background: def.c,
        minWidth: def.p?.length ? 148 : 110, cursor: "grab", userSelect: "none",
        outline: active ? "3px solid #fbbf24" : "none", outlineOffset: 2,
        transition: "outline 0.1s",
        boxShadow: "0 2px 6px rgba(0,0,0,0.2)",
        position: "relative",
      }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div style={{ flex: 1 }}>
          <div style={{ color: "white", fontSize: 12, fontWeight: 700, lineHeight: 1.3 }}>{def.l}</div>
          {(def.p || []).map(p => (
            <div key={p.k} style={{ display: "flex", alignItems: "center", gap: 4, marginTop: 6 }}>
              <input type="number" min={1} max={999} step={p.k === "deg" ? 45 : 1}
                value={block.pv[p.k] ?? p.d}
                onChange={e => onParam(idx, p.k, +e.target.value)}
                onClick={e => e.stopPropagation()}
                style={{ width: 48, borderRadius: 6, border: "none", textAlign: "center", fontSize: 12, fontWeight: 700, padding: "2px 4px", background: "rgba(255,255,255,0.3)", color: "white" }}
              />
              <span style={{ color: "rgba(255,255,255,0.8)", fontSize: 11 }}>{p.l}</span>
            </div>
          ))}
        </div>
        <button onClick={e => { e.stopPropagation(); onRemove(idx); }}
          style={{ color: "rgba(255,255,255,0.7)", fontWeight: 700, fontSize: 16, background: "none", border: "none", cursor: "pointer", padding: "0 0 0 6px", lineHeight: 1 }}>×</button>
      </div>
      {/* connector dots */}
      <div style={{ position: "absolute", right: -6, top: "50%", transform: "translateY(-50%)", width: 12, height: 12, borderRadius: "50%", background: "rgba(255,255,255,0.5)", border: "2px solid white" }} />
    </div>
  );
}

function ContainerBlock({ block, idx, onParam, onRemove, onAddInner, onRemoveInner, onInnerParam }) {
  const def = bdef(block.bid) || { l: block.bid, c: "#6b7280", p: [] };
  return (
    <div style={{ flexShrink: 0, borderRadius: 12, overflow: "hidden", border: `2px solid ${def.c}`, minWidth: 200 }}>
      <div style={{ padding: "8px 12px", background: def.c, display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ color: "white", fontSize: 12, fontWeight: 700 }}>{def.l}</span>
        {(def.p || []).map(p => (
          <span key={p.k} style={{ display: "flex", alignItems: "center", gap: 4 }}>
            <input type="number" min={1} max={20} value={block.pv[p.k] ?? p.d}
              onChange={e => onParam(idx, p.k, +e.target.value)}
              style={{ width: 40, borderRadius: 6, border: "none", textAlign: "center", fontSize: 12, fontWeight: 700, background: "rgba(255,255,255,0.3)", color: "white" }}
            />
            <span style={{ color: "rgba(255,255,255,0.8)", fontSize: 11 }}>{p.l}</span>
          </span>
        ))}
        <button onClick={() => onRemove(idx)} style={{ marginLeft: "auto", color: "rgba(255,255,255,0.8)", fontWeight: 700, background: "none", border: "none", cursor: "pointer", fontSize: 16 }}>×</button>
      </div>
      <div style={{ padding: "8px", background: "rgba(0,0,0,0.05)", display: "flex", gap: 6, flexWrap: "wrap", minHeight: 52 }}>
        {(block.inner || []).map((ib, ii) => {
          const idef = bdef(ib.bid) || { l: ib.bid, c: "#6b7280", p: [] };
          return (
            <div key={ib.wid} style={{ borderRadius: 8, padding: "6px 10px", background: idef.c, display: "flex", flexDirection: "column", gap: 3 }}>
              <div style={{ color: "white", fontSize: 11, fontWeight: 700 }}>{idef.l}</div>
              {(idef.p || []).map(p => (
                <div key={p.k} style={{ display: "flex", alignItems: "center", gap: 3 }}>
                  <input type="number" min={1} max={100} value={ib.pv[p.k] ?? p.d}
                    onChange={e => onInnerParam(idx, ii, p.k, +e.target.value)}
                    style={{ width: 36, borderRadius: 4, border: "none", textAlign: "center", fontSize: 11, background: "rgba(255,255,255,0.3)", color: "white" }}
                  />
                  <span style={{ color: "rgba(255,255,255,0.8)", fontSize: 10 }}>{p.l}</span>
                </div>
              ))}
              <button onClick={() => onRemoveInner(idx, ii)} style={{ color: "rgba(255,255,255,0.7)", fontSize: 10, background: "none", border: "none", cursor: "pointer", textAlign: "left", padding: 0 }}>× убрать</button>
            </div>
          );
        })}
        <select onChange={e => { if (e.target.value) { onAddInner(idx, e.target.value); e.target.value = ""; } }}
          style={{ fontSize: 11, borderRadius: 8, padding: "4px 8px", border: "1px dashed #94a3b8", background: "white", cursor: "pointer", color: "#64748b" }}>
          <option value="">+ блок внутрь</option>
          {["mfwd", "mbwd", "tr", "tl", "stop", "wait", "beep"].map(id => {
            const d = bdef(id);
            return <option key={id} value={id}>{d?.l}</option>;
          })}
        </select>
      </div>
    </div>
  );
}

function WorkArea({ prog, setProg, activeIdx }) {
  const [dragFrom, setDragFrom] = useState(null);

  function onParam(i, k, v) { setProg(p => { const a = [...p]; a[i] = { ...a[i], pv: { ...a[i].pv, [k]: v } }; return a; }); }
  function onInnerParam(pi, ii, k, v) {
    setProg(p => { const a = [...p]; const inner = [...a[pi].inner]; inner[ii] = { ...inner[ii], pv: { ...inner[ii].pv, [k]: v } }; a[pi] = { ...a[pi], inner }; return a; });
  }
  function onRemove(i) { setProg(p => p.filter((_, j) => j !== i)); }
  function onRemoveInner(pi, ii) { setProg(p => { const a = [...p]; a[pi] = { ...a[pi], inner: a[pi].inner.filter((_, j) => j !== ii) }; return a; }); }
  function onAddInner(pi, bid) {
    const nb = mkWB(bid);
    setProg(p => { const a = [...p]; a[pi] = { ...a[pi], inner: [...a[pi].inner, nb] }; return a; });
  }
  function onDrop(toIdx) {
    if (dragFrom === null || dragFrom === toIdx) return;
    const a = [...prog]; const [el] = a.splice(dragFrom, 1); a.splice(toIdx, 0, el);
    setProg(a); setDragFrom(null);
  }

  return (
    <div style={{ overflowX: "auto", overflowY: "hidden" }}>
      <div
        style={{
          display: "flex", flexDirection: "row", alignItems: "flex-start", gap: 8, padding: "14px 16px",
          minHeight: 100, borderRadius: 12, background: "#f8fafc", border: "2px dashed #cbd5e1",
          minWidth: Math.max(500, prog.length * 168),
        }}
        onDragOver={e => e.preventDefault()}
        onDrop={() => dragFrom !== null && onDrop(Math.max(0, prog.length - 1))}
      >
        {prog.length === 0 && (
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: "100%", color: "#94a3b8", fontSize: 14, fontStyle: "italic" }}>
            ← Кликай на блоки в панели слева, чтобы добавлять их сюда
          </div>
        )}
        {prog.map((block, i) => {
          const def = bdef(block.bid) || {};
          return def.ctr ? (
            <ContainerBlock key={block.wid} block={block} idx={i}
              onParam={onParam} onRemove={onRemove} onAddInner={onAddInner}
              onRemoveInner={onRemoveInner} onInnerParam={onInnerParam} />
          ) : (
            <EV3Block key={block.wid} block={block} idx={i}
              onParam={onParam} onRemove={onRemove}
              active={activeIdx === i}
              onDragStart={setDragFrom}
              onDragOver={() => { }}
              onDrop={onDrop}
            />
          );
        })}
      </div>
    </div>
  );
}

function BlockPalette({ onAdd }) {
  const [openCat, setOpenCat] = useState("movement");
  return (
    <div style={{ width: 162, flexShrink: 0, borderRadius: 12, overflow: "hidden", border: "1px solid #e2e8f0", background: "#f8fafc", alignSelf: "flex-start" }}>
      <div style={{ padding: "10px 12px", background: "#1e293b", color: "white", fontSize: 11, fontWeight: 700, textTransform: "uppercase", letterSpacing: 1 }}>
        Блоки EV3
      </div>
      {CATS.map(cat => (
        <div key={cat.id}>
          <button onClick={() => setOpenCat(openCat === cat.id ? null : cat.id)}
            style={{
              width: "100%", textAlign: "left", padding: "8px 12px", fontWeight: 700, fontSize: 12,
              background: openCat === cat.id ? cat.c : "transparent",
              color: openCat === cat.id ? "white" : "#374151",
              border: "none", borderBottom: "1px solid #e2e8f0", cursor: "pointer",
              display: "flex", alignItems: "center", gap: 6,
            }}>
            <span style={{ fontSize: 10 }}>{openCat === cat.id ? "▼" : "▶"}</span>
            {cat.l}
          </button>
          {openCat === cat.id && (BD[cat.id] || []).map(b => (
            <button key={b.id} onClick={() => onAdd(b.id)}
              style={{
                width: "100%", textAlign: "left", padding: "7px 14px", fontSize: 11, fontWeight: 600,
                background: b.c, color: "white", border: "none",
                borderBottom: "1px solid rgba(255,255,255,0.15)", cursor: "pointer",
                transition: "opacity 0.15s",
              }}
              onMouseEnter={e => e.target.style.opacity = "0.85"}
              onMouseLeave={e => e.target.style.opacity = "1"}
            >{b.l}</button>
          ))}
        </div>
      ))}
    </div>
  );
}

function SimPanel({ field, prog, runTrigger, stepTrigger, onDone }) {
  const [rState, setRState] = useState({ pos: [field.rx, field.ry], di: DORD.indexOf(field.rdir || "right") });
  const [beeping, setBeeping] = useState(false);
  const [result, setResult] = useState(null);
  const [stepIdx, setStepIdx] = useState(0);
  const [allStates, setAllStates] = useState([]);
  const intervalRef = useRef(null);

  const sz = field.sz || 8;
  const CZ = Math.min(50, Math.floor(400 / sz));
  const walls = new Set((field.walls || []).map(w => `${w.x},${w.y}`));
  const trees = new Set((field.trees || []).map(t => `${t.x},${t.y}`));
  const goalMap = {};
  (field.goals || []).forEach(g => { goalMap[`${g.x},${g.y}`] = g.t; });
  const goalEmoji = t => t === "flag" ? "🚩" : t === "house" ? "🏠" : t === "toy" ? "🧸" : "🎯";

  function buildStates() {
    return runSim(prog.map(b => ({ bid: b.bid, pv: b.pv, inner: b.inner })), { sz, rx: field.rx, ry: field.ry, rdir: field.rdir || "right", walls: field.walls || [], trees: field.trees || [] });
  }

  // Full run
  useEffect(() => {
    if (runTrigger === 0) return;
    if (intervalRef.current) clearInterval(intervalRef.current);
    setResult(null);
    const states = buildStates();
    setAllStates(states);
    let i = 0;
    intervalRef.current = setInterval(() => {
      if (i < states.length) {
        const s = states[i];
        setRState({ pos: s.pos, di: s.di });
        if (s.ev === "beep") { setBeeping(true); setTimeout(() => setBeeping(false), 250); }
        i++;
      } else {
        clearInterval(intervalRef.current);
        const last = states[states.length - 1];
        const reached = goalMap[`${last.pos[0]},${last.pos[1]}`] !== undefined;
        setResult(reached ? "success" : "fail");
        onDone(reached);
      }
    }, 320);
    return () => clearInterval(intervalRef.current);
  }, [runTrigger]);

  // Step mode
  useEffect(() => {
    if (stepTrigger === 0) return;
    const states = buildStates();
    setAllStates(states);
    const next = stepIdx + 1;
    if (next < states.length) {
      const s = states[next];
      setRState({ pos: s.pos, di: s.di });
      if (s.ev === "beep") { setBeeping(true); setTimeout(() => setBeeping(false), 250); }
      setStepIdx(next);
    } else {
      const last = states[states.length - 1];
      const reached = goalMap[`${last.pos[0]},${last.pos[1]}`] !== undefined;
      setResult(reached ? "success" : "fail");
      onDone(reached);
    }
  }, [stepTrigger]);

  const dirAngles = { right: 0, down: 90, left: 180, up: 270 };
  const da = dirAngles[DORD[rState.di]] || 0;
  const rx2 = rState.pos[0] * CZ + CZ / 2;
  const ry2 = rState.pos[1] * CZ + CZ / 2;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <div style={{ borderRadius: 12, overflow: "hidden", border: "2px solid #e2e8f0", background: "#f0fdf4", display: "inline-block" }}>
        <svg width={sz * CZ} height={sz * CZ} style={{ display: "block" }}>
          {Array.from({ length: sz }, (_, y) => Array.from({ length: sz }, (_, x) => {
            const key = `${x},${y}`;
            return (
              <g key={key}>
                <rect x={x * CZ} y={y * CZ} width={CZ} height={CZ}
                  fill={walls.has(key) ? "#374151" : trees.has(key) ? "#14532d" : (x + y) % 2 === 0 ? "#f0fdf4" : "#f9fafb"}
                  stroke="#d1d5db" strokeWidth={0.5} />
                {trees.has(key) && <text x={x * CZ + CZ / 2} y={y * CZ + CZ / 2 + 5} textAnchor="middle" fontSize={CZ * 0.52}>🌳</text>}
                {goalMap[key] && <text x={x * CZ + CZ / 2} y={y * CZ + CZ / 2 + 5} textAnchor="middle" fontSize={CZ * 0.58}>{goalEmoji(goalMap[key])}</text>}
              </g>
            );
          }))}
          {/* Robot */}
          <g style={{ transition: "transform 0.28s ease" }} transform={`translate(${rx2},${ry2})`}>
            <g transform={`rotate(${da})`}>
              <circle r={CZ * 0.36} fill={beeping ? "#fbbf24" : "#2563eb"} />
              <circle r={CZ * 0.14} cx={0} cy={0} fill="white" opacity={0.9} />
              <polygon points={`0,${-CZ * 0.29} ${CZ * 0.14},${CZ * 0.12} ${-CZ * 0.14},${CZ * 0.12}`} fill="white" />
            </g>
          </g>
        </svg>
      </div>
      {result === "success" && <div style={{ borderRadius: 10, padding: "8px 12px", background: "#dcfce7", color: "#166534", fontWeight: 700, fontSize: 14, textAlign: "center" }}>🎉 Цель достигнута!</div>}
      {result === "fail" && <div style={{ borderRadius: 10, padding: "8px 12px", background: "#fee2e2", color: "#991b1b", fontSize: 13, textAlign: "center" }}>Робот не добрался до цели. Измени программу!</div>}
    </div>
  );
}

function ProgrammingTask({ task, onSuccess, onHintUsed }) {
  const [prog, setProg] = useState(() =>
    task.pre ? task.pre.map(b => ({ wid: `pre_${b.id}`, bid: b.bid, pv: b.pv || {}, inner: [] })) : []
  );
  const [runTrigger, setRunTrigger] = useState(0);
  const [stepTrigger, setStepTrigger] = useState(0);
  const [showHint, setShowHint] = useState(false);
  const [activeIdx] = useState(null);

  function addBlock(bid) { setProg(p => [...p, mkWB(bid)]); }
  function run() { if (prog.length === 0) return; setRunTrigger(t => t + 1); }
  function step() { setStepTrigger(t => t + 1); }
  function handleDone(reached) { if (reached) { if (prog.length >= 8) {/* badge */ } setTimeout(() => onSuccess(), 900); } }
  const simW = Math.min(440, (task.field.sz || 8) * 50 + 8);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <div style={{ borderRadius: 12, padding: "10px 14px", background: "#fff7ed", border: "1px solid #fed7aa", color: "#7c2d12", fontSize: 14, fontWeight: 500 }}>
        {task.inst}
      </div>

      <div style={{ display: "flex", gap: 12, alignItems: "flex-start", flexWrap: "wrap" }}>
        {/* Block palette */}
        <BlockPalette onAdd={addBlock} />

        {/* Center: work area */}
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 8 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span style={{ fontSize: 11, fontWeight: 700, color: "#64748b", textTransform: "uppercase", letterSpacing: 1 }}>Рабочая зона</span>
            <span style={{ fontSize: 12, color: "#94a3b8" }}>({prog.length} блоков)</span>
          </div>
          <WorkArea prog={prog} setProg={setProg} activeIdx={activeIdx} />

          <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
            <button onClick={run} disabled={prog.length === 0}
              style={{ padding: "10px 20px", borderRadius: 12, fontWeight: 700, color: "white", background: prog.length === 0 ? "#9ca3af" : "#16a34a", border: "none", cursor: prog.length === 0 ? "not-allowed" : "pointer", fontSize: 15 }}>
              ▶ Запустить
            </button>
            <button onClick={step}
              style={{ padding: "10px 16px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>
              ⏭ Шаг
            </button>
            <button onClick={() => { setProg([]); setRunTrigger(0); setStepTrigger(0); }}
              style={{ padding: "10px 16px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>
              ↺ Очистить
            </button>
            <button onClick={() => { setShowHint(!showHint); onHintUsed && onHintUsed(); }}
              style={{ padding: "10px 16px", borderRadius: 12, fontWeight: 600, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>
              💡 Подсказка
            </button>
          </div>
          {showHint && <div style={{ borderRadius: 12, padding: 12, background: "#dbeafe", color: "#1e40af", fontSize: 13 }}>💡 {task.hint}</div>}
        </div>

        {/* Simulator */}
        <div style={{ flexShrink: 0 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: "#64748b", textTransform: "uppercase", letterSpacing: 1, marginBottom: 6 }}>Симулятор</div>
          <SimPanel field={task.field} prog={prog} runTrigger={runTrigger} stepTrigger={stepTrigger} onDone={handleDone} />
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// PAGES
// ─────────────────────────────────────────────

function LandingPage({ onStart, name, setName }) {
  const [inp, setInp] = useState(name || "");
  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 32, padding: 32, background: "linear-gradient(160deg,#eff6ff 0%,#f0fdf4 50%,#fff7ed 100%)" }}>
      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: 72, fontWeight: 900, letterSpacing: -2, lineHeight: 1 }}>
          <span style={{ color: "#1e40af" }}>STEP</span><span style={{ color: "#15803d" }}>CODE</span>
        </div>
        <div style={{ fontSize: 20, color: "#475569", marginTop: 8, fontWeight: 500 }}>Думай. Составляй. Программируй.</div>
      </div>

      <div style={{ fontSize: 80, filter: "drop-shadow(0 6px 16px rgba(0,0,0,0.15))", lineHeight: 1 }}>🤖</div>

      <div style={{ maxWidth: 440, textAlign: "center" }}>
        <p style={{ fontSize: 18, color: "#374151", lineHeight: 1.6, margin: 0 }}>Здесь ты научишься давать роботу задания — <strong>как настоящий инженер!</strong></p>
        <div style={{ display: "flex", justifyContent: "center", gap: 20, marginTop: 16, flexWrap: "wrap" }}>
          {[["🌍", "Жизненные задания"], ["🗺️", "Визуальные алгоритмы"], ["⚙️", "Программирование EV3"]].map(([e, l]) => (
            <div key={l} style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 14, color: "#64748b" }}>
              <span style={{ fontSize: 22 }}>{e}</span>{l}
            </div>
          ))}
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
        <input value={inp} onChange={e => setInp(e.target.value)}
          placeholder="Как тебя зовут?"
          onKeyDown={e => e.key === "Enter" && (setName(inp || "Ученик"), onStart())}
          style={{ padding: "14px 20px", borderRadius: 14, border: "2px solid #bfdbfe", fontSize: 17, fontWeight: 600, textAlign: "center", width: 260, outline: "none", background: "white", boxSizing: "border-box" }}
        />
        <button onClick={() => { setName(inp || "Ученик"); onStart(); }}
          style={{ padding: "16px 48px", borderRadius: 18, fontWeight: 900, color: "white", background: "linear-gradient(135deg,#2563eb,#15803d)", border: "none", cursor: "pointer", fontSize: 18, boxShadow: "0 6px 24px rgba(37,99,235,0.35)" }}>
          Начать приключение →
        </button>
      </div>
    </div>
  );
}

function TopicsPage({ progress, onSelect, name, onNav }) {
  return (
    <div style={{ padding: 24, maxWidth: 900, margin: "0 auto" }}>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 28, fontWeight: 900, color: "#1e293b", margin: 0 }}>Привет, {name}! 👋</h1>
        <p style={{ color: "#64748b", marginTop: 4, fontSize: 15 }}>Выбери тему и начни программировать!</p>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: 16 }}>
        {TOPICS.map((topic, ti) => {
          const tp = progress[topic.id] || {};
          const total = topic.levels.reduce((a, l) => a + l.tasks.length, 0);
          const done = topic.levels.reduce((a, l) => a + (tp[l.id] || []).filter(Boolean).length, 0);
          const prevDone = ti === 0 ? true : (() => {
            const prev = TOPICS[ti - 1];
            const pp = progress[prev.id] || {};
            const prevTotal = prev.levels.reduce((a, l) => a + l.tasks.length, 0);
            const prevDone2 = prev.levels.reduce((a, l) => a + (pp[l.id] || []).filter(Boolean).length, 0);
            return prevDone2 > 0;
          })();
          const isLocked = topic.locked && !prevDone && done === 0;

          return (
            <div key={topic.id} onClick={() => !isLocked && onSelect(topic.id)}
              style={{
                borderRadius: 20, padding: 20, cursor: isLocked ? "not-allowed" : "pointer",
                background: topic.bg, border: `2px solid ${done > 0 ? topic.color + "60" : "#e2e8f0"}`,
                opacity: isLocked ? 0.55 : 1, transition: "transform 0.2s, box-shadow 0.2s",
              }}
              onMouseEnter={e => !isLocked && (e.currentTarget.style.transform = "scale(1.03)", e.currentTarget.style.boxShadow = "0 8px 24px rgba(0,0,0,0.12)")}
              onMouseLeave={e => (e.currentTarget.style.transform = "scale(1)", e.currentTarget.style.boxShadow = "none")}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 12 }}>
                <span style={{ fontSize: 44 }}>{topic.icon}</span>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 4 }}>
                  {done === total && total > 0 && <span style={{ fontSize: 12, fontWeight: 700, color: "#16a34a", background: "#dcfce7", padding: "2px 8px", borderRadius: 20 }}>✓ Пройдена</span>}
                  {isLocked && <span style={{ fontSize: 18 }}>🔒</span>}
                  {done > 0 && done < total && <span style={{ fontSize: 12, fontWeight: 700, color: topic.color }}>В процессе</span>}
                </div>
              </div>
              <div style={{ fontWeight: 800, fontSize: 17, color: "#1e293b", marginBottom: 4 }}>{topic.title}</div>
              <div style={{ color: "#64748b", fontSize: 13, marginBottom: 14, lineHeight: 1.4 }}>{topic.goal}</div>
              <div>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: 12, color: "#94a3b8", marginBottom: 4 }}>
                  <span>Прогресс</span><span>{done}/{total}</span>
                </div>
                <div style={{ height: 6, borderRadius: 99, background: "#e5e7eb" }}>
                  <div style={{ height: 6, borderRadius: 99, background: topic.color, width: `${total ? (done / total) * 100 : 0}%`, transition: "width 0.4s" }} />
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function TopicDetailPage({ topicId, progress, onSelectLevel, onBack }) {
  const topic = TOPICS.find(t => t.id === topicId);
  if (!topic) return null;
  const tp = progress[topicId] || {};

  return (
    <div style={{ padding: 24, maxWidth: 720, margin: "0 auto" }}>
      <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: "#64748b", fontSize: 14, marginBottom: 16, display: "flex", alignItems: "center", gap: 4, padding: 0 }}>← Назад к темам</button>
      <div style={{ borderRadius: 20, padding: "24px 28px", marginBottom: 24, background: topic.bg, border: `2px solid ${topic.color}40` }}>
        <span style={{ fontSize: 52 }}>{topic.icon}</span>
        <h1 style={{ fontSize: 28, fontWeight: 900, color: "#1e293b", margin: "12px 0 6px" }}>{topic.title}</h1>
        <p style={{ color: "#475569", margin: 0, fontSize: 15 }}>{topic.goal}</p>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {topic.levels.map((level, li) => {
          const lp = tp[level.id] || [];
          const done = lp.filter(Boolean).length;
          const total = level.tasks.length;
          const isUnlocked = li === 0 || (tp[topic.levels[li - 1]?.id] || []).filter(Boolean).length === topic.levels[li - 1]?.tasks.length;
          const isDone = done === total;

          return (
            <div key={level.id} onClick={() => isUnlocked && onSelectLevel(topicId, level.id)}
              style={{
                borderRadius: 16, padding: "18px 22px", cursor: isUnlocked ? "pointer" : "not-allowed",
                background: "white", border: `2px solid ${isDone ? level.color : isUnlocked ? "#e2e8f0" : "#f1f5f9"}`,
                opacity: isUnlocked ? 1 : 0.5, transition: "border-color 0.2s, box-shadow 0.2s",
              }}
              onMouseEnter={e => isUnlocked && (e.currentTarget.style.boxShadow = "0 4px 16px rgba(0,0,0,0.1)")}
              onMouseLeave={e => (e.currentTarget.style.boxShadow = "none")}
            >
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <span style={{ fontWeight: 900, fontSize: 22, color: level.color }}>Уровень {li + 1}</span>
                    {!isUnlocked && <span>🔒</span>}
                    {isDone && <span style={{ fontSize: 18 }}>✓</span>}
                  </div>
                  <div style={{ fontWeight: 700, fontSize: 16, color: "#374151" }}>{level.title}</div>
                  <div style={{ fontSize: 13, color: "#94a3b8", marginTop: 2 }}>{total} задания</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <div style={{ fontSize: 28, fontWeight: 900, color: level.color }}>{done}/{total}</div>
                  <div style={{ display: "flex", gap: 6, marginTop: 4 }}>
                    {level.tasks.map((_, i) => (
                      <div key={i} style={{ width: 14, height: 14, borderRadius: "50%", background: lp[i] ? level.color : "#e5e7eb" }} />
                    ))}
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function LevelTasksPage({ topicId, levelId, taskIdx, progress, onComplete, onBack, onGoToTask }) {
  const topic = TOPICS.find(t => t.id === topicId);
  const level = topic?.levels.find(l => l.id === levelId);

  if (!topic || !level) return null;
  const lp = (progress[topicId] || {})[levelId] || [];

  return (
    <div style={{ padding: 24, maxWidth: 420, margin: "0 auto" }}>
      <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: "#64748b", fontSize: 14, marginBottom: 16, padding: 0 }}>← Назад к теме</button>
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 12, color: "#94a3b8", marginBottom: 4 }}>{topic.title}</div>
        <h2 style={{ fontSize: 22, fontWeight: 900, color: level.color, margin: 0 }}>{level.title}</h2>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {level.tasks.map((task, i) => {
          const isDone = lp[i];
          const isNext = !isDone && (i === 0 || lp[i - 1]);
          return (
            <div key={task.id} onClick={() => onGoToTask(topicId, levelId, i)}
              style={{
                borderRadius: 14, padding: "16px 20px", cursor: "pointer",
                background: isDone ? "#dcfce7" : isNext ? "white" : "#f9fafb",
                border: `2px solid ${isDone ? "#86efac" : isNext ? level.color : "#e5e7eb"}`,
                transition: "all 0.2s",
              }}
              onMouseEnter={e => (e.currentTarget.style.boxShadow = "0 4px 12px rgba(0,0,0,0.1)")}
              onMouseLeave={e => (e.currentTarget.style.boxShadow = "none")}
            >
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div>
                  <div style={{ fontWeight: 600, fontSize: 13, color: "#94a3b8", marginBottom: 2 }}>Задание {i + 1}</div>
                  <div style={{ fontWeight: 700, fontSize: 16, color: "#1e293b" }}>{task.title}</div>
                  <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                    {task.comp.map(c => <span key={c} style={{ fontSize: 10, fontWeight: 600, padding: "2px 7px", borderRadius: 10, background: "#f1f5f9", color: "#64748b" }}>{c}</span>)}
                  </div>
                </div>
                <span style={{ fontSize: 24 }}>{isDone ? "✅" : isNext ? "▶️" : "⭕"}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function TaskPage({ topicId, levelId, taskIdx, progress, onComplete, onBack, onNext }) {
  const topic = TOPICS.find(t => t.id === topicId);
  const level = topic?.levels.find(l => l.id === levelId);
  const task = level?.tasks[taskIdx];
  const [done, setDone] = useState(false);

  if (!topic || !level || !task) return null;
  const lp = (progress[topicId] || {})[levelId] || [];
  const alreadyDone = lp[taskIdx];

  function handleSuccess() {
    setDone(true);
    onComplete(topicId, levelId, taskIdx);
  }

  return (
    <div style={{ padding: "16px 20px", maxWidth: 1100, margin: "0 auto" }}>
      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 12 }}>
        <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: "#64748b", fontSize: 14, padding: 0 }}>← Назад</button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 12, color: "#94a3b8" }}>{topic.title} → {level.title}</div>
          <div style={{ fontWeight: 800, fontSize: 18, color: "#1e293b" }}>{task.title}</div>
        </div>
        <div style={{ display: "flex", gap: 5 }}>
          {level.tasks.map((_, i) => (
            <div key={i} style={{ width: 10, height: 10, borderRadius: "50%", background: lp[i] ? level.color : i === taskIdx ? level.color + "80" : "#e5e7eb" }} />
          ))}
        </div>
      </div>

      {/* Component tags */}
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap", marginBottom: 14 }}>
        {task.comp.map(c => <span key={c} style={{ fontSize: 12, fontWeight: 600, padding: "3px 10px", borderRadius: 12, background: "#f1f5f9", color: "#475569", border: "1px solid #e2e8f0" }}>{c}</span>)}
      </div>

      {/* Success banner */}
      {done && !alreadyDone && (
        <div style={{ borderRadius: 18, padding: "20px 24px", marginBottom: 16, textAlign: "center", background: "#dcfce7", border: "2px solid #86efac" }}>
          <div style={{ fontSize: 48, marginBottom: 8 }}>🎉</div>
          <div style={{ fontWeight: 900, fontSize: 22, color: "#166534" }}>Задание выполнено!</div>
          <div style={{ display: "flex", gap: 10, justifyContent: "center", marginTop: 12 }}>
            {taskIdx < level.tasks.length - 1 && (
              <button onClick={() => onNext(topicId, levelId, taskIdx + 1)}
                style={{ padding: "10px 24px", borderRadius: 12, fontWeight: 700, color: "white", background: level.color, border: "none", cursor: "pointer" }}>
                Следующее задание →
              </button>
            )}
            <button onClick={onBack} style={{ padding: "10px 24px", borderRadius: 12, fontWeight: 700, color: "#475569", background: "#f1f5f9", border: "1px solid #e2e8f0", cursor: "pointer" }}>
              ← К списку заданий
            </button>
          </div>
        </div>
      )}

      {/* Task content */}
      {level.type === "seq" && <SequenceTask key={task.id} task={task} onSuccess={handleSuccess} />}
      {level.type === "grid" && <GridTask key={task.id} task={task} onSuccess={handleSuccess} />}
      {level.type === "prog" && <ProgrammingTask key={task.id} task={task} onSuccess={handleSuccess} />}
    </div>
  );
}

function ProgressPage({ progress, name, onBack, badges }) {
  const total = TOPICS.reduce((a, t) => a + t.levels.reduce((b, l) => b + l.tasks.length, 0), 0);
  const done = TOPICS.reduce((a, t) => {
    const tp = progress[t.id] || {};
    return a + t.levels.reduce((b, l) => b + (tp[l.id] || []).filter(Boolean).length, 0);
  }, 0);

  return (
    <div style={{ padding: 24, maxWidth: 700, margin: "0 auto" }}>
      <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: "#64748b", fontSize: 14, marginBottom: 16, padding: 0 }}>← Назад</button>

      <div style={{ borderRadius: 20, padding: "24px 28px", marginBottom: 24, background: "#eff6ff", border: "2px solid #bfdbfe", display: "flex", alignItems: "center", gap: 20 }}>
        <span style={{ fontSize: 64 }}>🤖</span>
        <div>
          <div style={{ fontWeight: 900, fontSize: 26, color: "#1e293b" }}>{name}</div>
          <div style={{ color: "#64748b", marginTop: 2 }}>Программист 2 класса</div>
          <div style={{ marginTop: 8, fontWeight: 700, fontSize: 16, color: "#2563eb" }}>{done} / {total} заданий выполнено</div>
          <div style={{ marginTop: 6, height: 8, borderRadius: 99, background: "#dbeafe", width: 200 }}>
            <div style={{ height: 8, borderRadius: 99, background: "#2563eb", width: `${(done / total) * 100}%`, transition: "width 0.4s" }} />
          </div>
        </div>
      </div>

      {/* Topics */}
      <h2 style={{ fontSize: 18, fontWeight: 800, color: "#1e293b", marginBottom: 12 }}>По темам</h2>
      <div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 24 }}>
        {TOPICS.map(topic => {
          const tp = progress[topic.id] || {};
          const ttotal = topic.levels.reduce((a, l) => a + l.tasks.length, 0);
          const tdone = topic.levels.reduce((a, l) => a + (tp[l.id] || []).filter(Boolean).length, 0);
          return (
            <div key={topic.id} style={{ borderRadius: 14, padding: "14px 18px", background: topic.bg, border: `1px solid ${topic.color}30` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                <span style={{ fontWeight: 700, color: "#1e293b" }}>{topic.icon} {topic.title}</span>
                <span style={{ fontWeight: 700, color: topic.color, fontFamily: "monospace" }}>{tdone}/{ttotal}</span>
              </div>
              <div style={{ height: 6, borderRadius: 99, background: "#e5e7eb" }}>
                <div style={{ height: 6, borderRadius: 99, background: topic.color, width: `${ttotal ? (tdone / ttotal) * 100 : 0}%` }} />
              </div>
            </div>
          );
        })}
      </div>

      {/* Badges */}
      <h2 style={{ fontSize: 18, fontWeight: 800, color: "#1e293b", marginBottom: 12 }}>Бейджи</h2>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: 10 }}>
        {BADGE_DEFS.map(b => {
          const earned = badges.includes(b.id);
          return (
            <div key={b.id} style={{ borderRadius: 14, padding: "14px 12px", textAlign: "center", background: earned ? b.c + "18" : "#f9fafb", border: `1.5px solid ${earned ? b.c : "#e5e7eb"}`, opacity: earned ? 1 : 0.4 }}>
              <div style={{ fontSize: 30, marginBottom: 6 }}>{b.icon}</div>
              <div style={{ fontWeight: 700, fontSize: 13, color: "#1e293b" }}>{b.title}</div>
              <div style={{ fontSize: 11, color: "#64748b", marginTop: 2, lineHeight: 1.3 }}>{b.desc}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function TeacherPage({ onBack, token, currentUser }) {
  const [students, setStudents] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (currentUser?.role !== 'teacher' || !token) return;
    setLoading(true);
    Promise.all([
      fetch('/api/teacher/students', { headers: { Authorization: `Bearer ${token}` } }).then(r => r.json()),
      fetch('/api/teacher/stats',    { headers: { Authorization: `Bearer ${token}` } }).then(r => r.json()),
    ]).then(([s, st]) => { setStudents(Array.isArray(s) ? s : []); setStats(st); })
      .finally(() => setLoading(false));
  }, [token, currentUser]);

  const TOTAL_TASKS = 45; // 5 topics × 3 levels × 3 tasks

  // Keep using original for non-teachers
  if (currentUser?.role !== 'teacher') {
  const rows = [];
  TOPICS.forEach(topic => {
    topic.levels.forEach((level, li) => {
      level.tasks.forEach((task, ti) => {
        rows.push({ topic: topic.title, topicColor: topic.color, level: `Ур.${li + 1}: ${level.title}`, task: task.title, comp: task.comp, type: level.type });
      });
    });
  });
  const typeLabel = { seq: "Жизненная ситуация", grid: "Визуальный алгоритм", prog: "Программирование EV3" };
  const typeColor = { seq: "#2563eb", grid: "#16a34a", prog: "#f97316" };

  }  // end non-teacher early return

  return (
    <div style={{ padding: 24, maxWidth: 1000, margin: "0 auto" }}>
      <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: "#64748b", fontSize: 14, marginBottom: 16, padding: 0 }}>← Назад</button>
      <h1 style={{ fontSize: 24, fontWeight: 900, color: "#1e293b", marginBottom: 4 }}>Раздел для учителя</h1>
      <p style={{ color: "#64748b", marginBottom: 20, fontSize: 14 }}>
        Класс: <strong>{currentUser?.classCode}</strong> · Методическая карта + живая аналитика
      </p>

      {/* ── Live class dashboard ── */}
      {loading && <div style={{ color: '#64748b', marginBottom: 16 }}>Загрузка данных класса...</div>}
      {!loading && stats && (
        <div style={{ marginBottom: 28 }}>
          {/* Summary cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(140px,1fr))', gap: 12, marginBottom: 20 }}>
            {[
              { label: 'Учеников в классе', value: stats.studentCount, color: '#2563eb' },
              { label: 'Выполнено заданий', value: stats.totalCompleted, color: '#16a34a' },
              { label: 'Всего заданий', value: TOTAL_TASKS, color: '#64748b' },
            ].map(c => (
              <div key={c.label} style={{ borderRadius: 14, padding: '14px 16px', background: 'white', border: `1.5px solid ${c.color}30`, textAlign: 'center' }}>
                <div style={{ fontSize: 30, fontWeight: 900, color: c.color }}>{c.value ?? '—'}</div>
                <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>{c.label}</div>
              </div>
            ))}
          </div>

          {/* Student list */}
          {students.length > 0 && (
            <div style={{ borderRadius: 14, overflow: 'hidden', border: '1px solid #e2e8f0', marginBottom: 20 }}>
              <div style={{ background: '#1e293b', padding: '10px 16px', color: 'white', fontWeight: 700, fontSize: 14 }}>
                👦 Ученики класса {currentUser?.classCode}
              </div>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
                <thead>
                  <tr style={{ background: '#f8fafc' }}>
                    {['Ученик', 'Заданий выполнено', 'Прогресс', 'Подсказок'].map(h => (
                      <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontWeight: 700, color: '#475569', borderBottom: '2px solid #e2e8f0' }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {students.map((s, i) => (
                    <tr key={s.id} style={{ background: i % 2 === 0 ? 'white' : '#f9fafb', borderBottom: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '10px 14px', fontWeight: 600 }}>{s.name}</td>
                      <td style={{ padding: '10px 14px', fontWeight: 700, color: '#16a34a' }}>{s.tasks_done} / {TOTAL_TASKS}</td>
                      <td style={{ padding: '10px 14px' }}>
                        <div style={{ height: 8, borderRadius: 99, background: '#e5e7eb', width: 120 }}>
                          <div style={{ height: 8, borderRadius: 99, background: '#16a34a', width: `${(s.tasks_done / TOTAL_TASKS) * 100}%` }} />
                        </div>
                      </td>
                      <td style={{ padding: '10px 14px', color: s.total_hints > 5 ? '#f97316' : '#64748b' }}>{s.total_hints}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {students.length === 0 && !loading && (
            <div style={{ borderRadius: 12, padding: 20, background: '#f8fafc', border: '1px dashed #e2e8f0', textAlign: 'center', color: '#94a3b8', marginBottom: 20 }}>
              Пока никто из учеников не вошёл в систему с кодом <strong>{currentUser?.classCode}</strong>
            </div>
          )}
        </div>
      )}

      <div style={{ overflowX: "auto", borderRadius: 14, border: "1px solid #e2e8f0", marginBottom: 24 }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
          <thead>
            <tr style={{ background: "#f8fafc" }}>
              {["Тема", "Уровень", "Задание", "Компоненты АМ", "Тип"].map(h => (
                <th key={h} style={{ padding: "12px 14px", textAlign: "left", fontWeight: 700, color: "#475569", borderBottom: "2px solid #e2e8f0", whiteSpace: "nowrap" }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, i) => (
              <tr key={i} style={{ background: i % 2 === 0 ? "white" : "#f9fafb", borderBottom: "1px solid #f1f5f9" }}>
                <td style={{ padding: "10px 14px", fontWeight: 600, color: row.topicColor }}>{row.topic}</td>
                <td style={{ padding: "10px 14px", color: "#64748b", whiteSpace: "nowrap" }}>{row.level}</td>
                <td style={{ padding: "10px 14px", color: "#1e293b" }}>{row.task}</td>
                <td style={{ padding: "10px 14px" }}>
                  <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
                    {row.comp.map(c => <span key={c} style={{ fontSize: 11, fontWeight: 600, padding: "2px 8px", borderRadius: 10, background: "#dbeafe", color: "#1e40af" }}>{c}</span>)}
                  </div>
                </td>
                <td style={{ padding: "10px 14px" }}>
                  <span style={{ fontSize: 11, fontWeight: 700, padding: "3px 10px", borderRadius: 10, background: typeColor[row.type] + "18", color: typeColor[row.type] }}>{typeLabel[row.type]}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
        <div style={{ borderRadius: 14, padding: 18, background: "#eff6ff", border: "1px solid #bfdbfe" }}>
          <h3 style={{ fontWeight: 800, color: "#1e40af", marginBottom: 10 }}>Методические рекомендации</h3>
          <ul style={{ margin: 0, paddingLeft: 18, color: "#1e40af", fontSize: 13, lineHeight: 2 }}>
            <li>Уровень 1 — обсуждать фронтально в классе</li>
            <li>Уровень 2 — рекомендуется работа в парах</li>
            <li>Уровень 3 — индивидуальная работа за ПК</li>
            <li>Подсказки — педагогический инструмент</li>
            <li>Бейджи можно включить в портфолио</li>
          </ul>
        </div>
        <div style={{ borderRadius: 14, padding: 18, background: "#f0fdf4", border: "1px solid #bbf7d0" }}>
          <h3 style={{ fontWeight: 800, color: "#15803d", marginBottom: 10 }}>5 компонентов АМ</h3>
          <ul style={{ margin: 0, paddingLeft: 18, color: "#15803d", fontSize: 13, lineHeight: 2 }}>
            <li><b>Последовательность</b> — правильный порядок</li>
            <li><b>Декомпозиция</b> — разбивка задачи</li>
            <li><b>Составление алгоритма</b> — инструкция</li>
            <li><b>Условные конструкции</b> — если…то…</li>
            <li><b>Поиск ошибок</b> — отладка</li>
          </ul>
        </div>
      </div>
    </div>
  );
}


// ─────────────────────────────────────────────
// LOGIN PAGE
// ─────────────────────────────────────────────
function LoginPage({ onLogin }) {
  const [uname, setUname] = useState('');
  const [classCode, setClassCode] = useState('');
  const [role, setRole] = useState('student');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleJoin() {
    if (!uname.trim() || !classCode.trim()) { setError('Заполни имя и код класса'); return; }
    setLoading(true); setError('');
    try {
      const res = await fetch('/api/auth/join', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: uname.trim(), classCode: classCode.trim().toUpperCase(), role }),
      });
      const data = await res.json();
      if (data.token) {
        localStorage.setItem('sc_token', data.token);
        onLogin(data.token, data.user);
      } else {
        setError(data.error || 'Ошибка входа');
      }
    } catch {
      setError('Сервер недоступен. Убедись, что backend запущен (npm run dev).');
    }
    setLoading(false);
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'linear-gradient(160deg,#eff6ff 0%,#f0fdf4 50%,#fff7ed 100%)' }}>
      <div style={{ background: 'white', borderRadius: 24, padding: '40px 44px', width: 360, boxShadow: '0 8px 32px rgba(0,0,0,0.12)' }}>
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ fontSize: 52, marginBottom: 8 }}>🤖</div>
          <div style={{ fontSize: 28, fontWeight: 900 }}>
            <span style={{ color: '#1e40af' }}>STEP</span><span style={{ color: '#15803d' }}>CODE</span>
          </div>
          <div style={{ color: '#64748b', fontSize: 14, marginTop: 4 }}>Войди, чтобы сохранять прогресс</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <label style={{ fontSize: 13, fontWeight: 600, color: '#374151', display: 'block', marginBottom: 4 }}>Твоё имя</label>
            <input value={uname} onChange={e => setUname(e.target.value)} placeholder="Например: Миша Иванов"
              onKeyDown={e => e.key === 'Enter' && handleJoin()}
              style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '2px solid #e2e8f0', fontSize: 15, outline: 'none', boxSizing: 'border-box' }}
              onFocus={e => (e.target.style.borderColor = '#2563eb')}
              onBlur={e => (e.target.style.borderColor = '#e2e8f0')} />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 600, color: '#374151', display: 'block', marginBottom: 4 }}>Код класса</label>
            <input value={classCode} onChange={e => setClassCode(e.target.value.toUpperCase())} placeholder="Спроси у учителя"
              onKeyDown={e => e.key === 'Enter' && handleJoin()}
              style={{ width: '100%', padding: '10px 14px', borderRadius: 10, border: '2px solid #e2e8f0', fontSize: 15, outline: 'none', boxSizing: 'border-box', letterSpacing: 2, fontWeight: 700 }}
              onFocus={e => (e.target.style.borderColor = '#2563eb')}
              onBlur={e => (e.target.style.borderColor = '#e2e8f0')} />
          </div>
          <div>
            <label style={{ fontSize: 13, fontWeight: 600, color: '#374151', display: 'block', marginBottom: 6 }}>Я:</label>
            <div style={{ display: 'flex', gap: 8 }}>
              {[['student', '👦 Ученик'], ['teacher', '👩‍🏫 Учитель']].map(([r, l]) => (
                <button key={r} onClick={() => setRole(r)}
                  style={{ flex: 1, padding: 9, borderRadius: 10, fontWeight: 700, fontSize: 14, background: role === r ? '#2563eb' : '#f1f5f9', color: role === r ? 'white' : '#374151', border: `2px solid ${role === r ? '#2563eb' : '#e2e8f0'}`, cursor: 'pointer' }}>
                  {l}
                </button>
              ))}
            </div>
          </div>
          {error && <div style={{ color: '#dc2626', fontSize: 13, background: '#fee2e2', padding: '8px 12px', borderRadius: 8 }}>{error}</div>}
          <button onClick={handleJoin} disabled={loading}
            style={{ padding: 13, borderRadius: 12, fontWeight: 800, color: 'white', background: '#2563eb', border: 'none', cursor: loading ? 'not-allowed' : 'pointer', fontSize: 16, marginTop: 4, opacity: loading ? 0.7 : 1 }}>
            {loading ? 'Входим...' : '→ Войти'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────
function Header({ nav, onNav, name, onLogout, currentUser }) {
  const navItems = [
    { id: "topics", label: "Темы", icon: "📚" },
    { id: "progress", label: "Мои успехи", icon: "🏆" },
    { id: "teacher", label: "Учителю", icon: "📋" },
  ];
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 20px", background: "white", borderBottom: "1px solid #e2e8f0", position: "sticky", top: 0, zIndex: 100 }}>
      <button onClick={() => onNav("landing")} style={{ fontWeight: 900, fontSize: 20, background: "none", border: "none", cursor: "pointer", letterSpacing: -1 }}>
        <span style={{ color: "#1e40af" }}>STEP</span><span style={{ color: "#15803d" }}>CODE</span>
      </button>
      <div style={{ flex: 1 }} />
      {navItems.map(item => (
        <button key={item.id} onClick={() => onNav(item.id)}
          style={{ padding: "6px 14px", borderRadius: 10, fontSize: 13, fontWeight: 600, border: "1px solid transparent", background: nav === item.id ? "#eff6ff" : "transparent", color: nav === item.id ? "#2563eb" : "#64748b", borderColor: nav === item.id ? "#bfdbfe" : "transparent", cursor: "pointer" }}>
          {item.icon} {item.label}
        </button>
      ))}
      {name && (
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginLeft: 6, borderLeft: "1px solid #e2e8f0", paddingLeft: 12 }}>
          <span style={{ fontSize: 13, color: "#475569", fontWeight: 600 }}>
            {currentUser?.role === 'teacher' ? '👩‍🏫' : '👦'} {name}
          </span>
          {currentUser?.classCode && (
            <span style={{ fontSize: 11, color: "#94a3b8", background: "#f1f5f9", padding: "2px 8px", borderRadius: 8, fontWeight: 700, letterSpacing: 1 }}>{currentUser.classCode}</span>
          )}
          <button onClick={onLogout} style={{ fontSize: 12, color: "#94a3b8", background: "none", border: "1px solid #e2e8f0", borderRadius: 8, padding: "3px 10px", cursor: "pointer" }}>Выйти</button>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────
// MAIN APP
// ─────────────────────────────────────────────
export default function StepCode() {
  // ── Auth state ──
  const [token, setToken] = useState(() => localStorage.getItem('sc_token') || null);
  const [currentUser, setCurrentUser] = useState(null);
  const [authReady, setAuthReady] = useState(false);

  // ── App state ──
  const [page, setPage] = useState("landing");
  const [name, setName] = useState("");
  const [topicId, setTopicId] = useState(null);
  const [levelId, setLevelId] = useState(null);
  const [taskIdx, setTaskIdx] = useState(0);
  const [progress, setProgress] = useState({});
  const [badges, setBadges] = useState([]);
  const [hintStreak, setHintStreak] = useState(0);

  // ── Check stored token on mount ──
  useEffect(() => {
    const stored = localStorage.getItem('sc_token');
    if (!stored) { setAuthReady(true); return; }
    fetch('/api/auth/me', { headers: { Authorization: `Bearer ${stored}` } })
      .then(r => r.ok ? r.json() : null)
      .then(user => {
        if (user) {
          setCurrentUser(user); setToken(stored); setName(user.name);
          return fetch('/api/progress', { headers: { Authorization: `Bearer ${stored}` } })
            .then(r => r.ok ? r.json() : {})
            .then(p => setProgress(p || {}));
        } else {
          localStorage.removeItem('sc_token'); setToken(null);
        }
      })
      .catch(() => { localStorage.removeItem('sc_token'); setToken(null); })
      .finally(() => setAuthReady(true));
  }, []);

  function handleLogin(tok, user) {
    setToken(tok); setCurrentUser(user); setName(user.name);
    fetch('/api/progress', { headers: { Authorization: `Bearer ${tok}` } })
      .then(r => r.ok ? r.json() : {}).then(p => setProgress(p || {}));
  }

  function handleLogout() {
    if (token) fetch('/api/auth/logout', { method: 'POST', headers: { Authorization: `Bearer ${token}` } });
    localStorage.removeItem('sc_token');
    setToken(null); setCurrentUser(null); setProgress({}); setBadges([]); setPage('landing');
  }

  function completeTask(tid, lid, tidx) {
    // Save to API
    if (token) {
      fetch('/api/progress', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ topicId: tid, levelId: lid, taskIdx: tidx }),
      });
    }
    setProgress(prev => {
      const tp = { ...(prev[tid] || {}) };
      const lp = [...(tp[lid] || [])];
      lp[tidx] = true;
      tp[lid] = lp;
      const np = { ...prev, [tid]: tp };

      // Award badges
      const newBadges = new Set(badges);
      const totalDone = Object.values(np).reduce((a, t) => a + Object.values(t).reduce((b, l) => b + l.filter(Boolean).length, 0), 0);
      if (totalDone >= 1) newBadges.add("first");

      // Check master badge
      const topic = TOPICS.find(t => t.id === tid);
      if (topic) {
        const allLevelsDone = topic.levels.every(l => (tp[l.id] || []).filter(Boolean).length === l.tasks.length);
        if (allLevelsDone) newBadges.add("master");
      }

      // Explorer badge
      const allTopicsDone = TOPICS.every(t => {
        const pp = np[t.id] || {};
        return t.levels.every(l => (pp[l.id] || []).filter(Boolean).length === l.tasks.length);
      });
      if (allTopicsDone) newBadges.add("explorer");

      if (newBadges.size > badges.length) setBadges([...newBadges]);
      return np;
    });
  }

  const showHeader = page !== "landing";

  if (!authReady) return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#eff6ff' }}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 56, marginBottom: 12 }}>🤖</div>
        <div style={{ fontSize: 16, color: '#64748b' }}>Загрузка...</div>
      </div>
    </div>
  );

  if (!token) return <LoginPage onLogin={handleLogin} />;

  return (
    <div style={{ minHeight: "100vh", background: "#fafafa", fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" }}>
      {showHeader && <Header nav={page} onNav={p => setPage(p)} name={name} onLogout={handleLogout} currentUser={currentUser} />}

      {page === "landing" && (
        <LandingPage onStart={() => setPage("topics")} name={name} setName={setName} />
      )}

      {page === "topics" && (
        <TopicsPage progress={progress} name={name || "Ученик"}
          onSelect={tid => { setTopicId(tid); setPage("topicDetail"); }}
          onNav={setPage}
        />
      )}

      {page === "topicDetail" && topicId && (
        <TopicDetailPage topicId={topicId} progress={progress}
          onSelectLevel={(tid, lid) => { setTopicId(tid); setLevelId(lid); setPage("levelTasks"); }}
          onBack={() => setPage("topics")}
        />
      )}

      {page === "levelTasks" && topicId && levelId && (
        <LevelTasksPage topicId={topicId} levelId={levelId} taskIdx={taskIdx} progress={progress}
          onComplete={completeTask}
          onBack={() => setPage("topicDetail")}
          onGoToTask={(tid, lid, idx) => { setTopicId(tid); setLevelId(lid); setTaskIdx(idx); setPage("task"); }}
        />
      )}

      {page === "task" && topicId && levelId && (
        <TaskPage topicId={topicId} levelId={levelId} taskIdx={taskIdx} progress={progress}
          onComplete={completeTask}
          onBack={() => setPage("levelTasks")}
          onNext={(tid, lid, idx) => { setTopicId(tid); setLevelId(lid); setTaskIdx(idx); }}
        />
      )}

      {page === "progress" && (
        <ProgressPage progress={progress} name={name || "Ученик"} badges={badges} onBack={() => setPage("topics")} />
      )}

      {page === "teacher" && (
        <TeacherPage onBack={() => setPage("topics")} token={token} currentUser={currentUser} />
      )}
    </div>
  );
}
