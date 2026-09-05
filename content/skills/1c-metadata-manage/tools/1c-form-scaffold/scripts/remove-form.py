#!/usr/bin/env python3
# remove-form v1.4 — Remove form from 1C object
# Source: https://github.com/Nikolay-Shirokov/cc-1c-skills, pinned at
#         ecd289fe11733028d87b55284ea9fb5feff8f513 — the same upstream state the
#         vendored remove-form.ps1 v1.4 was synced from.
# Licence: MIT, Copyright (c) 2025-2026 Nick Shirokov. Full notice and permission
#          text: ../../../NOTICE.md (installed as
#          skills/1c-metadata-manage/NOTICE.md).
# Local: hardening on top of upstream v1.4, mirroring remove-form.ps1's contract.
#        Upstream deletes the form files first and parses the root XML afterwards,
#        accepts any string as a name, and has no confirmation gate. Here:
#          * names must be 1C identifiers and every resolved path must stay inside
#            the object's own Forms directory (no traversal, no symlink escape);
#          * -DryRun prints the plan and changes nothing; a real deletion needs
#            -Force and otherwise exits 2 before any mutation;
#          * the mutation itself is a bounded transaction — deletions are renames
#            into a quarantine on the same filesystem and every step has an undo,
#            so a failure anywhere restores the original tree.

import argparse
import os
import re
import shutil
import stat
import sys

from lxml import etree

NSMAP = {"md": "http://v8.1c.ru/8.3/MDClasses"}

QUARANTINE_NAME = ".remove-form-quarantine"

# A 1C metadata identifier: a Latin or Cyrillic letter or underscore, then letters,
# digits and underscores, up to the platform's 128-character limit. Deliberately an
# allowlist - it rejects path separators, `..`, drive letters, UNC prefixes, trailing
# dots and spaces (which Windows silently strips), embedded NULs, and look-alike
# letters from other scripts.
CYRILLIC = "А-яЁё"
IDENTIFIER_RE = re.compile(
    rf"^[A-Za-z_{CYRILLIC}][0-9A-Za-z_{CYRILLIC}]{{0,127}}$")


def die(message, code):
    print(message, file=sys.stderr)
    sys.exit(code)


def require_identifier(value, what):
    """Refuse anything that is not a plain 1C identifier, before any path is built."""
    if not IDENTIFIER_RE.match(value or ""):
        die(f"Недопустимое имя {what}: {value!r}. Ожидается идентификатор 1С "
            f"(латиница или кириллица, цифры и подчёркивание, не начинается с цифры, "
            f"до 128 символов).", 2)


def is_link_or_reparse(path):
    """True for a POSIX symlink and for a Windows symlink / junction / reparse point."""
    try:
        info = os.lstat(path)
    except OSError:
        return False
    if stat.S_ISLNK(info.st_mode):
        return True
    reparse = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    return bool(getattr(info, "st_file_attributes", 0) & reparse)


def require_inside(path, parent, what):
    """The resolved *path* must be a direct child of the resolved *parent*.

    realpath() collapses `..` and follows symlinks, so this catches both a name that
    escaped validation and a directory that was symlinked out of the tree. The
    explicit link check refuses the remaining case - a link that still resolves
    inside, where deleting the link is not what the caller asked for.

    On its own this is *not* containment: it compares a path against its immediate
    parent, so when that parent is itself a link both sides resolve into the same
    foreign directory and the check passes. require_chain() below anchors the whole
    chain at the one directory the caller actually vouched for."""
    real_parent = os.path.realpath(parent)
    real_path = os.path.realpath(path)
    if os.path.dirname(real_path) != real_parent:
        die(f"Путь {what} выходит за пределы каталога {real_parent}: {real_path}. "
            f"Операция отклонена.", 2)
    if is_link_or_reparse(path):
        die(f"Путь {what} является символической ссылкой / точкой повторной обработки: "
            f"{path}. Удаление отклонено — проверьте выгрузку вручную.", 2)


def require_chain(root, path, what):
    """Every component between the trusted *root* and *path* must be a real directory.

    -SrcDir is the only path the caller vouched for; everything under it is derived.
    A link or reparse point anywhere on the way - the object directory as much as
    Forms/ or the form itself - silently redirects the whole subtree elsewhere, and a
    parent-relative check cannot see it because it resolves both sides through the
    same link. So walk the chain from the trusted root down and refuse a redirect on
    any component, before the first mutation."""
    root_full = os.path.abspath(root)
    full = os.path.abspath(path)
    chain = []
    current = full
    while os.path.normcase(current) != os.path.normcase(root_full):
        chain.append(current)
        parent = os.path.dirname(current)
        if parent == current:
            die(f"Путь {what} выходит за пределы каталога {root_full}: {full}. "
                f"Операция отклонена.", 2)
        current = parent
    for component in chain:
        if is_link_or_reparse(component):
            die(f"Путь {what} проходит через символическую ссылку / точку повторной "
                f"обработки: {component}. Удаление отклонено — проверьте выгрузку "
                f"вручную.", 2)


class _Step:
    """One reversible step of the transaction.

    ``undo`` puts the original state back. ``recovery`` is the pair
    ``(copy inside the quarantine, path it belongs at)``, and ``outstanding()``
    answers the only question a rollback has to get right: is that copy still the
    *only* copy of this payload? For a parked file the answer is read off the
    filesystem - it is outstanding for exactly as long as it is still sitting in the
    quarantine - so no bookkeeping slip can make the quarantine look disposable
    while it is not."""

    def __init__(self, what, undo, recovery, still_needed):
        self.what = what
        self.undo = undo
        self.recovery = recovery
        self._still_needed = still_needed
        self.restored = False

    def outstanding(self):
        return self._still_needed(self)


class RollbackReport:
    """What the rollback managed to undo, and what it deliberately kept.

    ``outstanding`` lists ``(copy in the quarantine, path it belongs at)`` for every
    payload the rollback could not put back. While it is non-empty the quarantine is
    the only copy of those files, so it must survive whatever else went wrong."""

    def __init__(self, problems, outstanding, quarantine_kept):
        self.problems = problems
        self.outstanding = outstanding
        self.quarantine_kept = quarantine_kept


class Transaction:
    """Bounded filesystem transaction with an explicit undo stack.

    Every step registers its undo *before* it runs, so a failure at any point
    restores the original bytes and the original existence of every touched path.
    Deletions are renames into a quarantine directory on the same filesystem: a
    rename is atomic and reversible, unlike a recursive delete that can stop
    half-way. The quarantine is discarded once the whole transaction has committed -
    or once a rollback has verifiably put every payload back, and not before.

    Discarding it is deliberately *not* one of the undo steps. As a step it was the
    oldest one and therefore ran last, i.e. after earlier restores had already
    failed: the tree kept the hole, and the only surviving copy of the deleted files
    was deleted along with the quarantine the error message was pointing at."""

    def __init__(self, quarantine):
        self.quarantine = quarantine
        self.steps = []
        self.started = False

    def begin(self):
        # A leftover quarantine means a previous run died between rollback steps.
        # Refuse rather than write into it: its contents are the only copy left.
        if os.path.exists(self.quarantine):
            die(f"Найден каталог карантина от прерванного запуска: {self.quarantine}. "
                f"Проверьте его содержимое и удалите вручную, затем повторите операцию.", 2)
        os.makedirs(self.quarantine)
        self.started = True

    def backup_file(self, path):
        """Keep a copy so a later step can restore the original bytes."""
        backup = os.path.join(self.quarantine, "root-backup.xml")
        shutil.copyfile(path, backup)

        def restore():
            shutil.copyfile(backup, path)

        # A copy, not a move: it stops being the only copy once it is back in place,
        # so its own success flag is what decides - and a failed copy leaves it set.
        self.steps.append(_Step(f"restore {path}", restore, (backup, path),
                                lambda step: not step.restored))
        return backup

    def move_away(self, path, slot):
        """Delete by renaming into the quarantine - reversible and never partial."""
        parked = os.path.join(self.quarantine, slot)
        os.replace(path, parked)
        self.steps.append(_Step(f"put back {path}", lambda: os.replace(parked, path),
                                (parked, path),
                                lambda step: os.path.exists(step.recovery[0])))

    def replace_file(self, path, payload):
        """Swap in new bytes atomically; the undo is the backup taken earlier."""
        staged = os.path.join(self.quarantine, "root-new.xml")
        with open(staged, "wb") as handle:
            handle.write(payload)
        os.replace(staged, path)

    def commit(self):
        """Point of no return: drop the quarantine, and with it the deleted files."""
        self.steps = []
        shutil.rmtree(self.quarantine)
        self.started = False

    def rollback(self):
        """Undo every recorded step, newest first, then decide the quarantine's fate.

        The quarantine goes only when nothing is outstanding: no payload is still
        parked in it and every restore reported success. Otherwise it stays, and the
        caller is told which file in it belongs where."""
        problems = []
        for step in reversed(self.steps):
            try:
                step.undo()
                step.restored = True
            except Exception as exc:  # noqa: BLE001 - keep undoing the rest
                problems.append(f"{step.what}: {exc}")
        outstanding = [step.recovery for step in self.steps if step.outstanding()]
        self.steps = []
        self.started = False
        if outstanding:
            return RollbackReport(problems, outstanding, True)
        try:
            shutil.rmtree(self.quarantine)
        except OSError as exc:
            problems.append(f"remove quarantine {self.quarantine}: {exc}")
            return RollbackReport(problems, [], True)
        return RollbackReport(problems, [], False)


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


def drop_element_keeping_indent(node):
    """Remove *node* without disturbing the pretty-printing around it.

    lxml keeps the whitespace that follows an element in that element's ``tail``,
    and the whitespace before the first child in the parent's ``text``. Removing an
    element therefore also removes the indentation of the *next* sibling unless the
    tails are rearranged first:

      * middle / first element - dropping the node and its own tail is exactly
        right, the survivors keep their own indentation;
      * last element - its tail is the parent's closing indentation, so hand it to
        the previous sibling;
      * only element - the block becomes empty, so drop the parent's text as well
        and let it serialize as ``<ChildObjects/>``, the way Configurator writes it.
    """
    parent = node.getparent()
    if node.getnext() is None:
        previous = node.getprevious()
        if previous is not None:
            previous.tail = node.tail
        else:
            parent.text = None
    parent.remove(node)


def main():
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure:
            reconfigure(encoding="utf-8")
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

    # --- Input validation: before a single path is built ---

    require_identifier(args.ObjectName, "объекта (-ObjectName)")
    require_identifier(args.FormName, "формы (-FormName)")
    object_name = args.ObjectName
    form_name = args.FormName
    src_dir = args.SrcDir

    # --- Checks ---

    root_xml_path = os.path.join(src_dir, f"{object_name}.xml")
    if not os.path.exists(root_xml_path):
        die(f"Корневой файл обработки не найден: {root_xml_path}", 1)

    processor_dir = os.path.join(src_dir, object_name)
    forms_dir = os.path.join(processor_dir, "Forms")
    form_meta_path = os.path.join(forms_dir, f"{form_name}.xml")
    form_dir = os.path.join(forms_dir, form_name)

    # Containment: every path this run may touch has to resolve inside the object's
    # own directory, whatever the filesystem has done with links in between.
    require_inside(root_xml_path, src_dir, "корневого XML")
    require_inside(processor_dir, src_dir, "каталога объекта")
    require_inside(forms_dir, processor_dir, "каталога Forms")
    require_inside(form_meta_path, forms_dir, "метаданных формы")
    require_inside(form_dir, forms_dir, "каталога формы")
    for target, label in ((root_xml_path, "корневого XML"),
                          (processor_dir, "каталога объекта"),
                          (forms_dir, "каталога Forms"),
                          (form_meta_path, "метаданных формы"),
                          (form_dir, "каталога формы")):
        require_chain(src_dir, target, label)

    if not os.path.exists(form_meta_path):
        die(f"Метаданные формы не найдены: {form_meta_path}", 1)

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
            drop_element_keeping_indent(node)
            break
    if not form_node_found:
        die(f"Form is not registered in ChildObjects: {form_name}", 1)

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
        die("Removal requires explicit -Force. Run with -DryRun first to review the plan.", 2)

    # --- Mutation: one bounded transaction, rolled back as a whole on any failure ---

    form_dir_existed = os.path.isdir(form_dir)
    transaction = Transaction(os.path.join(os.path.abspath(src_dir), QUARANTINE_NAME))
    transaction.begin()
    try:
        transaction.backup_file(root_xml_full)
        if form_dir_existed:
            transaction.move_away(form_dir, "form-dir")
        transaction.move_away(form_meta_path, "form-meta.xml")
        transaction.replace_file(root_xml_full, payload)
    except BaseException as exc:  # noqa: BLE001 - every failure mode rolls back
        report = transaction.rollback()
        # The primary failure first and unmasked - it is what has to be acted on.
        print(f"[error] Операция прервана: {exc}", file=sys.stderr)
        if report.outstanding or report.problems:
            print("[error] Откат (rollback) выполнен не полностью.", file=sys.stderr)
            for problem in report.problems:
                print(f"  - не удалось: {problem}", file=sys.stderr)
            if report.outstanding:
                print(f"[error] Карантин {transaction.quarantine} НЕ удалён: в нём "
                      f"единственные копии перечисленного ниже. Восстановите вручную:",
                      file=sys.stderr)
                for parked, original in report.outstanding:
                    print(f"  - {parked} -> {original}", file=sys.stderr)
        elif report.quarantine_kept:
            print("[error] Откат (rollback) выполнен, дерево исходников не изменено, но "
                  f"каталог карантина остался — удалите вручную: {transaction.quarantine}",
                  file=sys.stderr)
        else:
            print("[error] Откат (rollback) выполнен, дерево исходников не изменено.", file=sys.stderr)
        sys.exit(1)

    try:
        transaction.commit()
    except BaseException as exc:  # noqa: BLE001 - the tree is already correct here
        print(f"[error] Форма удалена, но каталог карантина не удалён ({exc}). "
              f"Удалите вручную: {transaction.quarantine}", file=sys.stderr)
        sys.exit(1)

    if form_dir_existed:
        print(f"[OK] Removed directory: {form_dir}")
    print(f"[OK] Removed file: {form_meta_path}")
    print(f"[OK] Form {form_name} removed from {root_xml_path}")


if __name__ == "__main__":
    main()
