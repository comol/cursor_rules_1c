#!/usr/bin/env python3
# remove-form v1.4 — Remove form from 1C object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills (MIT), pinned at
#         ecd289fe11733028d87b55284ea9fb5feff8f513 — the same upstream state the
#         vendored remove-form.ps1 v1.4 was synced from.
# Local: preflight parse + -DryRun / -Force safety gate on top of upstream v1.4,
#        mirroring remove-form.ps1. Upstream deletes the form files first and
#        parses the root XML afterwards, so a parse failure leaves a half-removed
#        tree and any run deletes without confirmation; the local order is
#        parse -> plan -> gate -> atomic root-XML write -> delete.

import argparse
import os
import re
import shutil
import sys

from lxml import etree

NSMAP = {"md": "http://v8.1c.ru/8.3/MDClasses"}


def _detect_xml_style(path):
    """Стиль существующего файла для round-trip-сохранения: BOM / EOL / регистр encoding /
    финальный перенос. None → файл новый (сохранить текущее поведение)."""
    try:
        raw = open(path, "rb").read()
    except OSError:
        return None
    bom = raw.startswith(b"\xef\xbb\xbf")
    body = raw[3:] if bom else raw
    crlf = b"\r\n" in body
    m = re.search(rb'encoding="([^"]+)"', body[:200])
    enc = m.group(1).decode("ascii") if m else "utf-8"
    final_nl = body.endswith(b"\n")
    return {"bom": bom, "crlf": crlf, "enc": enc, "final_nl": final_nl}


def _finalize_xml_bytes(xml_bytes, style):
    """Привести сериализованные байты к стилю оригинала (или к дефолту, если style is None)."""
    enc_decl = style["enc"] if style else "utf-8"
    xml_bytes = xml_bytes.replace(
        b"<?xml version='1.0' encoding='UTF-8'?>",
        b'<?xml version="1.0" encoding="' + enc_decl.encode("ascii") + b'"?>')
    # Канонизировать переносы к LF (убирает &#13; от \r в tail'ах)
    xml_bytes = (xml_bytes.replace(b"&#13;\n", b"\n").replace(b"&#13;", b"")
                 .replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
    # Финальный перенос — как в оригинале (новый файл → есть)
    want_final_nl = style["final_nl"] if style else True
    xml_bytes = xml_bytes.rstrip(b"\n")
    if want_final_nl:
        xml_bytes += b"\n"
    # EOL — как в оригинале (новый файл → LF, текущее поведение)
    if style and style["crlf"]:
        xml_bytes = xml_bytes.replace(b"\n", b"\r\n")
    return xml_bytes


def render_xml_with_bom(tree, path):
    """Serialize the tree into the bytes that would replace *path*, preserving its
    BOM / EOL / encoding-case / final-newline. Split out of the upstream
    save_xml_with_bom so the safety gate can render before committing anything."""
    style = _detect_xml_style(path)
    xml_bytes = etree.tostring(tree, xml_declaration=True, encoding="UTF-8")
    xml_bytes = _finalize_xml_bytes(xml_bytes, style)
    if style is None or style["bom"]:
        xml_bytes = b"\xef\xbb\xbf" + xml_bytes
    return xml_bytes


def write_atomic(path, payload):
    """Write *payload* through a temporary file next to the target and rename it
    into place, so a failed write leaves the original root XML intact instead of
    truncating it. Upstream saves straight over the file."""
    tmp = path + ".remove-form.tmp"
    try:
        with open(tmp, "wb") as handle:
            handle.write(payload)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass
        raise


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Remove form from 1C object", allow_abbrev=False)
    parser.add_argument("-ObjectName", "-ProcessorName", required=True)
    parser.add_argument("-FormName", required=True)
    parser.add_argument("-SrcDir", default="src")
    # Local: same safety switches as remove-form.ps1.
    parser.add_argument("-DryRun", action="store_true",
                        help="Print the full plan and change nothing.")
    parser.add_argument("-Force", action="store_true",
                        help="Authorize the deletion. Without it the run stops before any mutation.")
    args = parser.parse_args()

    object_name = args.ObjectName
    form_name = args.FormName
    src_dir = args.SrcDir

    # --- Checks ---

    root_xml_path = os.path.join(src_dir, f"{object_name}.xml")
    if not os.path.exists(root_xml_path):
        print(f"Корневой файл обработки не найден: {root_xml_path}", file=sys.stderr)
        sys.exit(1)

    processor_dir = os.path.join(src_dir, object_name)
    forms_dir = os.path.join(processor_dir, "Forms")
    form_meta_path = os.path.join(forms_dir, f"{form_name}.xml")
    form_dir = os.path.join(forms_dir, form_name)

    if not os.path.exists(form_meta_path):
        print(f"Метаданные формы не найдены: {form_meta_path}", file=sys.stderr)
        sys.exit(1)

    # --- Preflight: parse and modify XML in memory before deleting anything ---

    root_xml_full = os.path.abspath(root_xml_path)
    parser_xml = etree.XMLParser(remove_blank_text=False)
    tree = etree.parse(root_xml_full, parser_xml)
    root = tree.getroot()

    # Remove <Form>FormName</Form> from ChildObjects
    form_node_found = False
    for node in root.findall(".//md:ChildObjects/md:Form", NSMAP):
        if node.text and node.text.strip() == form_name:
            form_node_found = True
            parent = node.getparent()
            prev = node.getprevious()
            if prev is not None:
                # Whitespace is in prev.tail
                if prev.tail and prev.tail.strip() == "":
                    prev.tail = ""
            else:
                # First child — whitespace is in parent.text
                if parent.text and parent.text.strip() == "":
                    parent.text = ""
            parent.remove(node)
            break
    if not form_node_found:
        print(f"Form is not registered in ChildObjects: {form_name}", file=sys.stderr)
        sys.exit(1)

    # Clear any Default*/Auxiliary* form slot that pointed to the removed form
    # (form-add writes the purpose-specific property: DefaultObjectForm / DefaultListForm /
    #  DefaultChoiceForm / DefaultRecordForm / DefaultForm — not just generic DefaultForm).
    cleared_default_properties = []
    ref_re = re.compile(rf"Form\.{re.escape(form_name)}$")
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        if etree.QName(el).localname.endswith("Form") and el.text and ref_re.search(el.text):
            el.text = ""
            cleared_default_properties.append(etree.QName(el).localname)

    # Render now: a serialization failure must surface before anything is deleted.
    payload = render_xml_with_bom(tree, root_xml_full)

    # --- Safety gate ---

    print("Planned changes:")
    print(f"  modify: {root_xml_path} (remove ChildObjects/Form '{form_name}')")
    for property_name in cleared_default_properties:
        print(f"  modify: {root_xml_path} (clear {property_name})")
    print(f"  delete: {form_meta_path}")
    if os.path.isdir(form_dir):
        print(f"  delete: {form_dir} (recursive)")

    if args.DryRun:
        print("[DRY-RUN] No files changed.")
        sys.exit(0)
    if not args.Force:
        print("Removal requires explicit -Force. Run with -DryRun first to review the plan.",
              file=sys.stderr)
        sys.exit(2)

    # Commit the root registration change before deleting files: the temporary
    # file keeps the source tree untouched if the write fails.
    write_atomic(root_xml_full, payload)

    if os.path.isdir(form_dir):
        shutil.rmtree(form_dir)
        print(f"[OK] Removed directory: {form_dir}")
    os.remove(form_meta_path)
    print(f"[OK] Removed file: {form_meta_path}")
    print(f"[OK] Form {form_name} removed from {root_xml_path}")


if __name__ == "__main__":
    main()
