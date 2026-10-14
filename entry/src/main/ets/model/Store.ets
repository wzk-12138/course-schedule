/**
 * 本地持久化：基于 @kit.ArkData 的 Preferences，无需服务端。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Course, TodoItem, DEFAULT_TOTAL_WEEKS } from './Models';

const DOMAIN: number = 0x0001;
const TAG: string = 'CourseStore';
const PREF_NAME: string = 'course_schedule_store';
const KEY_COURSES: string = 'courses';
const KEY_TODOS: string = 'todos';
const KEY_CURRENT_WEEK: string = 'current_week';
const KEY_TOTAL_WEEKS: string = 'total_weeks';

export class CourseStore {
  private pref: preferences.Preferences | null = null;
  private courses: Course[] = [];
  private todos: TodoItem[] = [];
  private currentWeek: number = 1;
  private totalWeeks: number = DEFAULT_TOTAL_WEEKS;

  /** 初始化并读取本地数据 */
  async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);

      const rawCourses = await this.pref.get(KEY_COURSES, '[]');
      this.courses = JSON.parse(rawCourses as string) as Course[];

      const rawTodos = await this.pref.get(KEY_TODOS, '[]');
      this.todos = JSON.parse(rawTodos as string) as TodoItem[];

      const rawWeek = await this.pref.get(KEY_CURRENT_WEEK, 1);
      this.currentWeek = rawWeek as number;

      const rawTotal = await this.pref.get(KEY_TOTAL_WEEKS, DEFAULT_TOTAL_WEEKS);
      this.totalWeeks = rawTotal as number;

      if (!Array.isArray(this.courses)) {
        this.courses = [];
      }
      if (!Array.isArray(this.todos)) {
        this.todos = [];
      }
      hilog.info(DOMAIN, TAG, 'store loaded: %{public}d courses', this.courses.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
      this.pref = null;
      this.courses = [];
      this.todos = [];
    }
  }

  getCourses(): Course[] {
    return this.courses;
  }

  getTodos(): TodoItem[] {
    return this.todos;
  }

  getCurrentWeek(): number {
    return this.currentWeek;
  }

  getTotalWeeks(): number {
    return this.totalWeeks;
  }

  async saveCourses(list: Course[]): Promise<void> {
    this.courses = list;
    await this.put(KEY_COURSES, JSON.stringify(list));
  }

  async saveTodos(list: TodoItem[]): Promise<void> {
    this.todos = list;
    await this.put(KEY_TODOS, JSON.stringify(list));
  }

  async saveCurrentWeek(week: number): Promise<void> {
    this.currentWeek = week;
    await this.put(KEY_CURRENT_WEEK, week);
  }

  async saveTotalWeeks(total: number): Promise<void> {
    this.totalWeeks = total;
    await this.put(KEY_TOTAL_WEEKS, total);
  }

  private async put(key: string, value: string | number): Promise<void> {
    if (this.pref === null) {
      return;
    }
    try {
      await this.pref.put(key, value);
      await this.pref.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'put failed: %{public}s', JSON.stringify(err));
    }
  }
}
