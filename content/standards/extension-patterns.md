---
description: 1C configuration extension (CFE) patterns — interceptor types (`&Перед` / `&После` / `&Вместо` / `&ИзменениеИКонтроль`), `ПродолжитьВызов` rules, change markers, adopted-object constraints. Load when writing or reviewing extension code.
alwaysApply: false
category: architecture
---

# 1C Extension Patterns (CFE)

BSL patterns for working with 1C configuration extensions.

Applies to: extension code (`**/Extensions/**/*.bsl` and similar).

Background reference: `dev-standards-architecture.md §2` (Extensions) — modification priority, directives, placement rules. This file is the **practical** companion: interceptor types, `ПродолжитьВызов` semantics, markers, and adopted-object constraints.

> **Naming convention used in examples.** Below, `Расш1_` / `МоеРасш_` denotes the **extension's own short alias** (set in the extension's properties — typically the `Имя` of the extension or an explicit alias), **not** `{PREFIX}` from `.dev.env`. `{PREFIX}` applies to new metadata objects and attributes; the extension alias applies to procedure / function names introduced by the extension and prevents name collisions between extensions. The two are independent: an extension can both add a new attribute `{PREFIX}Признак` to a typical object and define an interceptor procedure `Расш1_ПриЗаписи` in the same module.
>
> The alias itself MUST NOT contain the letter «ё» — see `dev-standards-code-style.md → Typography`. Use `МоеРасш_`, `Расш1_`, `MyExt_` or any «ё»-free form.

---

## Interceptor types

| Directive | Type | When to use |
|-----------|------|-------------|
| `&Перед("ИмяМетода")` | Before | Code before the original method |
| `&После("ИмяМетода")` | After | Code after the original method |
| `&Вместо("ИмяМетода")` | Instead | Full replacement of the method; call the original via `ПродолжитьВызов()` when needed |
| `&ИзменениеИКонтроль("ИмяМетода")` | ModificationAndControl | Controlled edit of a **copy** of the original body with `#Вставка` / `#Удаление` markers |

Prefer `&Перед` / `&После`. Use `&Вместо` or `&ИзменениеИКонтроль` only when before/after cannot achieve the result. At most one `&ИзменениеИКонтроль` (or competing `&Вместо`) may apply to a given method across extensions — see platform apply rules.

### Before / After — simple interceptors

```bsl
&НаСервере
&Перед("ПриЗаписи")
Процедура Расш1_ПриЗаписи()
    // Runs BEFORE the original ПриЗаписи
КонецПроцедуры

&НаСервере
&После("ПриЗаписи")
Процедура Расш1_ПослеЗаписи()
    // Runs AFTER the original ПриЗаписи
КонецПроцедуры
```

### Вместо — full replacement

```bsl
&НаСервере
&Вместо("ОбработкаПроведения")
Процедура Расш1_ОбработкаПроведения(Отказ, РежимПроведения)

    // Code before the original

    ПродолжитьВызов(Отказ, РежимПроведения);

    // Code after the original (same context)

КонецПроцедуры
```

For a function, capture and return the result:

```bsl
&Вместо("ПолучитьЦену")
Функция Расш1_ПолучитьЦену(Номенклатура)

    Результат = ПродолжитьВызов(Номенклатура);
    // adjust Результат if needed
    Возврат Результат;

КонецФункции
```

### ИзменениеИКонтроль — controlled body edit

The interceptor body is a **copy of the original**. Every own change must be marked; unmarked lines must match the vendor original verbatim (the "control" part). There is **no** `ПродолжитьВызов()` — the modified body *is* what runs in place of the original.

```bsl
&НаСервере
&ИзменениеИКонтроль("ОбработкаЗаполнения")
Процедура Расш1_ОбработкаЗаполнения(ДанныеЗаполнения, СтандартнаяОбработка)

    // … unmarked original lines (must match the vendor method) …

#Удаление
    // Original lines being removed (kept between markers for control)
#КонецУдаления
#Вставка
    // Replacement / new code
#КонецВставки

    // … further unmarked original lines …

КонецПроцедуры
```

---

## ПродолжитьВызов() rules

- `&Перед` — the original runs automatically afterwards. **Do not call** `ПродолжитьВызов()`.
- `&После` — the original has already executed; `ПродолжитьВызов()` is **not** used.
- `&Вместо` — the original does **not** run unless you call `ПродолжитьВызов(...)` (pass the same arguments; for functions, use the return value). Omitting it means only the extension body runs.
- `&ИзменениеИКонтроль` — `ПродолжитьВызов()` is **not** used. The body is the controlled copy of the original; edits go through `#Вставка` / `#Удаление` only.

---

## Change markers

Markers are **required** inside `&ИзменениеИКонтроль` to track changes:

| Marker | Purpose |
|--------|---------|
| `#Вставка` / `#КонецВставки` | New code added by the extension |
| `#Удаление` / `#КонецУдаления` | Original code that was removed (lines stay between markers for control) |

Markers preserve diff/merge semantics when the base configuration is updated and the extension needs to be re-synced (`cfe-patch-method -Check` / `-Actualize`). Put each marker on its **own line at column 0** (no indentation).

---

## Constraints on adopted (borrowed) objects

- An adopted object (`ObjectBelonging=Adopted`) is **not a copy** — it is a reference to a base-configuration object brought into the extension's scope so that the extension can attach interceptors and add its own attributes / tabular sections / form elements. The original definition still lives in the base configuration; on a base-configuration update the adopted object is automatically re-read, and the extension is re-applied on top of it.
- You **cannot** delete existing attributes / tabular sections of an adopted object — they belong to the base configuration.
- You **can** add your own attributes / tabular sections (with `{PREFIX}` from `.dev.env`).
- Modules of adopted objects — interceptors only (`&Перед` / `&После` / `&Вместо` / `&ИзменениеИКонтроль`), no direct edits to the original procedure body.
- Forms of adopted objects — you can add elements, you cannot delete existing ones.

---

## Anti-patterns

### Direct edit of an adopted module

```bsl
// WRONG: editing original code in place
Процедура ПриЗаписи()
    // changed code...
КонецПроцедуры

// RIGHT: interceptor
&Перед("ПриЗаписи")
Процедура Расш1_ПриЗаписи()
    // additional code
КонецПроцедуры
```

### Forgotten ПродолжитьВызов in &Вместо

```bsl
// DANGEROUS: original method will not execute!
&Вместо("ОбработкаПроведения")
Процедура Расш1_ОбработкаПроведения(Отказ, РежимПроведения)
    // own code only...
    // FORGOT: ПродолжитьВызов(Отказ, РежимПроведения);
КонецПроцедуры
```

### ПродолжитьВызов inside &ИзменениеИКонтроль

```bsl
// WRONG: ПродолжитьВызов is for &Вместо, not for controlled edits
&ИзменениеИКонтроль("ОбработкаПроведения")
Процедура Расш1_ОбработкаПроведения(Отказ, РежимПроведения)
    // …
    ПродолжитьВызов(Отказ, РежимПроведения); // do not
КонецПроцедуры

// RIGHT: edit the copied body with #Вставка / #Удаление only
```

### No prefix in extension method names

```bsl
// Bad: name conflict with other extensions
Процедура ДополнительнаяПроверка()

// Good: extension prefix
Процедура МоеРасш_ДополнительнаяПроверка()
```

---

## Extension purpose tag

Set the `Purpose` (Назначение) of the extension in its properties:

| Type | Purpose | When to use |
|------|---------|-------------|
| Patch | `Patch` | Minimal changes, interceptors only |
| Customization | `Customization` | Attributes, forms, modules |
| AddOn | `AddOn` | Full new functionality |

The `Purpose` value affects update behaviour and the way the platform reapplies the extension after a base-configuration update.
