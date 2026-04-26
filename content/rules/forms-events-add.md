---
description: when adding event hooks to a 1C form
globs: "**/Form.Module.bsl"
alwaysApply: false
category: forms
---

# **IMPORTANT!** — don't forget to add the event hook to the form XML file.
The file is usually named `Form.xml` in the parent directory of the module code.

Event hooks in XML look like:

```xml
<Events>
	<Event name="OnOpen">ПриОткрытии</Event>
	<Event name="BeforeWrite">ПередЗаписью</Event>
	<Event name="OnCreateAtServer">ПриСозданииНаСервере</Event>
</Events>
```

Common form events (this is a **non-exhaustive subset** — the platform exposes dozens of form, item, and table events):

| XML Event Name | Russian Handler Name | Description |
|----------------|----------------------|-------------|
| `OnOpen` | `ПриОткрытии` | Client, when form opens |
| `OnClose` | `ПриЗакрытии` | Client, when form closes |
| `BeforeWrite` | `ПередЗаписью` | Client, before write |
| `AfterWrite` | `ПриЗаписи` | Client, after write |
| `OnCreateAtServer` | `ПриСозданииНаСервере` | Server, form creation |
| `BeforeWriteAtServer` | `ПередЗаписьюНаСервере` | Server, before write |
| `AfterWriteAtServer` | `ПриЗаписиНаСервере` | Server, after write |
| `OnReadAtServer` | `ПриЧтенииНаСервере` | Server, when reading object |

The value inside the `<Event>` tag is the name of the handler procedure in the form module.

## Getting the full event list

For the complete and authoritative list of available events, do **not** rely on this table. Use:

- `bsl_scope_members` with `member_type="events"` and the relevant context (e.g. `"УправляемаяФорма"`, `"ПолеФормы"`, `"ТаблицаФормы"`, `"КнопкаФормы"`).
- `inspect_form_layout` on a similar existing form — every wired-up event is listed under each element with its handler name.
- `docinfo` / `docsearch` against the platform documentation for the specific form-item type.
- `search_forms` to locate canonical examples that already use the event you need.
