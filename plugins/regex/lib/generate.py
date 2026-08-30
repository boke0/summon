#!/usr/bin/env python3
"""Build random strings from a regular expression (stdlib only)."""

import random
import re
import string

try:
    import re._parser as sre_parse
    import re._constants as sre_constants
except ImportError:
    import sre_parse
    import sre_constants

MAXREPEAT = int(getattr(sre_constants, "MAXREPEAT", 4294967295))
REPEAT_SPAN = 8
REPEAT_HARD_MAX = 1024
DEFAULT_COUNT = 8
MAX_ATTEMPTS_PER_STRING = 80
MAX_TOTAL_ATTEMPTS = 800

ASCII_PRINTABLE = [chr(i) for i in range(32, 127)]
DIGITS = string.digits
WORD = string.ascii_letters + string.digits + "_"
SPACE_CHARS = " \t"

EXAMPLES = (
    ("[a-z]{8}", "8 lowercase letters"),
    (r"\d{4}-\d{4}", "4 digits, hyphen, 4 digits"),
    ("[A-F0-9]{8}", "8 hex characters"),
    (r"[A-Za-z0-9]{12}", "12 alphanumeric characters"),
)

_LITERAL_OPS = frozenset(
    ("literal", "literal_ignore", "literal_uni_ignore", "literal_loc_ignore")
)
_IN_OPS = frozenset(("in", "in_ignore", "in_uni_ignore", "in_loc_ignore"))
_NOT_LITERAL_OPS = frozenset(
    (
        "not_literal",
        "not_literal_ignore",
        "not_literal_uni_ignore",
        "not_literal_loc_ignore",
    )
)
_REPEAT_OPS = frozenset(("max_repeat", "min_repeat", "possessive_repeat"))


def _op_name(op):
    name = getattr(op, "name", None)
    if isinstance(name, str):
        return name.lower()
    return str(op).lower()


def _case_variants(ch, flags):
    if not (flags & re.IGNORECASE):
        return [ch]
    lower = ch.lower()
    upper = ch.upper()
    if lower == upper:
        return [ch]
    if lower == ch:
        return [ch, upper]
    if upper == ch:
        return [ch, lower]
    return [ch, lower, upper]


def _maybe_swap_case(ch, flags, rng):
    variants = _case_variants(ch, flags)
    if len(variants) == 1:
        return variants[0]
    return rng.choice(variants)


def _chr_in_range(rng, lo, hi):
    if hi < lo:
        lo, hi = hi, lo
    lo = max(0, lo)
    hi = min(hi, 0x10FFFF)
    for _ in range(40):
        code = rng.randint(lo, hi)
        if 0xD800 <= code <= 0xDFFF:
            continue
        try:
            return chr(code)
        except ValueError:
            continue
    return "x"


def _category_chars(category):
    name = _op_name(category)
    if name.startswith("category_"):
        name = name[9:]
    mapping = {
        "digit": DIGITS,
        "uni_digit": DIGITS,
        "loc_digit": DIGITS,
        "not_digit": [c for c in ASCII_PRINTABLE if c not in DIGITS],
        "uni_not_digit": [c for c in ASCII_PRINTABLE if c not in DIGITS],
        "loc_not_digit": [c for c in ASCII_PRINTABLE if c not in DIGITS],
        "word": WORD,
        "uni_word": WORD,
        "loc_word": WORD,
        "not_word": [c for c in ASCII_PRINTABLE if not (c.isalnum() or c == "_")],
        "uni_not_word": [c for c in ASCII_PRINTABLE if not (c.isalnum() or c == "_")],
        "loc_not_word": [c for c in ASCII_PRINTABLE if not (c.isalnum() or c == "_")],
        "space": SPACE_CHARS,
        "uni_space": SPACE_CHARS,
        "loc_space": SPACE_CHARS,
        "not_space": [c for c in ASCII_PRINTABLE if c not in string.whitespace],
        "uni_not_space": [c for c in ASCII_PRINTABLE if c not in string.whitespace],
        "loc_not_space": [c for c in ASCII_PRINTABLE if c not in string.whitespace],
        "linebreak": "\n",
        "not_linebreak": [c for c in ASCII_PRINTABLE if c != "\n"],
    }
    chars = mapping.get(name)
    if chars is None:
        return ASCII_PRINTABLE
    return list(chars)


def _in_category(ch, category):
    name = _op_name(category)
    if name.startswith("category_"):
        name = name[9:]
    if name in ("digit", "uni_digit", "loc_digit"):
        return ch in DIGITS
    if name in ("not_digit", "uni_not_digit", "loc_not_digit"):
        return ch not in DIGITS
    if name in ("word", "uni_word", "loc_word"):
        return ch.isalnum() or ch == "_"
    if name in ("not_word", "uni_not_word", "loc_not_word"):
        return not (ch.isalnum() or ch == "_")
    if name in ("space", "uni_space", "loc_space"):
        return ch in string.whitespace
    if name in ("not_space", "uni_not_space", "loc_not_space"):
        return ch not in string.whitespace
    if name == "linebreak":
        return ch == "\n"
    if name == "not_linebreak":
        return ch != "\n"
    return False


def _char_matches_specs(ch, specs, flags):
    for opcode, value in specs:
        name = _op_name(opcode)
        if name in _LITERAL_OPS:
            if any(v == ch for v in _case_variants(chr(value), flags)):
                return True
        elif name == "range" or name == "range_uni_ignore":
            lo, hi = value
            for variant in _case_variants(ch, flags):
                code = ord(variant)
                if lo <= code <= hi:
                    return True
        elif name == "category":
            if _in_category(ch, value):
                return True
    return False


def _repeat_bounds(min_count, max_count):
    min_count = max(0, int(min_count))
    unbounded = max_count is None or int(max_count) >= MAXREPEAT
    if unbounded:
        max_count = min_count + REPEAT_SPAN
    else:
        max_count = int(max_count)
    min_count = min(min_count, REPEAT_HARD_MAX)
    max_count = min(max_count, REPEAT_HARD_MAX)
    if max_count < min_count:
        max_count = min_count
    return min_count, max_count


class _Emitter(object):
    def __init__(self, rng, flags):
        self.rng = rng
        self.flags = flags
        self.groups = {}

    def emit(self, seq):
        parts = []
        for opcode, value in seq:
            parts.append(self._handle(opcode, value))
        return "".join(parts)

    def _handle(self, opcode, value):
        name = _op_name(opcode)
        if name in _LITERAL_OPS:
            return _maybe_swap_case(chr(value), self.flags, self.rng)
        if name in _NOT_LITERAL_OPS:
            return self._not_literal(value)
        if name in _IN_OPS:
            return self._sample_in(value)
        if name == "any":
            return self._any()
        if name == "at":
            return ""
        if name in _REPEAT_OPS:
            return self._repeat(value)
        if name == "branch":
            return self._branch(value)
        if name == "subpattern":
            return self._subpattern(value)
        if name in (
            "groupref",
            "groupref_ignore",
            "groupref_uni_ignore",
            "groupref_loc_ignore",
        ):
            return self.groups.get(value, "")
        if name == "groupref_exists":
            return self._groupref_exists(value)
        if name in ("assert", "assert_not"):
            return ""
        if name == "atomic_group":
            return self.emit(value)
        if name == "category":
            chars = _category_chars(value)
            return self.rng.choice(chars)
        return ""

    def _any(self):
        alphabet = list(ASCII_PRINTABLE)
        if self.flags & re.DOTALL:
            alphabet.append("\n")
        return self.rng.choice(alphabet)

    def _not_literal(self, value):
        banned = set(_case_variants(chr(value), self.flags))
        choices = [c for c in ASCII_PRINTABLE if c not in banned]
        if not choices:
            return "x"
        return self.rng.choice(choices)

    def _sample_in(self, items):
        specs = list(items)
        negated = False
        if specs and _op_name(specs[0][0]) == "negate":
            negated = True
            specs = specs[1:]
        if negated:
            return self._sample_negated(specs)
        return self._sample_positive(specs)

    def _sample_positive(self, specs):
        choices = []
        for opcode, value in specs:
            name = _op_name(opcode)
            if name in _LITERAL_OPS:
                chars = _case_variants(chr(value), self.flags)
                choices.append((len(chars), "set", chars))
            elif name == "range" or name == "range_uni_ignore":
                lo, hi = value
                size = max(1, min(hi - lo + 1, 10000))
                choices.append((size, "range", (lo, hi)))
            elif name == "category":
                chars = _category_chars(value)
                choices.append((max(1, len(chars)), "set", chars))
        if not choices:
            return self.rng.choice(ASCII_PRINTABLE)
        total = sum(weight for weight, _, _ in choices)
        pick = self.rng.randint(1, total)
        acc = 0
        for weight, kind, data in choices:
            acc += weight
            if pick <= acc:
                if kind == "set":
                    return self.rng.choice(data)
                lo, hi = data
                return _maybe_swap_case(_chr_in_range(self.rng, lo, hi), self.flags, self.rng)
        return self.rng.choice(ASCII_PRINTABLE)

    def _sample_negated(self, specs):
        choices = [
            c for c in ASCII_PRINTABLE if not _char_matches_specs(c, specs, self.flags)
        ]
        if not choices:
            choices = [
                chr(i)
                for i in range(160, 256)
                if not _char_matches_specs(chr(i), specs, self.flags)
            ]
        if not choices:
            for _ in range(40):
                ch = _chr_in_range(self.rng, 0, 0xFFFF)
                if not _char_matches_specs(ch, specs, self.flags):
                    return ch
            return "x"
        return self.rng.choice(choices)

    def _repeat(self, value):
        min_count, max_count, sub = value
        low, high = _repeat_bounds(min_count, max_count)
        n = self.rng.randint(low, high)
        return "".join(self.emit(sub) for _ in range(n))

    def _branch(self, value):
        branches = value[1]
        if not branches:
            return ""
        return self.emit(self.rng.choice(branches))

    def _subpattern(self, value):
        group = None
        add_flags = 0
        del_flags = 0
        sub = value
        if isinstance(value, tuple):
            if len(value) == 4:
                group, add_flags, del_flags, sub = value
            elif len(value) == 2:
                group, sub = value
        saved = self.flags
        self.flags = (self.flags | int(add_flags or 0)) & ~int(del_flags or 0)
        try:
            text = self.emit(sub)
        finally:
            self.flags = saved
        if group:
            self.groups[group] = text
        return text

    def _groupref_exists(self, value):
        cond = value[0]
        yes = value[1]
        no = value[2] if len(value) > 2 else None
        if self.groups.get(cond):
            return self.emit(yes) if yes is not None else ""
        return self.emit(no) if no is not None else ""


def generate_strings(pattern, count=DEFAULT_COUNT, rng=None):
    """Return up to `count` unique strings that fully match `pattern`.

    Raises re.error if the pattern is invalid.
    """
    if rng is None:
        rng = random.Random()
    compiled = re.compile(pattern)
    parsed = sre_parse.parse(pattern)
    unique = []
    seen = set()
    attempts = 0
    while len(unique) < count and attempts < MAX_TOTAL_ATTEMPTS:
        attempts += 1
        matched = None
        for _ in range(MAX_ATTEMPTS_PER_STRING):
            emitter = _Emitter(rng, compiled.flags)
            candidate = emitter.emit(parsed)
            if compiled.fullmatch(candidate) is not None:
                matched = candidate
                break
        if matched is None or matched in seen:
            continue
        seen.add(matched)
        unique.append(matched)
    return unique


def _text_item(item_id, text, subtitle):
    title = text if text else "(empty)"
    return {
        "id": item_id,
        "title": title,
        "subtitle": subtitle,
        "payload": {"kind": "text", "text": text},
    }


def _message_item(item_id, title, subtitle, kind):
    return {
        "id": item_id,
        "title": title,
        "subtitle": subtitle,
        "payload": {"kind": kind},
    }


def _example_items(rng):
    items = []
    index = 0
    for pattern, label in EXAMPLES:
        samples = generate_strings(pattern, count=2, rng=rng)
        subtitle = "%s · %s" % (pattern, label)
        for text in samples:
            items.append(_text_item("gen:%d" % index, text, subtitle))
            index += 1
    if not items:
        items.append(
            _message_item(
                "hint",
                "Enter a regular expression",
                "Example: [a-z]{8}",
                "hint",
            )
        )
    return items


def items_for_query(query, rng=None, count=DEFAULT_COUNT):
    if rng is None:
        rng = random.Random()
    if query == "":
        return _example_items(rng)
    try:
        strings = generate_strings(query, count=count, rng=rng)
    except re.error as exc:
        return [
            _message_item(
                "error",
                "Invalid regular expression",
                str(exc),
                "error",
            )
        ]
    if not strings:
        return [
            _message_item(
                "error",
                "Could not generate a matching string",
                "The pattern may be impossible to satisfy",
                "error",
            )
        ]
    return [
        _text_item("gen:%d" % index, text, "Copy to clipboard")
        for index, text in enumerate(strings)
    ]
