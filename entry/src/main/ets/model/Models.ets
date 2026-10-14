/**
 * 数据模型 + 业务工具：学期课表与冲突检测
 */

/** 一门课程 */
export interface Course {
  id: string;
  name: string;         // 课程名称
  teacher: string;      // 教师
  location: string;     // 教室
  day: number;          // 星期：1=周一 ... 7=周日
  startSection: number; // 开始节次
  endSection: number;   // 结束节次
  startWeek: number;    // 起始周
  endWeek: number;      // 结束周
  colorIndex: number;   // 配色下标
  note: string;         // 备注
}

/** 待办事项 */
export interface TodoItem {
  id: string;
  title: string;
  done: boolean;
  courseId: string;     // 关联课程（可空）
  createdAt: number;
}

/** 每学期周数（可在界面上调整） */
export const DEFAULT_TOTAL_WEEKS: number = 20;

/** 每天节次数 */
export const SECTIONS_PER_DAY: number = 12;

/** 星期名称 */
export const DAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/** 节次上课时间（用于左侧节次栏展示） */
export const SECTION_TIMES: string[] = [
  '08:00', '08:55', '10:00', '10:55',
  '13:30', '14:25', '15:20', '16:15',
  '18:30', '19:25', '20:20', '21:15'
];

/** 课程卡片背景色（浅色，配合深色文字） */
export const COURSE_BG: string[] = [
  '#E8F0FE', '#E6F4EA', '#FEF7E0', '#F3E8FD',
  '#E4F7FB', '#FDECEF', '#EAF3DE', '#FFF1E6'
];

/** 课程卡片描边色 */
export const COURSE_LINE: string[] = [
  '#A8C7FA', '#A8DAB5', '#F5C26B', '#D0A8F5',
  '#8FD5E5', '#F5A8B8', '#BBD98B', '#F5C08F'
];

/** 课程卡片文字色 */
export const COURSE_FG: string[] = [
  '#174EA6', '#1E6C3A', '#8A5A00', '#6A2FA6',
  '#0B6B7A', '#A3203A', '#3F6B0F', '#A85B12'
];

/** 冲突高亮色 */
export const CONFLICT_BG: string = '#FFECEC';
export const CONFLICT_LINE: string = '#E5484D';
export const CONFLICT_FG: string = '#B42318';

/** 生成唯一 id */
export function nextId(prefix: string): string {
  return prefix + '_' + Date.now().toString() + '_' + Math.floor(Math.random() * 100000).toString();
}

/** 周次显示："1-16周" / "单周" 等 */
export function formatWeeks(startWeek: number, endWeek: number): string {
  if (startWeek === endWeek) {
    return '第' + startWeek + '周';
  }
  return startWeek + '-' + endWeek + '周';
}

/** 节次显示："1-2节" */
export function formatSections(startSection: number, endSection: number): string {
  if (startSection === endSection) {
    return startSection + '节';
  }
  return startSection + '-' + endSection + '节';
}

/** 判断两门课的周次是否重叠 */
export function weeksOverlap(a: Course, b: Course): boolean {
  return a.startWeek <= b.endWeek && b.startWeek <= a.endWeek;
}

/** 判断两门课的节次是否重叠 */
export function sectionsOverlap(a: Course, b: Course): boolean {
  return a.startSection <= b.endSection && b.startSection <= a.endSection;
}

/** 判断两门课是否冲突（同一天 + 节次重叠 + 周次重叠） */
export function isConflictPair(a: Course, b: Course): boolean {
  if (a.id === b.id) {
    return false;
  }
  if (a.day !== b.day) {
    return false;
  }
  return sectionsOverlap(a, b) && weeksOverlap(a, b);
}

/**
 * 冲突检测：返回存在冲突的课程 id 列表（去重）
 */
export function detectConflictIds(courses: Course[]): string[] {
  const ids: string[] = [];
  for (let i = 0; i < courses.length; i++) {
    for (let j = i + 1; j < courses.length; j++) {
      if (isConflictPair(courses[i], courses[j])) {
        if (!ids.includes(courses[i].id)) {
          ids.push(courses[i].id);
        }
        if (!ids.includes(courses[j].id)) {
          ids.push(courses[j].id);
        }
      }
    }
  }
  return ids;
}

/** 冲突对数量 */
export function countConflictPairs(courses: Course[]): number {
  let count = 0;
  for (let i = 0; i < courses.length; i++) {
    for (let j = i + 1; j < courses.length; j++) {
      if (isConflictPair(courses[i], courses[j])) {
        count++;
      }
    }
  }
  return count;
}

/** 今天对应的星期（1=周一 ... 7=周日） */
export function todayWeekday(): number {
  const d = new Date().getDay(); // 0=周日
  return d === 0 ? 7 : d;
}

/** 把 "周一"/"星期一"/"礼拜一"/"1"/"mon" 解析为 1-7，失败返回 -1 */
export function parseDay(token: string): number {
  const t = token.trim().toLowerCase();
  if (t.length === 0) {
    return -1;
  }
  const direct: number = parseInt(t);
  if (!isNaN(direct) && direct >= 1 && direct <= 7) {
    return direct;
  }
  const names: string[] = ['一', '二', '三', '四', '五', '六', '日'];
  for (let i = 0; i < names.length; i++) {
    if (t.includes(names[i])) {
      return i + 1;
    }
  }
  if (t.includes('sun')) {
    return 7;
  }
  const en: string[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  for (let i = 0; i < en.length; i++) {
    if (t.startsWith(en[i])) {
      return i + 1;
    }
  }
  return -1;
}

/** 解析 "1-2" / "1~2" / "1" / "1-2节" / "1-16周" 为 [a, b] */
export function parseRange(token: string): number[] {
  const cleaned = token.replace(/[第节周课时\s]/g, '').replace(/~/g, '-').replace(/—/g, '-');
  const parts = cleaned.split('-');
  if (parts.length >= 2) {
    const a = parseInt(parts[0]);
    const b = parseInt(parts[1]);
    if (!isNaN(a) && !isNaN(b)) {
      return [a, b];
    }
  }
  const single = parseInt(cleaned);
  if (!isNaN(single)) {
    return [single, single];
  }
  return [];
}

/** 批量导入的解析结果 */
export interface ImportResult {
  courses: Course[];
  failedLines: number;
}

/**
 * 批量导入文本解析。每行一门课程，支持两种格式：
 *
 * A（逗号 / 制表符 / 分号分隔，推荐）：
 *   课程名, 星期, 开始节, 结束节, 起始周, 结束周, 教室, 教师
 *   高等数学, 周一, 1, 2, 1, 16, 教一101, 张明
 *
 * B（紧凑区间写法）：
 *   课程名, 星期, 1-2节, 1-16周, 教室, 教师
 *   大学英语, 周二, 3-4节, 1-16周, 外语楼203, 李华
 *
 * 以 # 开头的行、空行会被忽略。
 */
export function parseImportText(text: string, startColorIndex: number): ImportResult {
  const result: Course[] = [];
  let failed = 0;
  let colorIndex = startColorIndex;
  const lines: string[] = text.split('\n');
  for (let li = 0; li < lines.length; li++) {
    const raw: string = lines[li].trim();
    if (raw.length === 0 || raw.startsWith('#') || raw.startsWith('//')) {
      continue;
    }
    const normalized: string = raw
      .replace(/，/g, ',')
      .replace(/、/g, ',')
      .replace(/；/g, ',')
      .replace(/;/g, ',')
      .replace(/\t/g, ',')
      .replace(/\|/g, ',')
      .replace(/\s+/g, ' ');
    const tokens: string[] = normalized.split(',')
      .map((t: string) => t.trim())
      .filter((t: string) => t.length > 0);
    if (tokens.length < 5) {
      failed++;
      continue;
    }

    const name: string = tokens[0];
    const day: number = parseDay(tokens[1]);
    if (day < 0) {
      failed++;
      continue;
    }

    let sections: number[] = [];
    let weeks: number[] = [];
    let location: string = '';
    let teacher: string = '';

    if (tokens[2].indexOf('-') >= 0) {
      // 格式 B：区间写法
      sections = parseRange(tokens[2]);
      weeks = tokens.length > 3 ? parseRange(tokens[3]) : [1, DEFAULT_TOTAL_WEEKS];
      location = tokens.length > 4 ? tokens[4] : '';
      teacher = tokens.length > 5 ? tokens[5] : '';
    } else {
      // 格式 A：分开的节次与周次
      const s1 = parseInt(tokens[2]);
      const s2 = parseInt(tokens[3]);
      if (isNaN(s1) || isNaN(s2)) {
        failed++;
        continue;
      }
      sections = [s1, s2];
      if (tokens.length > 4 && tokens[4].indexOf('-') >= 0) {
        weeks = parseRange(tokens[4]);
        location = tokens.length > 5 ? tokens[5] : '';
        teacher = tokens.length > 6 ? tokens[6] : '';
      } else {
        const w1 = tokens.length > 4 ? parseInt(tokens[4]) : 1;
        const w2 = tokens.length > 5 ? parseInt(tokens[5]) : DEFAULT_TOTAL_WEEKS;
        weeks = [isNaN(w1) ? 1 : w1, isNaN(w2) ? DEFAULT_TOTAL_WEEKS : w2];
        location = tokens.length > 6 ? tokens[6] : '';
        teacher = tokens.length > 7 ? tokens[7] : '';
      }
    }

    if (sections.length < 2 || weeks.length < 2) {
      failed++;
      continue;
    }

    const course: Course = {
      id: nextId('c'),
      name: name,
      teacher: teacher,
      location: location,
      day: day,
      startSection: Math.max(1, Math.min(sections[0], sections[1])),
      endSection: Math.min(SECTIONS_PER_DAY, Math.max(sections[0], sections[1])),
      startWeek: Math.max(1, Math.min(weeks[0], weeks[1])),
      endWeek: Math.max(1, Math.max(weeks[0], weeks[1])),
      colorIndex: colorIndex % COURSE_BG.length,
      note: ''
    };
    colorIndex++;
    result.push(course);
  }
  return { courses: result, failedLines: failed };
}

/** 示例数据（含一处刻意安排的冲突，用于演示冲突检测） */
export function sampleCourses(): Course[] {
  const raw: string[][] = [
    ['高等数学 A', '张明', '教一101', '1', '1', '2', '1', '16'],
    ['大学英语', '李华', '外语楼203', '1', '3', '4', '1', '16'],
    ['程序设计基础', '王强', '信息楼A305', '2', '1', '2', '1', '16'],
    ['线性代数', '赵敏', '教二208', '3', '3', '4', '1', '8'],
    ['数据结构', '陈晨', '信息楼A401', '3', '3', '4', '5', '12'],
    ['大学物理', '刘洋', '理科楼B102', '4', '5', '6', '1', '16'],
    ['马克思主义基本原理', '周红', '教三301', '5', '1', '2', '1', '16'],
    ['体育（篮球）', '孙磊', '体育馆', '5', '7', '8', '1', '16']
  ];
  const list: Course[] = [];
  for (let i = 0; i < raw.length; i++) {
    const r = raw[i];
    const c: Course = {
      id: nextId('c'),
      name: r[0],
      teacher: r[1],
      location: r[2],
      day: parseInt(r[3]),
      startSection: parseInt(r[4]),
      endSection: parseInt(r[5]),
      startWeek: parseInt(r[6]),
      endWeek: parseInt(r[7]),
      colorIndex: i % COURSE_BG.length,
      note: ''
    };
    list.push(c);
  }
  return list;
}
