// Engine_Partials
// three additive sine voices with gentle FM shimmer
// plus a just-intoned root drone
// for monome norns — @jamminstein

Engine_Partials : CroneEngine {

  var <voices;
  var <drone;
  var <rootHz;
  var <shimmerAmt;
  var <ampLevel;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    rootHz     = 55.0;
    shimmerAmt = 0.002;
    ampLevel   = 0.28;

    // --- melodic voices ---
    // each voice: a sine with a very slow FM modulator
    // the modulator freq is irrational relative to the carrier
    // so the shimmer never repeats
    SynthDef(\partial_voice, {
      arg out = 0,
          freq = 220,
          amp  = 0.28,
          gate = 1,
          shimmer = 0.002,
          atk  = 0.06,
          rel  = 0.4;

      var sig, env, mod_freq, fm;

      // FM shimmer: modulator at ~sqrt(2) * freq so it's inharmonic
      mod_freq = freq * 1.4142;
      fm       = SinOsc.ar(mod_freq) * (freq * shimmer);

      sig = SinOsc.ar(freq + fm);

      env = EnvGen.kr(
        Env.asr(atk, 1.0, rel),
        gate,
        doneAction: Done.freeSelf
      );

      sig = sig * env * amp * 0.33;  // /3 since three voices sum
      Out.ar(out, sig ! 2);
    }).add;

    // --- root drone ---
    // fundamental + octave + fifth, at very low amplitude
    // gives the harmonic scaffold a physical center of gravity
    SynthDef(\partial_drone, {
      arg out  = 0,
          freq = 55,
          amp  = 0.08;

      var sig, f2, f3;

      f2 = freq * 2;   // octave
      f3 = freq * 3;   // fifth above octave (3rd harmonic)

      sig =   SinOsc.ar(freq) * 0.6
            + SinOsc.ar(f2)   * 0.25
            + SinOsc.ar(f3)   * 0.10;

      sig = sig * amp;
      Out.ar(out, sig ! 2);
    }).add;

    // start drone immediately
    drone = Synth(\partial_drone, [
      \out,  context.out_b.index,
      \freq, rootHz,
      \amp,  0.08
    ], context.xg);

    // voice slots — start silent, Lua will drive them
    voices = Array.fill(3, { |i|
      Synth(\partial_voice, [
        \out,     context.out_b.index,
        \freq,    rootHz * (i + 1),
        \amp,     ampLevel,
        \shimmer, shimmerAmt,
        \gate,    1
      ], context.xg);
    });

    // --- commands ---

    this.addCommand("v1_hz", "f", { arg msg;
      voices[0].set(\freq, msg[1]);
    });

    this.addCommand("v2_hz", "f", { arg msg;
      voices[1].set(\freq, msg[1]);
    });

    this.addCommand("v3_hz", "f", { arg msg;
      voices[2].set(\freq, msg[1]);
    });

    this.addCommand("root_hz", "f", { arg msg;
      rootHz = msg[1];
      drone.set(\freq, rootHz);
    });

    this.addCommand("shimmer", "f", { arg msg;
      shimmerAmt = msg[1];
      voices.do { |v| v.set(\shimmer, shimmerAmt) };
    });

    this.addCommand("amp", "f", { arg msg;
      ampLevel = msg[1];
      voices.do { |v| v.set(\amp, ampLevel) };
    });

    this.addCommand("drone_amp", "f", { arg msg;
      drone.set(\amp, msg[1]);
    });
  }

  free {
    voices.do { |v| v.free };
    drone.free;
  }
}
