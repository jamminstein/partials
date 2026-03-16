# partials

Three voices walk the natural harmonic series. Each clock drifts imperceptibly faster than the last — over minutes they breathe apart, create acoustic beating, briefly align in unison, then drift again.

Steve Reich's phasing meets the overtone series. Timeless because these pitches are physics.

A [monome norns](https://monome.org/docs/norns/) script with custom SuperCollider engine.

---

## controls

| control | action |
|---------|--------|
| ENC1 | root frequency (A1–A3, semitone steps) |
| ENC2 | drift rate (0 = lockstep, max = chaotic) |
| ENC3 | step rate (32nd note → whole note) |
| KEY2 | play / pause |
| KEY3 | randomize harmonic weights |

## the harmonic series used

Partials 4–16 above the root, in just intonation:

```
4/4  root          8/4  octave         12/4  fifth + 8va
5/4  major third   9/4  major second   13/4  13th partial *
6/4  fifth         10/4 maj 3rd + 8va  14/4  flat 7th
7/4  blues 7th *   11/4 11th partial * 15/4  major 7th
                                       16/4  2nd octave
```

`*` marks the partials that don't exist in 12-TET — the ones that hurt in the best way.

## requirements

- norns
- no grid required (grid optional for future expansion)
