---
description: Advanced programmatic composition in СКД — two-pass preprocessing of detail records before roll-up (hiding zero-total crosstab rows / columns), and executing the composition query directly instead of the DCS output processor for memory-heavy reports. Load only when the standard `ПриКомпоновкеРезультата` override of `dcs-design.md §5` is not enough.
alwaysApply: false
category: development
---

# СКД — advanced composition techniques

Two techniques that go beyond the standard programmatic override. Both are **escalations**: reach for them only after the ordinary route of `dcs-design.md §5` (override `ПриКомпоновкеРезультата`, manipulate settings, output through `ПроцессорВыводаРезультатаКомпоновкиДанныхВТабличныйДокумент`) has been shown insufficient. Both give up part of the standard DCS semantics, and that cost is the reason they are not the default.

| Technique | Solves | Gives up |
|---|---|---|
| **Two-pass preprocessing** (§1) | Filtering / transforming **detail records before the engine rolls them up** | A second full composition pass; the schema must stay query-based |
| **Direct query execution** (§2) | Memory blow-up of the DCS engine on large reports; a flat "raw" result | Groupings, conditional appearance, drill-down (расшифровка), DCS totals |

---

## 1. Two-pass preprocessing

### The problem it solves

Canonical case: hide crosstab rows / columns whose **rolled-up** total is zero — January `−1200` plus March `+1200` sums to `0`, so the cell renders empty but the grouping skeleton stays, leaving hollow rows and columns.

This cannot be solved earlier in the pipeline:

- **In the query / `ИМЕЮЩИЕ`** — the roll-up that produces the zero happens *after* grouping, so the query cannot see it.
- **With a DCS filter** — same reason: the filter applies before the engine aggregates.
- **By post-processing the spreadsheet** (`Область.Видимость = Ложь`) — simpler, but it also hides the grouping headers and leaves visible gaps in the layout.

The working answer is to compose **twice**: once flat, to get the detail rows and filter them, and once for real, feeding the filtered rows back in.

### Algorithm

Both passes run inside `ПриКомпоновкеРезультата` with `СтандартнаяОбработка = Ложь`.

**Pass 1 — obtain a flat detail `ТаблицаЗначений`.** Build a *flat* settings variant (detail records, all fields) over either a cloned query of the main schema or the same schema. Output through `ГенераторМакетаКомпоновкиДанныхДляКоллекцииЗначений` + `ПроцессорВыводаРезультатаКомпоновкиДанныхВКоллекциюЗначений`.

**Process the table** — drop or transform rows (for the zero case: drop a detail row only when **all** its resource fields are zero; keep partially filled rows).

**Pass 2 — compose the real crosstab.** The output schema must remain a **query** dataset *in the schema file*; compile it normally, then swap the dataset for an object dataset **in the compiled layout at runtime**:

```bsl
МакетКомпоновки = КомпоновщикМакета.Выполнить(СхемаВывода, Настройки, Расшифровка);

СтарыйНабор = МакетКомпоновки.НаборыДанных[0];
НовыйНабор  = МакетКомпоновки.НаборыДанных.Добавить(Тип("НаборДанныхОбъектМакетаКомпоновкиДанных"));
НовыйНабор.Имя           = СтарыйНабор.Имя;
НовыйНабор.ИсточникДанных = СтарыйНабор.ИсточникДанных;
Для Каждого Поле Из СтарыйНабор.Поля Цикл
	ЗаполнитьЗначенияСвойств(НовыйНабор.Поля.Добавить(), Поле);
КонецЦикла;
НовыйНабор.ИмяОбъекта = "Результат";
МакетКомпоновки.НаборыДанных.Удалить(СтарыйНабор);

ПроцессорКомпоновки = Новый ПроцессорКомпоновкиДанных;
ПроцессорКомпоновки.Инициализировать(
	МакетКомпоновки, Новый Структура("Результат", ТаблицаДеталей), Расшифровка, Истина);
```

The compile-then-swap order is the whole point: compiling from the **query** dataset lets the platform resolve field types (and therefore reference navigation such as `Номенклатура.Артикул`); the object dataset is substituted only afterwards, into a layout where types are already resolved.

### Gotchas

1. **A crosstab cannot be output to a collection** — only a flat (detail-records) layout can. That is why pass 1 needs its own flat settings.
2. **An object dataset declared in the schema file breaks reference navigation.** Object-dataset fields are untyped, so `КомпоновщикМакета.Выполнить` fails with "Поле не найдено" at **compile** time, before any data is touched. Never convert the output schema to an object dataset — swap at runtime instead.
3. **Derived parameter expressions are not parsed by the collection generator.** Schema parameters defined as expressions (`НачалоПериода = &Период.ДатаНачала`, `ТекущаяДата = ТекущаяДатаСеанса()`) raise "Синтаксическая ошибка" on `Инициализировать`. Set such parameters to explicit computed values in code (`Параметр.Значение = ТекущаяДатаСеанса()`), and take the period from the output settings.
4. **Do not bulk-copy parameters from the output settings into pass 1.** The output settings store derived parameters as `ВыражениеКомпоновкиДанных`, which then leak into pass 1 and trip gotcha 3. Copy only `Период` (`СтандартныйПериод`); compute the rest.
5. **`ПараметрыДанных.НайтиЗначениеПараметра` expects a `ПараметрКомпоновкиДанных`, not a string** — passing a string gives "Несоответствие типов (параметр 1)". Wrap it: `НайтиЗначениеПараметра(Новый ПараметрКомпоновкиДанных(ИмяСтрокой))`. Note the asymmetry: `УстановитьЗначениеПараметра` *does* accept a string.
6. **Identify resource columns via `Схема.ПоляИтога`, not by the column type of the `ТаблицаЗначений`.** Sums coming out of a query with left joins have the **composite** type `Null` + `Число`; a strict "is it a Число" test rejects them and empties the report. Iterate `Схема.ПоляИтога` and use `Строка(ПолеИтога.ПутьКДанным)`.
7. **Compiled parameter values live in `МакетКомпоновки.ЗначенияПараметров`** — not in `НаборДанных.ЗначенияПараметров`, which is empty. On a query dataset of the layout the property is `ЗначенияПараметров` (not `Параметры`).
8. **`ПолеНабораДанныхМакетаКомпоновкиДанных` exposes only `Имя` / `ПутьКДанным` / `Роль`** — there is no `ТипЗначения`. Match table columns by `.Имя`.
9. **Zero-filter semantics.** Drop a detail row only when *every* resource is zero. Rolling up what remains yields a crosstab with no hollow rows or columns; dropping partially filled rows corrupts the totals.
10. **External edits to `.dcs` are invisible to EDT** (via scripts, Python, `git checkout`) until `clean_project` / refresh — the build model keeps the stale schema. When deploying, move schema files separately from the BSL module, and register a new layout in the `.mdo` / object XML with its own UUID.

---

## 2. Direct query execution instead of the DCS engine

### When

- The DCS engine's memory footprint is the problem — it holds all intermediate data of the composition.
- A flat "raw" query result is what is actually wanted (e.g. an `xlsx` export next to the standard "Сформировать").

**Do not use it** when the report needs user groupings, conditional appearance, drill-down, or DCS totals. Those exist only on the standard output path.

### Algorithm

```bsl
// 1. Получить исполняемый макет компоновки.
КомпоновщикМакета = Новый КомпоновщикМакетаКомпоновкиДанных;
МакетКомпоновки = КомпоновщикМакета.Выполнить(
	СхемаКомпоновки, НастройкиОтчёта, , ,
	Тип("ГенераторМакетаКомпоновкиДанныхДляКоллекцииЗначений"));

// 2. Извлечь текст запроса основного набора.
ОбъектЗапроса = МакетКомпоновки.НаборыДанных.НаборДанных1.Запрос;
Если ТипЗнч(ОбъектЗапроса) = Тип("Строка") Тогда
	ТекстЗапроса = ОбъектЗапроса;
Иначе
	ТекстЗапроса = ОбъектЗапроса.Текст;
КонецЕсли;

// 3. Параметры — из СКОМПИЛИРОВАННОГО макета (уже с учётом настроек).
Запрос = Новый Запрос(ТекстЗапроса);
Для Каждого ЗначениеПараметра Из МакетКомпоновки.ЗначенияПараметров Цикл
	Запрос.УстановитьПараметр(ЗначениеПараметра.Имя, ЗначениеПараметра.Значение);
КонецЦикла;

// 4. Потоковый вывод — О(1) по памяти на строку.
Выборка = Запрос.Выполнить().Выбрать();
Пока Выборка.Следующий() Цикл
	// заполнение области табличного документа, накопление итогов
КонецЦикла;
```

Get the schema through `ОбъектОтчёт.ПолучитьМакет("ОсновнаяСхемаКомпоновкиДанных")` — an independent copy from metadata — rather than through the object's own attribute, to avoid side effects on the live schema.

### Two sources for query and parameters

| Source | What you get | Use when |
|---|---|---|
| **Schema** — `СхемаКомпоновки.НаборыДанных.НаборДанных1.Запрос` + `Схема.Параметры` | Raw query text; parameters set by hand from the settings (period, filters) | Simple reports without complex groupings |
| **Compiled layout** — `МакетКомпоновки.НаборыДанных.НаборДанных1.Запрос` + `Макет.ЗначенияПараметров` | Query with the DCS filters and parameters already folded in | Complex reports; when all parameter values must be collected automatically |

### Gotchas

- **`НаборДанных1.Запрос` may be a `Строка` or an object with `.Текст`** — check `ТипЗнч` rather than assuming.
- **External (object) datasets are not wired up automatically** on the direct path. If the query text references one, populate a temporary table under the same name and attach a `МенеджерВременныхТаблиц` to the query.
- **Configuration post-processing of the layout** (e.g. a ЗУП handler that injects extra data into the datasets after composition) operates on the **compiled layout** — it is available only when the layout was obtained through the configuration's own wrapper, not when the query text was lifted straight out of the schema.
- **Stream, never `Выгрузить()`.** Use `РезультатЗапроса.Выбрать()` + `Выборка.Следующий()`; `Выгрузить()` puts the whole result in memory and defeats the purpose. The `ТабличныйДокумент` still grows — for very large volumes, output in chunks.
- **The parameter-value property name** in `МакетКомпоновки.ЗначенияПараметров` (`Имя` vs `ИмяПараметра`) is worth confirming in the debugger on the target platform version before relying on it.
- **Beware form attribute names.** In a form module, a local variable named after a form attribute (`НастройкиОтчёта` on `ФормаОтчета`) overwrites the attribute and breaks `СвойстваРезультата` — clicking the spreadsheet then fails. See `form-module.md → Reserved Names`.
- **Reconciliation with the standard path** compares data and resource totals only — the flat output deliberately does not reproduce groupings, appearance or drill-down.

### Wiring a command into the БСП report form

For reports rendered on the standard `ВариантыОтчетов.ФормаОтчета` (no own form):

1. **Report object module** — `ОпределитьНастройкиФормы` sets `Настройки.События.ПриСозданииНаСервере = Истина`; `ПриСозданииНаСервере` adds the command (`Форма.Команды.Добавить(...)` with `Действие = "Подключаемый_Команда"`) and places it via `ОтчетыСервер.ВывестиКоманду(Форма, Команда, "Главное")`.
2. **`ОтчетыКлиентПереопределяемый.ОбработчикКоманды`** — branch on `ФормаОтчета.ИмяФормы` + `Команда.Имя` to the client method.
3. **The server-side composition code must live in the form module** (`ОбщаяФорма.ФормаОтчета`), not in a common server module: only there is `РеквизитФормыВЗначение("Отчет")` available to get the report object on the server.

Client-server traffic carries **serialisable** data only (`НастройкиКомпоновкиДанных` serialises; a form object does not). Return large results through temporary storage (`ПоместитьВоВременноеХранилище` / `ПолучитьИзВременногоХранилища`).

---

## 3. Companion rules

| Concern | File |
|---|---|
| Ordinary DCS design and the standard programmatic override | `dcs-design.md` |
| `.dcs` XML / schema mechanics | `content/skills/1c-metadata-manage/docs/skd-manage.md` |
| Query performance and anti-patterns | `anti-patterns.md`, `query-design.md` |
| Reserved form-attribute names | `form-module.md → Reserved Names` |
| Long-running composition in the background | `platform-solutions.md §2 → Long-running operations` |
