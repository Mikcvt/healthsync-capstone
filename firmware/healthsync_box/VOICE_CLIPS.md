# Voice clips for the box (DFPlayer Mini)

> Nov 1, 2026. Proposal: the box has no speaker yet, and `voice.cpp` is not
> written. The firmware change needs Christian's agreement.
>
> **Minimal on purpose (Miko):** the voice guides the patient to the lit
> compartments and confirms pairing. Every other signal keeps its tone from
> `config.h`.

## The clips: 13 per language

The box joins short parts into one sentence, so a few clips cover every
combination of lit compartments.

### Dose

| ✔ | File | English | Filipino | Used for |
|---|---|---|---|---|
| ☐ | 001 | Take your medicine. | Inumin na po ang gamot. | Start of the announcement |
| ☐ | 002 | Compartment | Compartment | Before the numbers |
| ☐ | 003 | and | at | Before the last number, when 2 or more are lit |
| ☐ | 011 | one | isa | Compartment number |
| ☐ | 012 | two | dalawa | 〃 |
| ☐ | 013 | three | tatlo | 〃 |
| ☐ | 014 | four | apat | 〃 |
| ☐ | 015 | five | lima | 〃 |
| ☐ | 016 | six | anim | 〃 |
| ☐ | 051 | Confirmed. | Nakumpirma po. | A press confirms the dose. Replaces the 1.5 s "taken" tone |

Number clip = 010 + compartment, so the firmware computes it.

### Pairing

| ✔ | File | English | Filipino | Plays when | Replaces |
|---|---|---|---|---|---|
| ☐ | 061 | Pairing mode. | Pairing mode na po. | The 5 s hold opens pairing mode | 2 s tone |
| ☐ | 062 | Phone connected. | Nakakonekta na po ang telepono. | A new phone paired, or a paired phone connected during pairing mode | 3 s / 0.5 s tones |
| ☐ | 063 | Pairing cancelled. | Kinansela po ang pairing. | A short press while the pairing lights run | 0.8 s tone |

## How the sentence is built

When a dose becomes due, the box lists **every lit compartment, lowest
first**, with "and" before the last one:

| Lit | Clips played | Heard |
|---|---|---|
| 3 | 001 · 002 · 013 | "Take your medicine. Compartment three." |
| 1, 5 | 001 · 002 · 011 · 003 · 015 | "Take your medicine. Compartment one and five." |
| 1, 2, 3 | 001 · 002 · 011 · 012 · 003 · 013 | "Take your medicine. Compartment one, two and three." |
| 1–6 | 001 · 002 · 011 · 012 · 013 · 014 · 015 · 003 · 016 | "… Compartment one, two, three, four, five and six." |

Firmware rule: `001, 002`, then each lit number in order, with `003` inserted
before the last number when more than one is lit.

**After a press:**
- Today's firmware (one press confirms all lit): `051` only.
- With the planned one-press-per-compartment change (A1 in
  `PANEL_SCENARIOS.md`): `051`, then the compartments still lit, using the
  same rule without `001`, e.g. "Confirmed. Compartment two and three."

The 5 s / 2 s alarm tone, the 30-min silence and everything else work exactly
as now; the voice plays at the start of the alarm and after a press.

## What stays a tone (no clip)

Nothing due (0.8 s), power on (1 s), too-short press, clock problems.

## SD card (the DFPlayer's own card, not the dose-log card)

```
/01/   English    001.mp3 002.mp3 003.mp3  011.mp3 … 016.mp3  051.mp3  061.mp3 062.mp3 063.mp3
/02/   Filipino   (same file names)
```

- Name the files exactly as above, with nothing after the number.
- FAT32. Copy the files in number order: some cheap DFPlayer clones play by
  copy order instead of by name.

## How to record

1. One voice for all clips, slow and clear. Quiet room, phone 20–30 cm away.
2. **Say the parts so they join well:**
   - "Compartment" and "and": flat, as if the sentence goes on.
   - The numbers: each as if it ends the sentence ("…and **three**."), so the
     last one sounds finished.
   - Record a full sentence first ("Take your medicine. Compartment one, two
     and three.") and copy its rhythm for the single clips.
3. Audacity: cut **all** silence before and after the part clips (002, 003,
   011–016), so the joins sound like one sentence. Add **0.2 s of silence at
   the start of 001, 051 and 061–063 only** (the DFPlayer swallows the first
   fraction of a second of a clip that starts from quiet). Normalize every
   clip to **−1 dB**.
4. Export MP3, mono, 44.1 kHz, 128 kbps.
5. Test: put the card in the DFPlayer and play 001 002 011 012 003 013 in a
   row. If the gaps sound too long, trim more silence; the DFPlayer itself
   adds about 0.1–0.3 s between clips.

## Not decided yet (for Christian)

- How the box picks the language: a setting in `config.h` for now.
- Playing a sequence: wait for the DFPlayer's BUSY pin (or its "finished"
  reply) before sending the next clip.
