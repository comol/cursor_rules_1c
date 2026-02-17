# 1C Help Manage — Built-in Help Management

Adds built-in help to a 1C metadata object: help metadata file (`Help.xml`), HTML page, and optionally updates form metadata.

## Usage

```
1c-help-manage <ObjectName> [Lang] [SrcDir]
```

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| ObjectName | yes | — | Object name (e.g., data processor name) |
| Lang | no | `ru` | Help language code |
| SrcDir | no | `src` | Source directory |

## Command

```powershell
powershell.exe -NoProfile -File skills/1c-metadata-manage/tools/1c-help-manage/scripts/add-help.ps1 -ProcessorName "<ObjectName>" [-Lang "<Lang>"] [-SrcDir "<SrcDir>"]
```

## What Gets Created

```
<SrcDir>/<ObjectName>/
    Ext/
        Help.xml                    # Help metadata (extrnprops namespace)
        Help/
            ru.html                 # HTML help page
```

- `Help.xml` — fixed structure with `<Page>ru</Page>` (namespace `http://v8.1c.ru/8.3/xcf/extrnprops`)
- `ru.html` — HTML 4.0 Transitional with 1C stylesheet link (`v8help://service_book/service_style`)
- Help is **not registered** in `ChildObjects` of the root XML — file presence is sufficient

## What Gets Modified

- If form metadata (`Forms/<FormName>.xml`) lacks `<IncludeHelpInContents>`, the script adds `<IncludeHelpInContents>false</IncludeHelpInContents>` after `<FormType>`. For forms created via `1c-form-scaffold`, this element already exists.

## Help Button on the Form

After creating help, a button is needed on the form to invoke it. Add button `Form.StandardCommand.Help` to the AutoCommandBar of the form (`Forms/<FormName>/Ext/Form.xml`).

### Current AutoCommandBar Structure (from 1c-form-scaffold)

```xml
<AutoCommandBar name="FormCommandBar" id="-1">
    <Autofill>true</Autofill>
</AutoCommandBar>
```

### Replace With

```xml
<AutoCommandBar name="FormCommandBar" id="-1">
    <Autofill>true</Autofill>
    <ChildItems>
        <Button name="FormHelp" id="{{free_id}}">
            <Type>CommandBarButton</Type>
            <CommandName>Form.StandardCommand.Help</CommandName>
            <ExtendedTooltip name="FormHelpExtendedTooltip" id="{{free_id + 1}}"/>
        </Button>
    </ChildItems>
</AutoCommandBar>
```

### Choosing IDs

Review all `id="..."` in `Form.xml` and choose the next free numeric ID. Typically IDs start at 1 and go sequentially. The button needs 2 IDs: one for Button, one for ExtendedTooltip.

### Important

- `Form.StandardCommand.Help` — standard platform command, no declaration needed in `<Commands>`
- No handler needed in Module.bsl — the platform finds `Help.xml` and opens HTML automatically

## Editing Help

After creation, help content is regular HTML. Edit `Ext/Help/ru.html` according to the object's purpose. Supported HTML markup: `<h1>`..`<h4>`, `<p>`, `<ul>`, `<ol>`, `<table>`, `<strong>`, `<em>`, `<a>`, `<pre>`.
