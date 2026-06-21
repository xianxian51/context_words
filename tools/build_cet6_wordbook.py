#!/usr/bin/env python3
"""Build the built-in CET-6 wordbook asset.

Sources:
- CET word list: JavaProgrammerLB/cet-word-list, MIT.
- Definitions: skywind3000/ECDICT, MIT.

The script keeps large downloaded source files in a temp cache, validates the
generated word count, and only overwrites assets/wordbooks/cet6.json after the
new wordbook passes basic quality checks.
"""

from __future__ import annotations

import csv
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.request import urlopen


REPO_ROOT = Path(__file__).resolve().parents[1]
ASSET_PATH = REPO_ROOT / "assets" / "wordbooks" / "cet6.json"
ECDICT_LICENSE_PATH = REPO_ROOT / "assets" / "wordbooks" / "ECDICT_LICENSE.txt"
CET_LICENSE_PATH = REPO_ROOT / "assets" / "wordbooks" / "CET_WORD_LIST_LICENSE.txt"

CACHE_DIR = Path(
    os.environ.get(
        "CONTEXT_WORDS_WORDBOOK_CACHE",
        str(Path(tempfile.gettempdir()) / "context_words_sources"),
    )
)

JAVA_WORD_LIST_URL = (
    "https://raw.githubusercontent.com/JavaProgrammerLB/cet-word-list/"
    "master/word-list.txt"
)
JAVA_LICENSE_URL = (
    "https://raw.githubusercontent.com/JavaProgrammerLB/cet-word-list/"
    "master/LICENSE"
)
ECDICT_CSV_URL = (
    "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
)
ECDICT_LICENSE_URL = (
    "https://raw.githubusercontent.com/skywind3000/ECDICT/master/LICENSE"
)

MIN_WORD_COUNT = 2500
ECDICT_CSV_SIZE = 65_933_428
WORD_RE = re.compile(r"^[a-z]+(?:[-'][a-z]+)*$")
WORD_TOKEN_RE = re.compile(r"[a-z]+(?:[-'][a-z]+)*(?:/[a-z-]+)?(?:\\([a-z]+\\))?")
POS_RE = re.compile(r"^(n|v|vt|vi|adj|adv|prep|conj|pron|num|int|art|aux|a)\.")


@dataclass(frozen=True)
class BuildStats:
    total_words: int
    unique_words: int
    meaning_cn_count: int
    phonetic_count: int
    part_of_speech_count: int
    meaning_en_count: int
    skipped_count: int


def main() -> int:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_PATH.parent.mkdir(parents=True, exist_ok=True)

    word_list_path = ensure_file("java_word-list.txt", JAVA_WORD_LIST_URL)
    java_license_path = ensure_file("java_LICENSE", JAVA_LICENSE_URL)
    ecdict_license_path = ensure_file("ecdict_LICENSE", ECDICT_LICENSE_URL)
    ecdict_path = ensure_ecdict_csv()

    java_words, java_skipped = load_cet_words(word_list_path)
    ecdict, skipped = load_ecdict_cet6(ecdict_path)
    words = sorted(ecdict)
    entries = build_entries(words, ecdict)
    stats = collect_stats(entries, skipped)

    if stats.unique_words < MIN_WORD_COUNT:
        print(
            f"ERROR: generated only {stats.unique_words} words; "
            f"minimum is {MIN_WORD_COUNT}. Existing cet6.json was not changed.",
            file=sys.stderr,
        )
        return 1

    tmp_path = ASSET_PATH.with_suffix(".json.tmp")
    tmp_path.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    tmp_path.replace(ASSET_PATH)
    shutil.copyfile(java_license_path, CET_LICENSE_PATH)
    shutil.copyfile(ecdict_license_path, ECDICT_LICENSE_PATH)

    print_stats(stats)
    print(f"java_reference_words={len(java_words)}")
    print(f"java_reference_skipped_fragments={java_skipped}")
    return 0


def ensure_file(name: str, url: str) -> Path:
    path = CACHE_DIR / name
    if path.exists() and path.stat().st_size > 0:
        return path
    print(f"Downloading {url}")
    with urlopen(url, timeout=60) as response:
        path.write_bytes(response.read())
    return path


def ensure_ecdict_csv() -> Path:
    path = CACHE_DIR / "ecdict.csv"
    if path.exists() and path.stat().st_size == ECDICT_CSV_SIZE:
        return path

    for cache_candidate in (
        Path(tempfile.gettempdir()) / "context_words_sources" / "ecdict.csv",
        Path("/tmp/context_words_sources/ecdict.csv"),
    ):
        if (
            cache_candidate.exists()
            and cache_candidate.stat().st_size == ECDICT_CSV_SIZE
        ):
            return cache_candidate

    print("Downloading ECDICT CSV with parallel byte ranges")
    parallel_range_download(ECDICT_CSV_URL, path, ECDICT_CSV_SIZE)
    return path


def parallel_range_download(url: str, destination: Path, size: int) -> None:
    parts_dir = destination.with_suffix(".parts")
    if parts_dir.exists():
        shutil.rmtree(parts_dir)
    parts_dir.mkdir(parents=True)

    chunk_size = 1024 * 1024
    ranges: list[tuple[int, int, int]] = []
    for index, start in enumerate(range(0, size, chunk_size)):
        ranges.append((index, start, min(start + chunk_size - 1, size - 1)))

    commands = [
        [
            "curl",
            "-sS",
            "-L",
            "--connect-timeout",
            "15",
            "--max-time",
            "180",
            "-r",
            f"{start}-{end}",
            "-o",
            str(parts_dir / f"part_{index:04d}"),
            url,
        ]
        for index, start, end in ranges
    ]

    processes: list[subprocess.Popen[bytes]] = []
    max_parallel = 16
    for command in commands:
        while len(processes) >= max_parallel:
            wait_one(processes)
        processes.append(subprocess.Popen(command))
    while processes:
        wait_one(processes)

    with destination.open("wb") as output:
        for index, _, _ in ranges:
            part = parts_dir / f"part_{index:04d}"
            output.write(part.read_bytes())

    if destination.stat().st_size != size:
        raise RuntimeError(
            f"ECDICT download size mismatch: {destination.stat().st_size} != {size}"
        )
    shutil.rmtree(parts_dir)


def wait_one(processes: list[subprocess.Popen[bytes]]) -> None:
    process = processes.pop(0)
    code = process.wait()
    if code != 0:
        for other in processes:
            other.terminate()
        raise RuntimeError(f"download command failed with exit code {code}")


def load_cet_words(path: Path) -> tuple[list[str], int]:
    words: set[str] = set()
    skipped = 0
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip().lower().replace("’", "'")
        if not line:
            continue
        extracted = extract_words_from_line(line)
        if not extracted:
            skipped += 1
        words.update(extracted)
    return sorted(words), skipped


def extract_words_from_line(line: str) -> set[str]:
    found: set[str] = set()
    for match in WORD_TOKEN_RE.finditer(line):
        token = match.group(0).strip("-'")
        for variant in expand_word_variant(token):
            if WORD_RE.fullmatch(variant):
                found.add(variant)
    return found


def expand_word_variant(token: str) -> set[str]:
    variants = {token}
    if "(" in token and ")" in token:
        variants.update(expand_parenthetical_variant(token))
    expanded: set[str] = set()
    for value in variants:
        if "/" not in value:
            expanded.add(value)
            continue
        base, alternate = value.split("/", 1)
        expanded.add(base)
        if alternate.startswith("-"):
            suffix = alternate[1:]
            if suffix and len(base) > len(suffix):
                expanded.add(base[: -len(suffix)] + suffix)
        elif alternate:
            expanded.add(alternate)
    return {
        value.strip("-'")
        for value in expanded
        if value and len(value.strip("-'")) > 1
    }


def expand_parenthetical_variant(token: str) -> set[str]:
    match = re.fullmatch(r"([a-z'-]*)\\(([a-z]+)\\)([a-z'-]*)", token)
    if not match:
        return {token}
    before, optional, after = match.groups()
    return {before + after, before + optional + after}


def load_ecdict_cet6(path: Path) -> tuple[dict[str, dict[str, str]], int]:
    matched: dict[str, dict[str, str]] = {}
    skipped = 0
    with path.open(encoding="utf-8", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            tags = set((row.get("tag") or "").split())
            if "cet6" not in tags:
                continue
            word = (row.get("word") or "").strip().lower()
            if not WORD_RE.fullmatch(word):
                skipped += 1
                continue
            matched.setdefault(word, row)
    return matched, skipped


def build_entries(
    words: list[str], ecdict: dict[str, dict[str, str]]
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for word in words:
        row = ecdict.get(word, {})
        entries.append(
            {
                "word": word,
                "phonetic": format_phonetic(row.get("phonetic", "")),
                "part_of_speech": extract_part_of_speech(row),
                "meaning_cn": clean_text(row.get("translation", "")),
                "meaning_en": clean_text(row.get("definition", "")),
                "example_sentence": "",
                "phrase": [],
                "synonyms": [],
                "difficulty": "cet6",
                "source": "cet6_builtin",
            }
        )
    return entries


def format_phonetic(value: str) -> str:
    text = clean_text(value)
    if not text:
        return ""
    if text.startswith("/") and text.endswith("/"):
        return text
    return f"/{text}/"


def extract_part_of_speech(row: dict[str, str]) -> str:
    value = clean_text(row.get("pos", ""))
    if value:
        return value
    translation = row.get("translation", "")
    found: list[str] = []
    for line in translation.splitlines():
        match = POS_RE.match(line.strip())
        if not match:
            continue
        pos = match.group(1)
        if pos == "a":
            pos = "adj"
        if pos not in found:
            found.append(pos)
    return ", ".join(f"{pos}." for pos in found)


def clean_text(value: str | None) -> str:
    if not value:
        return ""
    normalized = (
        value.replace("\\r\\n", "; ")
        .replace("\\n", "; ")
        .replace("\r", "\n")
        .replace("\n", "; ")
    )
    return re.sub(r"\s+", " ", normalized).strip()


def collect_stats(entries: list[dict[str, object]], skipped: int) -> BuildStats:
    words = [str(entry["word"]) for entry in entries]
    return BuildStats(
        total_words=len(entries),
        unique_words=len(set(words)),
        meaning_cn_count=count_non_empty(entries, "meaning_cn"),
        phonetic_count=count_non_empty(entries, "phonetic"),
        part_of_speech_count=count_non_empty(entries, "part_of_speech"),
        meaning_en_count=count_non_empty(entries, "meaning_en"),
        skipped_count=skipped,
    )


def count_non_empty(entries: list[dict[str, object]], key: str) -> int:
    return sum(1 for entry in entries if str(entry.get(key, "")).strip())


def print_stats(stats: BuildStats) -> None:
    print("CET-6 wordbook generated")
    print(f"total_words={stats.total_words}")
    print(f"unique_words={stats.unique_words}")
    print(f"meaning_cn_count={stats.meaning_cn_count}")
    print(f"phonetic_count={stats.phonetic_count}")
    print(f"part_of_speech_count={stats.part_of_speech_count}")
    print(f"meaning_en_count={stats.meaning_en_count}")
    print(f"skipped_count={stats.skipped_count}")
    print("cet_source=skywind3000/ECDICT tag=cet6 (MIT)")
    print("definition_source=skywind3000/ECDICT (MIT)")
    print("java_backup_checked=JavaProgrammerLB/cet-word-list (MIT)")
    print("kylebing_checked=KyleBing/english-vocabulary has CET-6 5651 words, license not explicit; not used")
    print(f"output={ASSET_PATH}")


if __name__ == "__main__":
    raise SystemExit(main())
