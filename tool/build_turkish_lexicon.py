# -*- coding: utf-8 -*-
"""Zemberek-NLP (Apache 2.0) sözlüklerinden Tahrir için gömülü Türkçe sözlük Dart dosyası üretir."""
import re
import sys
import urllib.request

BASE = "https://raw.githubusercontent.com/ahmetaa/zemberek-nlp/master/morphology/src/main/resources/tr/"
FILES = ["master-dictionary.dict", "non-tdk.dict", "proper.dict", "person-names.dict"]
OUT = sys.argv[1]

VOWELS = "aeıioöuüâîû"
LETTERS = re.compile(r"^[a-zçğıöşüâîû]+$")


def tr_lower(s: str) -> str:
    return s.replace("I", "ı").replace("İ", "i").lower()


def strip_circ(s: str) -> str:
    return s.replace("â", "a").replace("î", "i").replace("û", "u")


def syllables(w: str) -> int:
    return sum(1 for c in w if c in VOWELS)


VOICE = {"p": "b", "ç": "c", "t": "d", "k": "ğ"}

nouns, verbs, bound, inverse = set(), set(), set(), set()

for f in FILES:
    raw = urllib.request.urlopen(BASE + f, timeout=30).read().decode("utf-8")
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        word = line.split("[", 1)[0].strip()
        attrs = line[len(word):]
        w = tr_lower(word)
        if " " in w or not LETTERS.match(w):
            continue
        a = attrs.replace(" ", "")
        is_verb = "P:Verb" in a or ("P:" not in a and len(w) > 4 and (w.endswith("mak") or w.endswith("mek")))
        flags = set()
        m = re.search(r"A:([^;\]]+)", a)
        if m:
            flags = set(m.group(1).split(","))
        if w == "değil":
            is_verb = False
        if is_verb:
            root = w[:-3]
            if len(root) < 1:
                continue
            verbs.add(strip_circ(root))
            if "Voicing" in flags and root[-1] in VOICE:
                v = VOICE[root[-1]]
                if root.endswith("nk"):
                    v = "g"
                bound.add("VV:" + strip_circ(root[:-1] + v))
            continue
        base = strip_circ(w)
        nouns.add(base)
        if "InverseHarmony" in flags:
            inverse.add(base)
        stem = base
        if "LastVowelDrop" in flags:
            idx = max(stem.rfind(c) for c in "aeıioöuü")
            if idx > 0:
                stem = stem[:idx] + stem[idx + 1:]
                bound.add("N:" + stem)
                if "InverseHarmony" in flags:
                    inverse.add(stem)
        if "Doubling" in flags:
            bound.add("N:" + stem + stem[-1])
        last = stem[-1]
        if last in VOICE and "NoVoicing" not in flags:
            if "Voicing" in flags or syllables(base) >= 2:
                v = "g" if stem.endswith("nk") else VOICE[last]
                bound.add("NV:" + stem[:-1] + v)
                if "InverseHarmony" in flags:
                    inverse.add(stem[:-1] + v)

# Düzensiz zamir ve sık kalıplar
nouns.update({"bana", "sana", "onlar", "bunlar", "şunlar", "kendi", "diye", "değil", "diyor", "yiyor", "diyen", "diyerek", "diyecek", "yiyecek", "diyip"})
bound.update({"N:on", "N:bun", "N:şun"})


def chunk(items, per_line=24):
    # Tek bir çok satırlı ham string: analizör/derleyici için sabit birleştirme maliyeti yok.
    items = sorted(items)
    lines = []
    for i in range(0, len(items), per_line):
        lines.append(" ".join(items[i:i + per_line]))
    return "    r'''\n" + "\n".join(lines) + "\n'''"


with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write("// GENERATED FILE — DO NOT EDIT BY HAND.\n")
    fh.write("// Kaynak: Zemberek-NLP sözlükleri (https://github.com/ahmetaa/zemberek-nlp)\n")
    fh.write("// Lisans: Apache License 2.0 — Copyright 2018 Ahmet A. Akın, Mehmet D. Akın\n")
    fh.write("// Üretici: build_turkish_lexicon.py (master, non-tdk, proper, person-names)\n\n")
    fh.write("// ignore_for_file: lines_longer_than_80_chars\n\n")
    fh.write("/// Çevrimdışı Türkçe sözlük verisi (isim/sıfat lemmaları, fiil kökleri, ses olayı gövdeleri).\n")
    fh.write("abstract final class TurkishLexiconData {\n")
    fh.write("  /// İsim, sıfat, zarf, zamir ve özel isim lemmaları (şapkasız, küçük harf).\n")
    fh.write("  static const String nominalLemmas =\n" + chunk(nouns) + ";\n\n")
    fh.write("  /// Fiil kökleri (-mak/-mek atılmış).\n")
    fh.write("  static const String verbRoots =\n" + chunk(verbs) + ";\n\n")
    fh.write("  /// Yalnızca ünlüyle başlayan ek önünde geçerli gövdeler (N: isim, V: fiil).\n")
    fh.write("  static const String boundStems =\n" + chunk(bound) + ";\n\n")
    fh.write("  /// Ters ünlü uyumlu (ince ek alan) kalın ünlülü isimler.\n")
    fh.write("  static const String inverseHarmony =\n" + chunk(inverse) + ";\n")
    fh.write("}\n")

print(f"nouns={len(nouns)} verbs={len(verbs)} bound={len(bound)} inverse={len(inverse)}")
