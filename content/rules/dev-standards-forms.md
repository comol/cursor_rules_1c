---
description: Development standards — module structure templates and form modification rules
globs: "**/Form.Module.bsl"
alwaysApply: false
category: forms
---

# Development Standards — Module Structure & Forms

## 1. Module Structure Templates

> Canonical region names are **Russian, БСП-style**. This is aligned with `AGENTS.md → "Module Regions"` and with baseline configurations. English names (`Public` / `Internal` / `Private`) MUST NOT be used — except when the whole configuration is already maintained in English locale with regions defined uniformly.

### Common Module

```bsl
#Область ПрограммныйИнтерфейс

#КонецОбласти

#Область СлужебныйПрограммныйИнтерфейс

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

#КонецОбласти
```

### Object / Manager Module

```bsl
#Если Сервер Или ТолстыйКлиентОбычноеПриложение Или ВнешнееСоединение Тогда

#Область ПрограммныйИнтерфейс

#КонецОбласти

#Область ОбработчикиСобытий

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

#КонецОбласти

#КонецЕсли
```

### Form Module

```bsl
#Область ОбработчикиСобытийФормы

#КонецОбласти

#Область ОбработчикиСобытийЭлементовШапкиФормы

#КонецОбласти

#Область ОбработчикиСобытийЭлементовТаблицыФормыИмяТаблицы

#КонецОбласти

#Область ОбработчикиКомандФормы

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

#КонецОбласти
```

> All 5 form-module regions are **mandatory**, even when empty. For every form tabular section create a separate region `ОбработчикиСобытийЭлементовТаблицыФормы<ИмяТаблицы>`.
> Regions inside procedures/functions are **forbidden**.

## 2. Form Modification Rules

### Programmatic Modification of Typical Forms
All typical form modifications are performed **programmatically**, not visually. Elements are created in `OnCreateAtServer` handler (or via subscription/extension).

### Placement of Added Elements
- If form has tabs — add elements to a separate tab (e.g., "Additional" or with `{PREFIX}`)
- If no tabs — create a group without title for added elements
- Typical form element names — with `{PREFIX}` prefix

### New Forms (Non-Typical Objects)
- Separate header attributes and tabular sections into distinct tabs: "Main" (header), then one tab per tabular section
- Fill "Header Data Path" property for pages with tabular sections
- Reference fields — maximum width 27 characters
- Multiline comment fields — width 79, height 3

### Fill Checking
- Use "Fill check" property on form attributes
- Before writing/posting, call `CheckFilling()`:

```bsl
Если Не ПроверитьЗаполнение() Тогда
	Возврат;
КонецЕсли;
```

### Form Commands
- When creating commands that modify data — enable "Modifies stored data" flag
