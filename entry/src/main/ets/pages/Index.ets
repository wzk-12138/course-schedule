/**
 * 学期课表与冲突检测 —— 主界面
 * 功能：录入/批量导入课程、自动冲突标记、周视图课表、分屏查看课表与待办
 */
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  Course,
  TodoItem,
  DAY_NAMES,
  SECTION_TIMES,
  SECTIONS_PER_DAY,
  DEFAULT_TOTAL_WEEKS,
  COURSE_BG,
  COURSE_LINE,
  COURSE_FG,
  CONFLICT_BG,
  CONFLICT_LINE,
  CONFLICT_FG,
  formatWeeks,
  formatSections,
  detectConflictIds,
  countConflictPairs,
  todayWeekday,
  parseImportText,
  sampleCourses,
  nextId
} from '../model/Models';
import { CourseStore } from '../model/Store';

const CELL_H: number = 64;
const HEADER_H: number = 42;
const SECTION_COL_W: number = 64;

@Entry
@Component
struct Index {
  // ==== 数据 ====
  @State courses: Course[] = [];
  @State todos: TodoItem[] = [];
  @State currentWeek: number = 1;
  @State totalWeeks: number = DEFAULT_TOTAL_WEEKS;
  @State conflictIds: string[] = [];
  @State conflictPairs: number = 0;
  @State loaded: boolean = false;

  // ==== 布局 ====
  @State splitRow: boolean = true; // true=左右分屏，false=上下分屏

  // ==== 浮层 ====
  @State showForm: boolean = false;
  @State showImport: boolean = false;

  // ==== 表单 ====
  @State editingId: string = '';
  @State fName: string = '';
  @State fTeacher: string = '';
  @State fLocation: string = '';
  @State fDay: number = 1;
  @State fStart: string = '1';
  @State fEnd: string = '2';
  @State fWeekStart: string = '1';
  @State fWeekEnd: string = '16';

  // ==== 导入 ====
  @State importText: string = '';

  // ==== 待办 ====
  @State newTodo: string = '';

  private store: CourseStore = new CourseStore();
  private sections: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  private days: number[] = [1, 2, 3, 4, 5, 6, 7];

  // ================= 生命周期 =================
  async aboutToAppear(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.Context;
    await this.store.init(ctx);
    this.courses = this.store.getCourses();
    this.todos = this.store.getTodos();
    this.currentWeek = this.store.getCurrentWeek();
    this.totalWeeks = this.store.getTotalWeeks();
    this.loaded = true;
    this.refreshConflicts();
  }

  // ================= 计算 =================
  /** 指定周次上课的课程 */
  private activeCourses(): Course[] {
    const week = this.currentWeek;
    return this.courses.filter((c: Course) => c.startWeek <= week && c.endWeek >= week);
  }

  /** 某一天的课程（按节次排序） */
  private coursesOfDay(day: number): Course[] {
    return this.activeCourses()
      .filter((c: Course) => c.day === day)
      .sort((a: Course, b: Course) => a.startSection - b.startSection);
  }

  /** 今天（按星期）的课程，不受当前周次限制 */
  private todayCourses(): Course[] {
    const d = todayWeekday();
    return this.courses
      .filter((c: Course) => c.day === d)
      .sort((a: Course, b: Course) => a.startSection - b.startSection);
  }

  private todayW(): number {
    return todayWeekday();
  }

  private isConflict(id: string): boolean {
    return this.conflictIds.includes(id);
  }

  private refreshConflicts(): void {
    const active = this.activeCourses();
    this.conflictIds = detectConflictIds(active);
    this.conflictPairs = countConflictPairs(active);
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2200 });
    } catch (err) {
      hilog.warn(0x0001, 'CourseSchedule', 'showToast failed: %{public}s', JSON.stringify(err));
    }
  }

  // ================= 操作 =================
  private prevWeek(): void {
    if (this.currentWeek > 1) {
      this.currentWeek--;
      this.store.saveCurrentWeek(this.currentWeek);
      this.refreshConflicts();
    }
  }

  private nextWeek(): void {
    if (this.currentWeek < this.totalWeeks) {
      this.currentWeek++;
      this.store.saveCurrentWeek(this.currentWeek);
      this.refreshConflicts();
    }
  }

  private openCreate(): void {
    this.editingId = '';
    this.fName = '';
    this.fTeacher = '';
    this.fLocation = '';
    this.fDay = 1;
    this.fStart = '1';
    this.fEnd = '2';
    this.fWeekStart = '1';
    this.fWeekEnd = '16';
    this.showForm = true;
  }

  private openEdit(c: Course): void {
    this.editingId = c.id;
    this.fName = c.name;
    this.fTeacher = c.teacher;
    this.fLocation = c.location;
    this.fDay = c.day;
    this.fStart = c.startSection.toString();
    this.fEnd = c.endSection.toString();
    this.fWeekStart = c.startWeek.toString();
    this.fWeekEnd = c.endWeek.toString();
    this.showForm = true;
  }

  private saveCourse(): void {
    const name: string = this.fName.trim();
    if (name.length === 0) {
      this.toast('请填写课程名称');
      return;
    }
    const s1: number = parseInt(this.fStart);
    const s2: number = parseInt(this.fEnd);
    const w1: number = parseInt(this.fWeekStart);
    const w2: number = parseInt(this.fWeekEnd);
    if (isNaN(s1) || isNaN(s2) || isNaN(w1) || isNaN(w2)) {
      this.toast('节次与周次请填写数字');
      return;
    }
    const newStartSection: number = Math.max(1, Math.min(s1, s2));
    const newEndSection: number = Math.min(SECTIONS_PER_DAY, Math.max(s1, s2));
    const newStartWeek: number = Math.max(1, Math.min(w1, w2));
    const newEndWeek: number = Math.max(1, Math.max(w1, w2));

    const oldColor: number = this.editingId.length > 0
      ? (this.courses.find((c: Course) => c.id === this.editingId)?.colorIndex ?? this.courses.length)
      : this.courses.length;

    const target: Course = {
      id: this.editingId.length > 0 ? this.editingId : nextId('c'),
      name: name,
      teacher: this.fTeacher.trim(),
      location: this.fLocation.trim(),
      day: this.fDay,
      startSection: newStartSection,
      endSection: newEndSection,
      startWeek: newStartWeek,
      endWeek: newEndWeek,
      colorIndex: oldColor % COURSE_BG.length,
      note: ''
    };

    let list: Course[] = [];
    if (this.editingId.length > 0) {
      list = this.courses.map((c: Course) => c.id === target.id ? target : c);
    } else {
      list = this.courses.slice();
      list.push(target);
    }
    this.courses = list;
    this.store.saveCourses(list);
    this.refreshConflicts();
    this.showForm = false;

    if (this.isConflict(target.id)) {
      this.toast('已保存，但该课程与其它课程存在时间冲突 ⚠');
    } else {
      this.toast('已保存：' + target.name);
    }
  }

  private deleteCourse(id: string): void {
    const list: Course[] = this.courses.filter((c: Course) => c.id !== id);
    this.courses = list;
    this.store.saveCourses(list);
    this.refreshConflicts();
    this.showForm = false;
    this.toast('已删除该课程');
  }

  private doImport(): void {
    const res = parseImportText(this.importText, this.courses.length);
    if (res.courses.length === 0) {
      this.toast('没有解析到有效课程，请检查格式（需要逗号分隔，至少 5 列）');
      return;
    }
    const list: Course[] = this.courses.slice();
    for (let i = 0; i < res.courses.length; i++) {
      list.push(res.courses[i]);
    }
    this.courses = list;
    this.store.saveCourses(list);
    this.refreshConflicts();
    this.showImport = false;
    this.importText = '';

    let msg: string = '已导入 ' + res.courses.length + ' 门课程';
    if (res.failedLines > 0) {
      msg += '（' + res.failedLines + ' 行格式不正确已跳过）';
    }
    if (this.conflictPairs > 0) {
      msg += '｜检测到 ' + this.conflictPairs + ' 处冲突';
    }
    this.toast(msg);
  }

  private loadSample(): void {
    const list: Course[] = this.courses.slice();
    const samples: Course[] = sampleCourses();
    for (let i = 0; i < samples.length; i++) {
      list.push(samples[i]);
    }
    this.courses = list;
    this.store.saveCourses(list);
    this.refreshConflicts();
    this.toast('已载入 ' + samples.length + ' 门示例课程（含 1 处冲突用于演示）');
  }

  private addTodo(): void {
    const title: string = this.newTodo.trim();
    if (title.length === 0) {
      return;
    }
    const list: TodoItem[] = this.todos.slice();
    list.push({ id: nextId('t'), title: title, done: false, courseId: '', createdAt: Date.now() });
    this.todos = list;
    this.store.saveTodos(list);
    this.newTodo = '';
  }

  private toggleTodo(id: string, done: boolean): void {
    const list: TodoItem[] = this.todos.map((t: TodoItem) => {
      if (t.id === id) {
        const n: TodoItem = { id: t.id, title: t.title, done: done, courseId: t.courseId, createdAt: t.createdAt };
        return n;
      }
      return t;
    });
    this.todos = list;
    this.store.saveTodos(list);
  }

  private removeTodo(id: string): void {
    const list: TodoItem[] = this.todos.filter((t: TodoItem) => t.id !== id);
    this.todos = list;
    this.store.saveTodos(list);
  }

  private generateFromToday(): void {
    const today: Course[] = this.todayCourses();
    if (today.length === 0) {
      this.toast('今天没有课程，无需生成待办');
      return;
    }
    const list: TodoItem[] = this.todos.slice();
    for (let i = 0; i < today.length; i++) {
      const c: Course = today[i];
      list.push({
        id: nextId('t'),
        title: '【今日课程】' + c.name + ' ' + formatSections(c.startSection, c.endSection)
          + (c.location.length > 0 ? ' @' + c.location : ''),
        done: false,
        courseId: c.id,
        createdAt: Date.now()
      });
    }
    this.todos = list;
    this.store.saveTodos(list);
    this.toast('已生成 ' + today.length + ' 条待办');
  }

  // ================= UI =================
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.toolbarView()

        if (this.splitRow) {
          Row() {
            this.timetablePane()
            this.sidePane()
          }
          .layoutWeight(1)
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
          Column() {
            this.timetablePane()
            this.sidePane()
          }
          .layoutWeight(1)
          .width('100%')
        }

        this.statusBarView()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F4F8')

      if (this.showForm) {
        this.formOverlay()
      }
      if (this.showImport) {
        this.importOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ---------- 顶部工具栏 ----------
  @Builder
  toolbarView() {
    Row() {
      Column() {
        Text('学期课表')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text('冲突检测 · 周视图 · 分屏待办')
          .fontSize(11)
          .fontColor('#9AA3AF')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      // 周次切换
      Row() {
        Button('‹')
          .width(30)
          .height(30)
          .fontSize(16)
          .backgroundColor('#F1F3F7')
          .fontColor('#374151')
          .borderRadius(8)
          .onClick(() => {
            this.prevWeek();
          })
        Text('第 ' + this.currentWeek + ' / ' + this.totalWeeks + ' 周')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .margin({ left: 12, right: 12 })
        Button('›')
          .width(30)
          .height(30)
          .fontSize(16)
          .backgroundColor('#F1F3F7')
          .fontColor('#374151')
          .borderRadius(8)
          .onClick(() => {
            this.nextWeek();
          })
      }
      .margin({ right: 16 })

      Button('录入课程')
        .height(34)
        .fontSize(13)
        .backgroundColor('#1F6FEB')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .onClick(() => {
          this.openCreate();
        })

      Button('批量导入')
        .height(34)
        .fontSize(13)
        .backgroundColor('#EEF2F7')
        .fontColor('#1F2937')
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.showImport = true;
        })

      Button(this.splitRow ? '上下分屏' : '左右分屏')
        .height(34)
        .fontSize(13)
        .backgroundColor('#EEF2F7')
        .fontColor('#1F2937')
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.splitRow = !this.splitRow;
        })
    }
    .width('100%')
    .height(64)
    .padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E9ECF1' })
  }

  // ---------- 周视图课表 ----------
  @Builder
  timetablePane() {
    Column() {
      // 面板头
      Row() {
        Text('周视图课表')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text('第 ' + this.currentWeek + ' 周')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ left: 8 })

        Blank()

        if (this.conflictIds.length > 0) {
          Row() {
            Text('⚠ 时间冲突')
              .fontSize(12)
              .fontColor(CONFLICT_FG)
              .fontWeight(FontWeight.Medium)
            Text(this.conflictPairs + ' 处 / ' + this.conflictIds.length + ' 门课')
              .fontSize(12)
              .fontColor('#8A5A5A')
              .margin({ left: 6 })
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(CONFLICT_BG)
          .borderRadius(8)
          .border({ width: 1, color: CONFLICT_LINE })
        } else {
          Text('✓ 无冲突')
            .fontSize(12)
            .fontColor('#1E6C3A')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#E6F4EA')
            .borderRadius(8)
        }
      }
      .width('100%')
      .height(46)
      .padding({ left: 16, right: 16 })
      .border({ width: { bottom: 1 }, color: '#E9ECF1' })

      if (this.courses.length === 0) {
        Column() {
          Text('还没有课程数据')
            .fontSize(15)
            .fontColor('#374151')
          Text('可以手动录入、批量粘贴导入，或先载入示例数据看看效果')
            .fontSize(12)
            .fontColor('#9AA3AF')
            .margin({ top: 8 })
          Row() {
            Button('录入第一门课')
              .height(34)
              .fontSize(13)
              .backgroundColor('#1F6FEB')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => {
                this.openCreate();
              })
            Button('批量导入')
              .height(34)
              .fontSize(13)
              .backgroundColor('#EEF2F7')
              .fontColor('#1F2937')
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => {
                this.showImport = true;
              })
            Button('载入示例数据')
              .height(34)
              .fontSize(13)
              .backgroundColor('#EEF2F7')
              .fontColor('#1F2937')
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => {
                this.loadSample();
              })
          }
          .margin({ top: 18 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        this.weekGrid()
      }
    }
    .layoutWeight(3)
    .height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ left: 12, top: 12, right: 6, bottom: 12 })
    .clip(true)
  }

  @Builder
  weekGrid() {
    Column() {
      // 表头：节次 + 周一到周日
      Row() {
        Text('节次')
          .width(SECTION_COL_W)
          .fontSize(12)
          .fontColor('#6B7280')
          .textAlign(TextAlign.Center)
        ForEach(DAY_NAMES, (d: string, idx: number) => {
          Text(d)
            .layoutWeight(1)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(idx >= 5 ? '#8A94A6' : '#374151')
            .textAlign(TextAlign.Center)
        }, (d: string) => d)
      }
      .width('100%')
      .height(HEADER_H)
      .backgroundColor('#FAFBFD')
      .border({ width: { bottom: 1 }, color: '#E9ECF1' })

      Scroll() {
        Row() {
          // 左侧节次栏
          Column() {
            ForEach(this.sections, (i: number) => {
              Column() {
                Text(i.toString())
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#6B7280')
                Text(SECTION_TIMES[i - 1])
                  .fontSize(9)
                  .fontColor('#B0B7C3')
                  .margin({ top: 2 })
              }
              .width('100%')
              .height(CELL_H)
              .justifyContent(FlexAlign.Center)
              .border({ width: { bottom: 1 }, color: '#F2F4F8' })
            }, (i: number) => 'sec' + i)
          }
          .width(SECTION_COL_W)

          // 每天的列
          ForEach(this.days, (day: number) => {
            Stack({ alignContent: Alignment.TopStart }) {
              // 网格底线
              Column() {
                ForEach(this.sections, (i: number) => {
                  Column()
                    .width('100%')
                    .height(CELL_H)
                    .border({ width: { bottom: 1 }, color: '#F2F4F8' })
                }, (i: number) => 'bg' + day + '_' + i)
              }
              .width('100%')
              .height(CELL_H * this.sections.length)

              // 课程卡片
              ForEach(this.coursesOfDay(day), (c: Course) => {
                Column() {
                  Row() {
                    Text(c.name)
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.isConflict(c.id) ? CONFLICT_FG : COURSE_FG[c.colorIndex % COURSE_BG.length])
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    if (this.isConflict(c.id)) {
                      Text('冲突')
                        .fontSize(9)
                        .fontColor('#FFFFFF')
                        .backgroundColor(CONFLICT_LINE)
                        .borderRadius(4)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    }
                  }
                  .width('100%')

                  Text(c.location.length > 0 ? (c.location + ' · ' + c.teacher) : c.teacher)
                    .fontSize(10)
                    .fontColor('#6B7280')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                    .margin({ top: 2 })

                  Text(formatWeeks(c.startWeek, c.endWeek))
                    .fontSize(9)
                    .fontColor('#9AA3AF')
                    .maxLines(1)
                    .width('100%')
                    .margin({ top: 1 })
                }
                .alignItems(HorizontalAlign.Start)
                .padding(6)
                .width('100%')
                .height((c.endSection - c.startSection + 1) * CELL_H - 8)
                .position({ x: 0, y: (c.startSection - 1) * CELL_H + 4 })
                .backgroundColor(this.isConflict(c.id) ? CONFLICT_BG : COURSE_BG[c.colorIndex % COURSE_BG.length])
                .borderRadius(8)
                .border({
                  width: this.isConflict(c.id) ? 1.5 : 1,
                  color: this.isConflict(c.id) ? CONFLICT_LINE : COURSE_LINE[c.colorIndex % COURSE_BG.length]
                })
                .onClick(() => {
                  this.openEdit(c);
                })
              }, (c: Course) => c.id + '_' + c.startSection + '_' + c.day)
            }
            .layoutWeight(1)
            .height(CELL_H * this.sections.length)
            .padding({ left: 3, right: 3 })
            .border({ width: { left: 1 }, color: '#F2F4F8' })
          }, (day: number) => 'day' + day)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .layoutWeight(1)
    .width('100%')
  }

  // ---------- 右侧：待办 + 今日课程 ----------
  @Builder
  sidePane() {
    Column() {
      // 今日课程
      Row() {
        Text('今日课程')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(DAY_NAMES[this.todayW() - 1])
          .fontSize(11)
          .fontColor('#1F6FEB')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#E8F0FE')
          .borderRadius(6)
          .margin({ left: 8 })
        Blank()
        Text(this.todayCourses().length + ' 门')
          .fontSize(12)
          .fontColor('#9AA3AF')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      if (this.todayCourses().length === 0) {
        Text('今天没有课，休息一下 ~')
          .fontSize(13)
          .fontColor('#9AA3AF')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 14 })
      } else {
        Column() {
          ForEach(this.todayCourses(), (c: Course) => {
            Row() {
              Text(formatSections(c.startSection, c.endSection))
                .fontSize(11)
                .fontColor('#1F6FEB')
                .width(58)
              Column() {
                Text(c.name)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isConflict(c.id) ? CONFLICT_FG : '#111827')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text((c.location.length > 0 ? c.location + ' · ' : '') + c.teacher)
                  .fontSize(10)
                  .fontColor('#9AA3AF')
                  .maxLines(1)
                  .width('100%')
                  .margin({ top: 1 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 7, bottom: 7 })
            .onClick(() => {
              this.openEdit(c);
            })
          }, (c: Course) => 'today_' + c.id)
        }
        .width('100%')
        .padding({ bottom: 8 })
      }

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#E9ECF1')

      // 待办
      Row() {
        Text('待办清单')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Blank()
        Text(this.todos.filter((t: TodoItem) => !t.done).length + ' 项未完成')
          .fontSize(12)
          .fontColor('#9AA3AF')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      Row() {
        TextInput({ placeholder: '添加待办，如：复习高数第三章', text: this.newTodo })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor('#F4F6F9')
          .borderRadius(8)
          .onChange((v: string) => {
            this.newTodo = v;
          })
        Button('添加')
          .height(36)
          .fontSize(13)
          .backgroundColor('#1F6FEB')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 8 })
          .onClick(() => {
            this.addTodo();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row() {
        Button('由今日课程生成待办')
          .height(32)
          .fontSize(12)
          .backgroundColor('#EEF2F7')
          .fontColor('#1F2937')
          .borderRadius(8)
          .onClick(() => {
            this.generateFromToday();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 6 })

      if (this.todos.length === 0) {
        Column() {
          Text('暂无待办')
            .fontSize(13)
            .fontColor('#B0B7C3')
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.todos, (t: TodoItem) => {
            ListItem() {
              Row() {
                Checkbox({ name: t.id, group: 'todoGroup' })
                  .select(t.done)
                  .width(20)
                  .height(20)
                  .onChange((v: boolean) => {
                    this.toggleTodo(t.id, v);
                  })
                Text(t.title)
                  .fontSize(13)
                  .fontColor(t.done ? '#9AA3AF' : '#111827')
                  .decoration({ type: t.done ? TextDecorationType.LineThrough : TextDecorationType.None })
                  .layoutWeight(1)
                  .maxLines(2)
                  .margin({ left: 8 })
                Text('✕')
                  .fontSize(14)
                  .fontColor('#C0C6CF')
                  .padding(6)
                  .onClick(() => {
                    this.removeTodo(t.id);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            }
          }, (t: TodoItem) => 'todo_' + t.id + (t.done ? '_1' : '_0'))
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      }
    }
    .layoutWeight(2)
    .height('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ left: 6, top: 12, right: 12, bottom: 12 })
    .border({ width: { left: this.splitRow ? 0 : 0 }, color: '#E9ECF1' })
    .clip(true)
  }

  // ---------- 底部状态栏 ----------
  @Builder
  statusBarView() {
    Row() {
      Text('共 ' + this.courses.length + ' 门课程')
        .fontSize(12)
        .fontColor('#6B7280')
      Text('·')
        .fontSize(12)
        .fontColor('#C0C6CF')
        .margin({ left: 8, right: 8 })
      Text('本周 ' + this.activeCourses().length + ' 门')
        .fontSize(12)
        .fontColor('#6B7280')
      if (this.conflictPairs > 0) {
        Text('·')
          .fontSize(12)
          .fontColor('#C0C6CF')
          .margin({ left: 8, right: 8 })
        Text('检测到 ' + this.conflictPairs + ' 处时间冲突')
          .fontSize(12)
          .fontColor(CONFLICT_FG)
      }
      Blank()
      Text('数据保存在本机（Preferences），无需联网')
        .fontSize(12)
        .fontColor('#9AA3AF')
    }
    .width('100%')
    .height(30)
    .padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E9ECF1' })
  }

  // ---------- 录入 / 编辑课程浮层 ----------
  @Builder
  formOverlay() {
    Column() {
      Column() {
        Row() {
          Text(this.editingId.length > 0 ? '编辑课程' : '录入课程')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Blank()
          Text('✕')
            .fontSize(16)
            .fontColor('#9AA3AF')
            .padding(4)
            .onClick(() => {
              this.showForm = false;
            })
        }
        .width('100%')
        .margin({ bottom: 16 })

        Text('课程名称')
          .fontSize(12)
          .fontColor('#6B7280')
          .width('100%')
        TextInput({ placeholder: '如：高等数学 A', text: this.fName })
          .height(38)
          .fontSize(14)
          .backgroundColor('#F5F6F8')
          .borderRadius(8)
          .margin({ top: 6, bottom: 12 })
          .onChange((v: string) => {
            this.fName = v;
          })

        Text('星期')
          .fontSize(12)
          .fontColor('#6B7280')
          .width('100%')
        Row() {
          ForEach(this.days, (d: number) => {
            Text(DAY_NAMES[d - 1])
              .fontSize(12)
              .fontColor(this.fDay === d ? '#FFFFFF' : '#374151')
              .backgroundColor(this.fDay === d ? '#1F6FEB' : '#F1F3F7')
              .borderRadius(6)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .margin({ right: 6 })
              .onClick(() => {
                this.fDay = d;
              })
          }, (d: number) => 'fday' + d)
        }
        .width('100%')
        .margin({ top: 6, bottom: 12 })

        Row() {
          Column() {
            Text('节次（第几节到第几节）')
              .fontSize(12)
              .fontColor('#6B7280')
              .width('100%')
            Row() {
              TextInput({ text: this.fStart })
                .type(InputType.Number)
                .width(64)
                .height(38)
                .fontSize(14)
                .backgroundColor('#F5F6F8')
                .borderRadius(8)
                .onChange((v: string) => {
                  this.fStart = v;
                })
              Text('—')
                .fontSize(14)
                .fontColor('#9AA3AF')
                .margin({ left: 8, right: 8 })
              TextInput({ text: this.fEnd })
                .type(InputType.Number)
                .width(64)
                .height(38)
                .fontSize(14)
                .backgroundColor('#F5F6F8')
                .borderRadius(8)
                .onChange((v: string) => {
                  this.fEnd = v;
                })
              Text('节')
                .fontSize(12)
                .fontColor('#9AA3AF')
                .margin({ left: 8 })
            }
            .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text('周次（起始周到结束周）')
              .fontSize(12)
              .fontColor('#6B7280')
              .width('100%')
            Row() {
              TextInput({ text: this.fWeekStart })
                .type(InputType.Number)
                .width(64)
                .height(38)
                .fontSize(14)
                .backgroundColor('#F5F6F8')
                .borderRadius(8)
                .onChange((v: string) => {
                  this.fWeekStart = v;
                })
              Text('—')
                .fontSize(14)
                .fontColor('#9AA3AF')
                .margin({ left: 8, right: 8 })
              TextInput({ text: this.fWeekEnd })
                .type(InputType.Number)
                .width(64)
                .height(38)
                .fontSize(14)
                .backgroundColor('#F5F6F8')
                .borderRadius(8)
                .onChange((v: string) => {
                  this.fWeekEnd = v;
                })
              Text('周')
                .fontSize(12)
                .fontColor('#9AA3AF')
                .margin({ left: 8 })
            }
            .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        Row() {
          Column() {
            Text('教室')
              .fontSize(12)
              .fontColor('#6B7280')
              .width('100%')
            TextInput({ placeholder: '如：教一101', text: this.fLocation })
              .height(38)
              .fontSize(14)
              .backgroundColor('#F5F6F8')
              .borderRadius(8)
              .margin({ top: 6 })
              .onChange((v: string) => {
                this.fLocation = v;
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text('教师')
              .fontSize(12)
              .fontColor('#6B7280')
              .width('100%')
            TextInput({ placeholder: '如：张明', text: this.fTeacher })
              .height(38)
              .fontSize(14)
              .backgroundColor('#F5F6F8')
              .borderRadius(8)
              .margin({ top: 6 })
              .onChange((v: string) => {
                this.fTeacher = v;
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
        }
        .width('100%')
        .margin({ bottom: 20 })

        Row() {
          if (this.editingId.length > 0) {
            Button('删除')
              .height(36)
              .fontSize(14)
              .backgroundColor('#FFECEC')
              .fontColor(CONFLICT_FG)
              .borderRadius(8)
              .onClick(() => {
                this.deleteCourse(this.editingId);
              })
          }
          Blank()
          Button('取消')
            .height(36)
            .fontSize(14)
            .backgroundColor('#EEF2F7')
            .fontColor('#1F2937')
            .borderRadius(8)
            .onClick(() => {
              this.showForm = false;
            })
          Button('保存')
            .height(36)
            .fontSize(14)
            .backgroundColor('#1F6FEB')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => {
              this.saveCourse();
            })
        }
        .width('100%')
      }
      .width(620)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .shadow({ radius: 24, color: 'rgba(17,24,39,0.18)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(17,24,39,0.35)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ---------- 批量导入浮层 ----------
  @Builder
  importOverlay() {
    Column() {
      Column() {
        Row() {
          Text('批量导入课程')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          Blank()
          Text('✕')
            .fontSize(16)
            .fontColor('#9AA3AF')
            .padding(4)
            .onClick(() => {
              this.showImport = false;
            })
        }
        .width('100%')
        .margin({ bottom: 10 })

        Text('每行一门课程，用逗号分隔。支持两种格式：\n'
          + '① 课程名, 星期, 开始节, 结束节, 起始周, 结束周, 教室, 教师\n'
          + '② 课程名, 星期, 1-2节, 1-16周, 教室, 教师（区间写法）\n'
          + '星期可写「周一」或「1」；以 # 开头的行会被忽略。')
          .fontSize(12)
          .fontColor('#6B7280')
          .lineHeight(19)
          .width('100%')

        TextArea({
          placeholder: '高等数学, 周一, 1, 2, 1, 16, 教一101, 张明\n'
            + '大学英语, 周二, 3-4节, 1-16周, 外语楼203, 李华\n'
            + '数据结构, 周三, 5, 6, 1, 12, 信息楼A401, 陈晨',
          text: this.importText
        })
          .height(220)
          .fontSize(13)
          .backgroundColor('#F5F6F8')
          .borderRadius(8)
          .margin({ top: 10, bottom: 16 })
          .onChange((v: string) => {
            this.importText = v;
          })

        Row() {
          Button('载入示例数据')
            .height(36)
            .fontSize(13)
            .backgroundColor('#EEF2F7')
            .fontColor('#1F2937')
            .borderRadius(8)
            .onClick(() => {
              this.loadSample();
            })
          Blank()
          Button('取消')
            .height(36)
            .fontSize(14)
            .backgroundColor('#EEF2F7')
            .fontColor('#1F2937')
            .borderRadius(8)
            .onClick(() => {
              this.showImport = false;
            })
          Button('解析并导入')
            .height(36)
            .fontSize(14)
            .backgroundColor('#1F6FEB')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => {
              this.doImport();
            })
        }
        .width('100%')
      }
      .width(660)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
      .shadow({ radius: 24, color: 'rgba(17,24,39,0.18)', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(17,24,39,0.35)')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
