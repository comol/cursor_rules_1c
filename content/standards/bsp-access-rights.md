---
description: Programmatic work with БСП access-group profiles and rights — `ПрофилиГруппДоступа` structure, the `Роли.Роль` reference type, extension roles, assigning profiles to users, and the right / role / RLS check API. Load when code creates or updates access profiles, assigns them, or checks rights on a БСП-based configuration.
alwaysApply: false
category: development
---

# БСП access-group profiles and rights — programmatic API

Applies to БСП / SSL 3.x configurations (ЗУП 3.1, БП 3.x, ERP 2.x, УТ 11.x): creating and updating `Справочник.ПрофилиГруппДоступа` from a code console or an update handler, assigning profiles to users, and checking rights, roles and RLS access.

> **Scope.** This file owns the *programmatic* side of access rights. Role **design** — which rights a role grants, RLS templates, role composition — lives in `content/skills/1c-metadata-manage/docs/role-manage.md`. Privileged-mode discipline in reports — `dcs-design.md §6`.

## 1. `Роли.Роль` is a reference, not a string

The tabular-section attribute `Справочник.ПрофилиГруппДоступа.Роли.Роль` has type **`СправочникСсылка.ИдентификаторыОбъектовМетаданных`** — not a string holding the role name.

```bsl
// WRONG — the value is silently discarded
НоваяСтрока = Профиль.Роли.Добавить();
НоваяСтрока.Роль = "ПолныеПрава";
```

**Symptom.** `Профиль.Записать()` succeeds without any error, but the tabular section ends up with 0–1 rows instead of the expected N. The БСП write handler filters out invalid values rather than raising.

The catalog's `ПолноеИмя` for a role is `"Роль." + ИмяРоли`.

## 2. Extension roles live in a different catalog

Objects of **configuration extensions** (roles, catalogs, documents) are registered in `Справочник.ИдентификаторыОбъектовРасширений`, not in `ИдентификаторыОбъектовМетаданных`. `ПрофилиГруппДоступа.Роли.Роль` is therefore of a **composite** type (`CatalogRef.ИдентификаторыОбъектовРасширений` + `CatalogRef.ИдентификаторыОбъектовМетаданных`).

Consequence: a direct query against `Справочник.ИдентификаторыОбъектовМетаданных` **does not find extension roles** — the profile silently gets only the base-configuration ones. On any configuration that has extensions, resolve names through the БСП method that covers both catalogs:

```bsl
ПолныеИмена = Новый Массив;
Для Каждого ИмяРоли Из ИменаРолей Цикл
	ПолныеИмена.Добавить("Роль." + ИмяРоли);
КонецЦикла;

// Соответствие [ПолноеИмя -> ссылка] — метаданных ИЛИ расширений.
// ВызыватьИсключение = Ложь — ненайденные пропускаются, без исключения.
КартаИдентификаторов = ОбщегоНазначения.ИдентификаторыОбъектовМетаданных(ПолныеИмена, Ложь);
СсылкаИдент = КартаИдентификаторов.Получить("Роль." + ИмяРоли);
```

A direct query is acceptable **only** on a configuration without extensions:

```bsl
Запрос = Новый Запрос;
Запрос.Текст =
"ВЫБРАТЬ РАЗРЕШЕННЫЕ
|	Идентификаторы.ПолноеИмя КАК ПолноеИмя,
|	Идентификаторы.Ссылка    КАК Ссылка
|ИЗ
|	Справочник.ИдентификаторыОбъектовМетаданных КАК Идентификаторы
|ГДЕ
|	Идентификаторы.ПолноеИмя В (&ПолныеИмена)
|	И НЕ Идентификаторы.ПометкаУдаления";
Запрос.УстановитьПараметр("ПолныеИмена", ПолныеИмена);
```

For a single role, `ОбщегоНазначения.ИдентификаторОбъектаМетаданных(Метаданные.Роли["ИмяРоли"])` returns the reference and **creates the catalog entry if it is missing** — useful right after a new role is added to the configuration and БСП has not registered it yet.

**In the profile UI, roles are shown by `Синоним`, not by `Имя`.** Filtering the visible list by a name prefix (e.g. `Расш_`) finds nothing when the role has a human-readable synonym. Search by synonym, or fill the profile programmatically.

## 3. Create / update template

```bsl
УстановитьПривилегированныйРежим(Истина);

ИмяПрофиля = "Имя профиля";

// 1. ИменаРолей — Массив имён ролей.
// 2. КартаИдентификаторов — по §2.

// 3. Найти или создать профиль.
СсылкаПрофиля = Справочники.ПрофилиГруппДоступа.НайтиПоНаименованию(ИмяПрофиля, Истина);
Если СсылкаПрофиля.Пустая() Тогда
	Профиль = Справочники.ПрофилиГруппДоступа.СоздатьЭлемент();
	Профиль.Наименование = ИмяПрофиля;
Иначе
	Профиль = СсылкаПрофиля.ПолучитьОбъект();
	Если Профиль.ПоставляемыйПрофиль Тогда
		ВызватьИсключение НСтр("ru = 'Поставляемый профиль — редактирование запрещено.'");
	КонецЕсли;
КонецЕсли;

// 4. Роли — ссылками, не строками (§1).
Профиль.Роли.Очистить();
Для Каждого ИмяРоли Из ИменаРолей Цикл
	СсылкаИдент = КартаИдентификаторов.Получить("Роль." + ИмяРоли);
	Если СсылкаИдент = Неопределено Тогда
		Продолжить;
	КонецЕсли;
	НоваяСтрока = Профиль.Роли.Добавить();
	НоваяСтрока.Роль = СсылкаИдент;
КонецЦикла;

// 5. Назначение (Пользователи / ВнешниеПользователи) — заполнить, если пусто.
Если Профиль.Назначение.Количество() = 0 Тогда
	Назначение = Профиль.Назначение.Добавить();
	Назначение.ТипПользователей = Справочники.Пользователи.ПустаяСсылка();
КонецЕсли;

// 6. Запись — БЕЗ ОбменДанными.Загрузка (см. §6).
Профиль.Записать();
```

Roles that were not resolved are skipped by `Продолжить`. **Count them and report** — a silently short role list is exactly the failure mode of §1 and §2, and it looks identical to success.

## 4. Assigning a profile to a user

Stable API of the `УправлениеДоступом` common module (server, `ПрограммныйИнтерфейс` region):

```bsl
// Профиль — ссылка ПрофилиГруппДоступа, УникальныйИдентификатор поставляемого
// профиля, или его строковое имя.
УправлениеДоступом.ВключитьПрофильПользователю(Пользователь, Профиль);

// Профиль = Неопределено — отключить все профили пользователя.
УправлениеДоступом.ВыключитьПрофильПользователю(Пользователь, Профиль = Неопределено);

// Полная переустановка прав: массивы групп доступа (или профилей) и групп пользователей.
УправлениеДоступом.УстановитьПраваПользователя(Пользователь, ГруппыДоступа, ГруппыПользователей);
```

`Пользователь` is a `СправочникСсылка.Пользователи` or `СправочникСсылка.ВнешниеПользователи`.

- There is **no** `УправлениеДоступом.ДобавлениеПользователейВГруппу` in БСП. Assignment is `ВключитьПрофильПользователю`; a full reset is `УстановитьПраваПользователя`.
- `ВключитьПрофильПользователю` targets the **simplified** rights-setup mode (it creates / finds a personal access group). In non-simplified mode work through access groups via `УстановитьПраваПользователя`.

## 5. Checking rights, roles and RLS

Exact signatures (all server-side, `ПрограммныйИнтерфейс`):

```bsl
// Роли конфигурации: имена ЧЕРЕЗ ЗАПЯТУЮ СТРОКОЙ (не массив).
// Истина — если доступна хотя бы одна.
Пользователи.РолиДоступны(ИменаРолей, Пользователь = Неопределено, УчитыватьПривилегированныйРежим = Истина)

Пользователи.ЭтоПолноправныйПользователь(Пользователь = Неопределено, ПроверятьПраваАдминистрированияСистемы = Ложь, УчитыватьПривилегированныйРежим = Истина)

// СсылкаНаОбъект — ссылка на объект ДАННЫХ (папка файлов и т.п.), НЕ объект метаданных.
УправлениеДоступом.ЕстьПраво(Право, СсылкаНаОбъект, Знач Пользователь = Неопределено)

// Роль в профилях групп доступа, с учётом RLS на чтение.
УправлениеДоступом.ЕстьРоль(Знач Роль, Знач СсылкаНаОбъект = Неопределено, Знач Пользователь = Неопределено)

// RLS на уровне записей — функции, возвращают Булево.
УправлениеДоступом.ЧтениеРазрешено(ОписаниеДанных, Пользователь = Неопределено)
УправлениеДоступом.ИзменениеРазрешено(ОписаниеДанных, Пользователь = Неопределено)
// Те же проверки процедурами — вызывают исключение при запрете.
УправлениеДоступом.ПроверитьЧтениеРазрешено(ОписаниеДанных)
УправлениеДоступом.ПроверитьИзменениеРазрешено(ОписаниеДанных)
```

- The platform's own `РольДоступна("ПолныеПрава")` ignores privileged mode and full-rights status. On a БСП configuration use `Пользователи.РолиДоступны` / `Пользователи.ЭтоПолноправныйПользователь` instead.
- `ЕстьРоль` checks the role **in access-group profiles**, with read-level RLS applied. To check a configuration role without RLS, use `Пользователи.РолиДоступны`.
- `ЕстьПраво` takes a **data** reference as its second argument; passing `Метаданные.*` is an error. The set of applicable rights is defined by the `УправлениеДоступомПереопределяемый` hook — there is no `УправлениеДоступом.НастройкиПрав` method.
- `ЧтениеРазрешено` / `ИзменениеРазрешено` concern record-level RLS. In the standard (non-performance) RLS variant, passing a user other than the current one raises an exception — check `УправлениеДоступом.ПроизводительныйВариант()` first.
- Client-side equivalent for full rights: `ПользователиКлиент.ЭтоПолноправныйПользователь(ПроверятьПраваАдминистрированияСистемы = Ложь)`, current user only.

## 6. Anti-patterns

| Anti-pattern | What actually happens |
|---|---|
| Assigning a **string** to `Роли.Роль` | Silently dropped by the БСП write handler; profile writes "successfully" with a short role list (§1). |
| Resolving roles by direct query on a configuration **with extensions** | Extension roles are missed silently; the profile is incomplete (§2). |
| `Профиль.ОбменДанными.Загрузка = Истина` before `Записать()` | Disables the БСП handlers — the profile row is written but never registered in the access-management subsystem, and the rights cache is not rebuilt. The profile exists and grants nothing. |
| Editing a profile with `ПоставляемыйПрофиль = Истина` | The write succeeds, and the next configuration update restores the vendor state. Create a separate user profile instead. |
| Matching input role names against `Синоним` with a naive comparison | Source data (spreadsheets, docs) uses synonyms with inconsistent case and doubled spaces. Match on `Синоним` first, then on a normalised form (`НРег` + `СокрЛП` + collapsed double spaces). |

## 7. Companion rules

| Concern | File |
|---|---|
| Role structure, rights and RLS in metadata | `content/skills/1c-metadata-manage/docs/role-manage.md` |
| Extension-side constraints on adopted objects | `extension-patterns.md` |
| БСП / SSL subsystem patterns | `standards(name="dev-standards-architecture") §4` and `content/skills/mcp-1c-tools/docs/1c-ssl-mcp.md` |
| Privileged mode in reports | `dcs-design.md §6` |
| Logging of rights changes | `logging-strategy.md` |

Some scenarios adapted from [brake71/1c-ssl-skills](https://github.com/brake71/1c-ssl-skills) (MIT) via [Desko77/claude-code-skills-1c](https://github.com/Desko77/claude-code-skills-1c) (MIT).
