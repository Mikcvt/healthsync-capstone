# Voice clips for the box (DFPlayer Mini)

> Nov 1, 2026: proposal. Nov 3, 2026: built in firmware 0.4.3 (`voice.cpp`),
> at Miko's request; Christian has not reviewed it yet.
>
> **Tone first, then voice (Miko):** every spoken prompt follows its tone,
> and the beep is never removed. The voice guides the patient to the lit
> compartments, confirms a dose and pairing, and greets at start-up. Every
> other signal keeps its tone from `config.h`. Without a DFPlayer (or with a
> dead one) the box works on tones alone.

## The clips: 14 per language

The box joins short parts into one sentence, so a few clips cover every
combination of lit compartments.

### Dose

| ✔ | File | English | Filipino | Used for |
|---|---|---|---|---|
| ☐ | 001 | Please take your medicine. | Inumin na po ang gamot. | Start of the announcement |
| ☐ | 002 | Compartment | Compartment | Before the numbers |
| ☐ | 003 | and | at | Before the last number, when 2 or more are lit |
| ☐ | 011 | one | isa | Compartment number |
| ☐ | 012 | two | dalawa | 〃 |
| ☐ | 013 | three | tatlo | 〃 |
| ☐ | 014 | four | apat | 〃 |
| ☐ | 015 | five | lima | 〃 |
| ☐ | 016 | six | anim | 〃 |
| ☐ | 051 | Dose confirmed. | Nakumpirma po. | A press confirms the dose: after the 1.5 s "taken" tone |

Number clip = 010 + compartment, so the firmware computes it.

### Pairing and start-up

| ✔ | File | English | Filipino | Plays when | After the tone |
|---|---|---|---|---|---|
| ☐ | 061 | Pairing mode. | Pairing mode na po. | The 5 s hold opens pairing mode | 2 s |
| ☐ | 062 | Phone connected. | Nakakonekta na po ang telepono. | A new phone paired, or a paired phone connected during pairing mode | 3 s / 0.5 s |
| ☐ | 063 | Pairing cancelled. | Kinansela po ang pairing. | A short press while the pairing lights run | 0.8 s |
| ☐ | 071 | HealthSync med box is ready. Please pair or sync your phone. | (not written yet) | Once per power-on (not after an automatic restart), unless a dose is already due | 1 s power-on |

## How the sentence is built

When a dose becomes due, the box lists **every lit compartment, lowest
first**, with "and" before the last one:

| Lit | Clips played | Heard |
|---|---|---|
| 3 | 001 · 002 · 013 | "Please take your medicine. Compartment three." |
| 1, 5 | 001 · 002 · 011 · 003 · 015 | "Please take your medicine. Compartment one and five." |
| 1, 2, 3 | 001 · 002 · 011 · 012 · 003 · 013 | "Please take your medicine. Compartment one, two and three." |
| 1–6 | 001 · 002 · 011 · 012 · 013 · 014 · 015 · 003 · 016 | "… Compartment one, two, three, four, five and six." |

Firmware rule: `001, 002`, then each lit number in order, with `003` inserted
before the last number when more than one is lit.

## The alarm: tone, voice, pause (Nov 3, Miko)

```
BEEP 5 s  →  "Please take your medicine. Compartment one."  →  silence 5 s  →  repeat
```

| Since the dose came due | Each round |
|---|---|
| 0–5 min | Tone 5 s → prompt → 5 s silence. Prompt **every round** |
| 5–30 min | Same, prompt **every 3rd round**; the others are tone 5 s → 5 s silence |
| 30–60 min | Silent; the LED stays lit |
| +60 min | Missed; LED off |

A round takes about 14 s with the prompt (one compartment) and 10 s without.
The tone and the voice never play together. A newly lit compartment restarts
the alarm, so its first 5 minutes speak every round again.

**After a press:** everything stops, then the 1.5 s tone and `051`.
With the planned one-press-per-compartment change (A1 in
`PANEL_SCENARIOS.md`): `051`, then the compartments still lit, using the same
rule without `001`, e.g. "Dose confirmed. Compartment two and three."

## What stays a tone (no clip)

Nothing due (0.8 s), too-short press, clock problems.

## SD card (the DFPlayer's own card, not the dose-log card)

```
/01/   English    001.mp3 002.mp3 003.mp3  011.mp3 … 016.mp3  051.mp3  061.mp3 062.mp3 063.mp3  071.mp3
/02/   Filipino   (same file names; not used yet)
```

- Name the files exactly as above, with nothing after the number.
- FAT32. Copy the files in number order: some cheap DFPlayer clones play by
  copy order instead of by name.
- A missing clip is skipped after 1 s; the tones still play.

## How to record

1. One voice for all clips, slow and clear. Quiet room, phone 20–30 cm away.
2. **Say the parts so they join well:**
   - "Compartment" and "and": flat, as if the sentence goes on.
   - The numbers: each as if it ends the sentence ("…and **three**."), so the
     last one sounds finished.
   - Record a full sentence first ("Please take your medicine. Compartment one, two
     and three.") and copy its rhythm for the single clips.
3. Audacity: cut **all** silence before and after the part clips (002, 003,
   011–016), so the joins sound like one sentence. Add **0.2 s of silence at
   the start of 001, 051, 061–063 and 071 only** (the DFPlayer swallows the
   first fraction of a second of a clip that starts from quiet). Normalize
   every clip to **−1 dB**.
4. Export MP3, mono, 44.1 kHz, 128 kbps.
5. Test: put the card in the DFPlayer and play 001 002 011 012 003 013 in a
   row. If the gaps sound too long, trim more silence; the DFPlayer itself
   adds about 0.1–0.3 s between clips.
6. AI voices: check how "HealthSync" and "med box" come out in 071; writing
   "Health Sync med box" in the voice tool can help.

## Still open

- Filipino: the language is the `VOICE_FOLDER` setting in `config.h` (1 =
  English); no Filipino clips yet, and no wording for 071.
- Christian to review `voice.cpp` and the alarm rounds in `buzzer.cpp`.

## Bench test, Nov 2, 2026 (`dfplayer_test/`)

- All clips play from `/01/`, BUSY works (HIGH idle, LOW while playing).
- **Volume 30 of 30**, chosen by ear. No brownout on laptop USB.
- **Do not send the DFPlayer reset command at start-up.** It made the ESP32
  brown out in a loop on 5 V. The player is already running from power-on:
  wait about 1.5 s, then `begin(serial, ..., false)`. The firmware also turns
  the player's acknowledgements off, so no command waits for a reply.
- The player does not report a file count (clone); it is not needed.
- Pin 1 (VCC) is the **top of the right row** with the chips facing you and
  the card sticking out at the bottom. The wiring page had this backwards.
- **One 8 Ω speaker.** Two 8 Ω speakers in parallel (4 Ω) sounded no louder,
  browned out at volume 30 on laptop USB and needed 25. Use one.

## Bench test, Nov 3, 2026 (firmware 0.4.3)

- **On laptop USB, volume 30 browned out** once Bluetooth was running (the
  test sketch had no Bluetooth). The firmware now starts with the voice off
  after a brownout reset, so it can never loop.
- **On the 18650 + 134N3P, volume 30 works** with Bluetooth on: start-up
  prompt and voices all fine (Miko). The finished box runs this way.
- Bench work on laptop USB: expect a brownout when the voice plays; the box
  then carries on with tones only.
