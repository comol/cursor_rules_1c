---
description: Managed locks, transaction boundaries, lock ordering, deadlock prevention, shared / exclusive lock modes, monitoring via the technological log. Load when designing posting / multi-document operations, debugging lock conflicts, or extending an existing transactional path.
alwaysApply: false
category: quality
---

# Locks and Transactions — Design Rules

The 1C platform offers two locking subsystems (automatic / managed) and an implicit-transaction model around object writes. Most production lock incidents come from mixing the two, opening unintended transactions, or holding locks across user dialogs. This file is the canonical home for those rules.

> **Scope.** This file owns the design rules. The narrow case "set a lock before reading balances during posting" lives as a worked example in `platform-solutions.md §9 → "Managed locks and deadlock prevention"` — that section now points back here for the general theory.

## 1. Lock mode of the configuration

Set the configuration property **«Режим управления блокировкой данных»** to `Управляемый` (Managed) for the whole configuration. Reasons:

- Mixed mode hides bugs — code written under automatic locking suddenly conflicts when the same data path is reached under managed mode.
- Managed mode is the only mode where lock granularity is under the developer's control (per-table / per-key, not per-row-page).
- Modern БСП subsystems assume managed mode.

Migrating an existing project from automatic to managed is a separate, multi-step task — out of scope here; use ITS "Перевод конфигурации на управляемый режим блокировки".

## 2. Transaction boundaries

### Implicit transactions

The platform opens its own transaction around:

- `Записать()` / `Записать(РежимЗаписиДокумента....)` on a reference object — wraps **`ПередЗаписью` → write → `ПриЗаписи` → posting (`ОбработкаПроведения`)**.
- `Удалить()` on a reference object.
- `НаборЗаписей.Записать()` for register record sets.
- Movement materialization at the end of `ОбработкаПроведения`.

**Inside an object's `ПередЗаписью` / `ПриЗаписи` / `ОбработкаПроведения`, do NOT open your own `НачалоТранзакции` / `ЗафиксироватьТранзакцию`.** The transaction is already there; a nested call fakes a savepoint but disables proper rollback on the outer error. See `platform-solutions.md §4 → "Transactions in event handlers"`.

### Explicit transactions in calling code

When the calling code needs to atomically write several objects or to combine a write with register edits, open the transaction there:

```bsl
НачалоТранзакции();

Попытка
	Документ.Записать(РежимЗаписиДокумента.Проведение);
	// ... additional changes ...
	ЗафиксироватьТранзакцию();
Исключение
	ОтменитьТранзакцию();

	ДанныеОшибки = Новый Структура;
	ДанныеОшибки.Вставить("Документ", Документ.Ссылка);
	ДанныеОшибки.Вставить("Подробно", ПодробноеПредставлениеОшибки(ИнформацияОбОшибке()));

	ЗаписьЖурналаРегистрации(
		"Проведение." + Документ.Метаданные().Имя + ".Ошибка",
		УровеньЖурналаРегистрации.Ошибка,
		Документ.Метаданные(),
		Документ.Ссылка,
		НСтр("ru = 'Не удалось провести документ.'"),
		ДанныеОшибки);

	ВызватьИсключение;
КонецПопытки;
```

The structured payload (`Данные = Структура`) and the dotted event name follow `logging-strategy.md §3-§5`; never log error context as a single concatenated string.

Rules:

- The `НачалоТранзакции()` → `Попытка` … `ЗафиксироватьТранзакцию()` → `Исключение` `ОтменитьТранзакцию()` `ВызватьИсключение` `КонецПопытки` shape (see the example above) is the **only** correct pattern. Any deviation (no `Попытка`, no `ОтменитьТранзакцию` in the catch branch, no re-raise) is a defect.
- **Diagnose, do not swallow.** Log the error and `ВызватьИсключение` — see `logging-strategy.md §5 → "Error / exception logging"`.
- **Re-check `ТранзакцияАктивна()`** before second `ОтменитьТранзакцию` only in diagnostics — normally the flow already guarantees it.

### Forbidden inside transactions

- **User dialogs** (`ВопросАсинх`, `ПоказатьЗначение`, file picker). Any wait on user input keeps the locks alive and stalls other sessions.
- **Long-running operations** (`ДлительныеОперации`, network calls, external components). Move them outside the transaction.
- **`ЗаписьЖурналаРегистрации` with `Сообщить`** in client context — the message goes to a UI that is blocked behind the transaction.

## 3. Managed-lock primitives

Lock managed data with `БлокировкаДанных`:

```bsl
Блокировка = Новый БлокировкаДанных;

ЭлементБлокировки = Блокировка.Добавить("РегистрНакопления.ТоварыНаСкладах");
ЭлементБлокировки.Режим = РежимБлокировкиДанных.Исключительный;
ЭлементБлокировки.ИсточникДанных = Товары;
ЭлементБлокировки.ИспользоватьИзИсточникаДанных("Номенклатура", "Номенклатура");
ЭлементБлокировки.ИспользоватьИзИсточникаДанных("Склад",       "Склад");

Блокировка.Заблокировать();
```

Rules:

- **Lock before reading**, then read, then write. Reading without a lock and then writing creates an unprotected gap that allows concurrent posting to write inconsistent balances.
- **Lock the register**, not the document. Locking the document does not protect the register; the next posting can still read stale balances.
- **`ИсточникДанных`**, not manual iteration. Always pass the document's tabular section (or a `ТаблицаЗначений` constructed from it) as `ИсточникДанных` and use `ИспользоватьИзИсточникаДанных` to map columns; the platform compiles one efficient lock request.
- **The lock lives until the end of the current transaction.** You cannot release it earlier; you can only finish the transaction.

### Modes

| `РежимБлокировкиДанных` | Use for |
|---|---|
| `Исключительный` | Read-modify-write paths: posting, mass write, recalculations. Blocks both readers and writers. |
| `Разделяемый` | Read paths that must remain consistent within the same transaction (e.g. a report that reads several registers under a single snapshot). Multiple shared locks are compatible; an exclusive lock against a shared one waits. |

Default: `Исключительный` for any write path. Use `Разделяемый` consciously — it does not protect from concurrent writers; it only blocks them from upgrading to exclusive while you read.

## 4. Lock ordering — the deadlock contract

A deadlock requires two transactions taking locks in different orders. The fix is to **fix the lock order project-wide**.

Establish a canonical ordering of locked tables and document it in `memory.md` as a project-wide rule. Example for a typical sales-and-warehouse configuration:

```
1. РегистрНакопления.ТоварыНаСкладах
2. РегистрНакопления.ТоварыКПередаче
3. РегистрНакопления.СвободныеОстатки
4. РегистрСведений.ЦеныНоменклатуры
5. РегистрНакопления.ВзаиморасчетыСКонтрагентами
```

Rules:

- Every posting that touches more than one register from this list locks them in the listed order. No exceptions.
- New registers added to the order — append, do not insert in the middle (renumbering breaks existing code reviews).
- Cross-document operations (one document posting another) inherit the same order — design the calling code to acquire locks in canonical order, then call subordinate operations.

If you observe a deadlock under load, the question is never "how do we retry" — it is "which transaction took locks out of order". Fix the order; retries are a band-aid.

## 5. Locking patterns

### Pattern: posting a document that touches several registers

```bsl
Процедура ОбработкаПроведения(Отказ, РежимПроведения)

	// 1. Build the lock object once, in canonical order.
	Блокировка = Новый БлокировкаДанных;

	БлокТовары = Блокировка.Добавить("РегистрНакопления.ТоварыНаСкладах");
	БлокТовары.Режим = РежимБлокировкиДанных.Исключительный;
	БлокТовары.ИсточникДанных = Товары;
	БлокТовары.ИспользоватьИзИсточникаДанных("Номенклатура", "Номенклатура");
	БлокТовары.ИспользоватьИзИсточникаДанных("Склад", "Склад");

	БлокВзаиморасчеты = Блокировка.Добавить("РегистрНакопления.ВзаиморасчетыСКонтрагентами");
	БлокВзаиморасчеты.Режим = РежимБлокировкиДанных.Исключительный;
	БлокВзаиморасчеты.УстановитьЗначение("Контрагент", Контрагент);

	Блокировка.Заблокировать();

	// 2. Read balances and validate.
	// 3. Write movements via Движения.X.Добавить / Записать = Истина.

КонецПроцедуры
```

### Pattern: mass operation across many documents

Drive the transaction at the caller, not per-document, when atomicity across documents is required. Otherwise wrap each document in its own transaction and continue on failure (logging each failure) — choose based on the business requirement.

Never hold a single transaction across thousands of documents — lock escalation and journal pressure cripple the cluster.

### Pattern: status update outside posting

For information registers used as a status log (`СтатусыЗаказов`, `СтатусыИнтеграции`), use a register-record-set write with `НаборЗаписей.Заблокировать()` inside an explicit transaction:

```bsl
НачалоТранзакции();

Попытка

	НаборЗаписей = РегистрыСведений.СтатусыИнтеграции.СоздатьНаборЗаписей();
	НаборЗаписей.Отбор.Заказ.Установить(СсылкаЗаказа);
	НаборЗаписей.Заблокировать();
	НаборЗаписей.Прочитать();

	// ... mutate the set ...

	НаборЗаписей.Записать();
	ЗафиксироватьТранзакцию();

Исключение
	ОтменитьТранзакцию();
	ВызватьИсключение;
КонецПопытки;
```

`НаборЗаписей.Заблокировать()` is the convenience form of a managed lock scoped to the set's filter — use it when the whole point is "I am about to rewrite these records".

## 6. Diagnosing lock conflicts and deadlocks

### Symptoms

- *"Конфликт блокировок при выполнении транзакции"* — sporadic timeout on a register; cause: another transaction holds the same key in an incompatible mode for longer than `MaxLockWait` (default 20 s).
- *"Deadlock"* — two transactions waiting for each other; cause: violated lock ordering (§4).
- *"Запись регистра не удалось получить"* during posting — usually a lock conflict on the underlying register, not on the register record set.

### Diagnostic tools

- **Technological log (`logcfg.xml`)** — turn on `TLOCK` and `TDEADLOCK` events for the failing register. The log records who holds what and what waits. This is the only authoritative source for "which two transactions deadlocked".
- **`ТранзакцияАктивна()`** — checks the current transaction is alive; useful only for self-consistency checks, not for cross-session diagnostics.
- **MS SQL DMVs (server infobase only)** — `sys.dm_tran_locks`, `sys.dm_os_waiting_tasks` for live snapshots when the technological log is not enough.
- **Posting replay** — re-post the failing document under the debugger to capture the exact lock call sequence.

See `systematic-debugging.md` for the surrounding methodology — locks must be diagnosed in the Reproduce → Hypothesize → Experiment → Fix order, not by guess-and-retry.

## 7. Companion rules

| Concern | File |
|---|---|
| Worked posting example | `platform-solutions.md §9 → "Managed locks and deadlock prevention"` |
| Transaction nesting in event handlers | `platform-solutions.md §4 → "Transactions in event handlers"` |
| Authoritative query rules under locks | `dev-standards-architecture.md §3 → "Queries"` |
| Logging lock-conflict events | `logging-strategy.md` |
| Systematic debugging of lock incidents | `systematic-debugging.md` |
| Register design (what gets locked) | `registers-design.md` |
