---
description: when working on form modules (ФормаМодуль, Form.Module.bsl)
globs: "**/Form.Module.bsl"
alwaysApply: false
category: forms
---

# Form Module Guidelines

## Client-Server Interaction

- Minimize client-server round trips in form modules.
- Group multiple server calls into a single call when possible.
- Avoid calling server methods in loops on the client side.

## Compilation Directives

Available compilation directives for form module methods:

| Directive | Context | Use Case |
|-----------|---------|----------|
| `&НаКлиенте` | Client-side execution | UI interactions, user input handling |
| `&НаСервере` | Server-side with form context | When you need to modify form attributes/items |
| `&НаСервереБезКонтекста` | Server-side without form context | **Preferred** for data operations when form context is not needed (reduces data transfer) |
| `&НаКлиентеНаСервереБезКонтекста` | Both client and server without context | Shared utility functions |

- Prefer `&НаСервереБезКонтекста` over `&НаСервере` when form context is not required — it reduces network traffic.

## Async Programming

- Prefer `Асинх` (async) methods over `ОписаниеОповещения` (notification description) when async analogues are available.
- Use `Ждать` (Await) for cleaner async code flow.

## Form Data

- Use `ДанныеФормыВЗначение()` / `ЗначениеВДанныеФормы()` to convert between form data and actual objects.
- Remember that form attributes are not the same as object attributes — they are form-specific representations.
