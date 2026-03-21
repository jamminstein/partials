-- partials
-- harmonic series phase canon
-- three voices walk the overtone series
-- each clock drifts slowly apart
-- v1.1 @jamminstein

engine.name = "Partials"

local lattice = require "lattice"

-- harmonic ratios: partials 4-16
-- these are the pitches that live in every vibrating string
local PARTIALS = {
  4/4,   -- root
  5/4,   -- major third (pure)
  6/4,   -- perfect fifth
  7/4,   -- "blues 7th" -- not in 12-TET
  8/4,   -- octave
  9/4,   -- major second
  10/4,  -- major third + octave
  11/4,  -- 11th partial -- sharp 4th (alien, beautiful)
  12/4,  -- fifth + octave
  13/4,  -- 13th partial -- slightly sharp minor 6th
  14/4,  -- flat 7th
  15/4,  -- major 7th
  16/4,  -- 2nd octave
}

-- partials that live outside 12-TET (highlighted on screen)
-- index 4 = 7/4, index 8 = 11/4, index 10 = 13/4
local MICROTONAL = {[4]=true, [8]=true, [10]=true}

local base_freq = 261.0  -- C4, default fundamental
local voice_count = 3    -- number of active voices (2-6)

-- FIX: declare main_lattice BEFORE rebuild_lattice so it is in upvalue scope
local main_lattice

local voices = {}

-- Initialize voices with base_freq and voice_count
local function init_voices()
  voices = {}
  for i = 1, voice_count do
    local start_idx = math.floor(((i - 1) * #PARTIALS) / voice_count) + 1
    voices[i] = {idx = start_idx, acc = 0.000, hz = base_freq * PARTIALS[start_idx]}
  end
end

-- Call initial setup
init_voices()

local drift    = 0.003  -- how much slower voices 2+3 run vs voice 1
local playing  = true

-- MIDI output device
local midi_out = nil

-- OP-XY MIDI
local opxy_out = nil
local function opxy_note_on(note, vel) if opxy_out then opxy_out:note_on(note, vel, params:get("opxy_channel")) end end
local function opxy_note_off(note) if opxy_out then opxy_out:note_off(note, 0, params:get("opxy_channel")) end end

local DIVS     = {1/32, 1/16, 1/8, 1/4, 1/2, 1}
local DIVNAMES = {"1/32","1/16","1/8","1/4","1/2","1"}
local div_idx  = 3  -- default 1/8

-- weighted random walk on harmonic index
-- favors +/-1 movement, slight pull back toward center
local function walk(idx)
  local r = math.random()
  if r < 0.45 then
    return math.max(1, math.min(#PARTIALS, idx + 1))
  elseif r < 0.90 then
    return math.max(1, math.min(#PARTIALS, idx - 1))
  elseif idx > 7 then
    return idx - 1  -- gentle drift back toward center from top
  else
    return idx
  end
end

local function set_voice_hz(i)
  if i > voice_count then return end
  local v = voices[i]
  v.hz = base_freq * PARTIALS[v.idx]
  engine["v" .. i .. "_hz"](v.hz)

  -- Send MIDI note on voice's channel (ch 1-6)
  local midi_note = 69 + 12 * math.log(v.hz / 440) / math.log(2)
  midi_note = math.floor(midi_note + 0.5)
  midi_note = math.max(0, math.min(127, midi_note))
  if midi_out then
    midi_out:note_on(midi_note, 90, i)  -- i = channel 1-6
  end
  opxy_note_on(midi_note, 90)
end

local function rebuild_lattice()
  -- FIX: destroy the whole old lattice, not just the sprocket
  -- (previously only sprocket:destroy() was called, leaving the
  --  parent lattice running and firing a second action every tick)
  if main_lattice then main_lattice:destroy() end

  main_lattice = lattice:new()
  main_lattice:new_sprocket({
    action = function(t)
      if not playing then return end

      for i, v in ipairs(voices) do
        if i <= voice_count then
          if i == 1 then
            -- FIX: voice 1 uses a simple every-tick step (no acc)
            -- Previously voice 1 was walked unconditionally AND
            -- also walked again when its acc overflowed, causing
            -- occasional double-steps.
            v.idx = walk(v.idx)
            set_voice_hz(1)
          else
            -- FIX: voices 2+ each accumulate at their own rate
            -- rate = 1.0 - (drift * i), so:
            --   voice 2 at drift=0.003 accumulates 0.994/tick -> steps every ~1.006 ticks
            --   voice 3 at drift=0.003 accumulates 0.991/tick -> steps every ~1.009 ticks
            -- This gives genuine, independent phase drift between all voices.
            local rate = 1.0 - (drift * i)
            v.acc = v.acc + rate
            if v.acc >= 1.0 then
              v.acc = v.acc - 1.0
              v.idx = walk(v.idx)
              set_voice_hz(i)
            end
          end
        end
      end
      redraw()
    end,
    division = DIVS[div_idx],
    enabled  = true,
  })
  main_lattice:start()
end

function init()
  midi_out = midi.connect(1)

  params:add_separator("OP-XY MIDI")
  params:add{type="number", id="opxy_device", name="OP-XY Device", min=1, max=16, default=2, action=function(v) opxy_out = midi.connect(v) end}
  params:add{type="number", id="opxy_channel", name="OP-XY Channel", min=1, max=16, default=1}
  opxy_out = midi.connect(params:get("opxy_device"))

  engine.shimmer(0.002)

  params:add_separator("PARTIALS")

  -- Base frequency parameter (20-880 Hz, default 261)
  params:add_control("base_freq", "base freq",
    controlspec.new(20, 880, "exp", 1, 261, "Hz"))
  params:set_action("base_freq", function(v)
    base_freq = v
    -- retune all voices immediately
    for i = 1, voice_count do set_voice_hz(i) end
    redraw()
  end)

  -- Voice count parameter (2-6, default 3)
  params:add_option("voice_count", "voice count",
    {"2", "3", "4", "5", "6"}, 2)
  params:set_action("voice_count", function(idx)
    voice_count = idx + 1
    init_voices()
    rebuild_lattice()
    redraw()
  end)

  params:add_control("shimmer", "shimmer",
    controlspec.new(0, 0.05, "lin", 0.001, 0.002, ""))
  params:set_action("shimmer", function(v)
    engine.shimmer(v)
  end)

  params:add_control("amp", "amp",
    controlspec.new(0, 1, "lin", 0.01, 0.28, ""))
  params:set_action("amp", function(v)
    engine.amp(v)
  end)

  rebuild_lattice()
  redraw()
end

function enc(n, d)
  if n == 1 then
    -- base frequency: semitone steps (12-TET ratio)
    local factor = d > 0 and 1.05946 or 0.94387
    base_freq = math.max(20, math.min(880, base_freq * factor))
    params:set("base_freq", base_freq)
    -- retune all voices immediately
    for i = 1, voice_count do set_voice_hz(i) end
  elseif n == 2 then
    drift = math.max(0.0, math.min(0.05, drift + d * 0.001))
  elseif n == 3 then
    div_idx = math.max(1, math.min(#DIVS, div_idx + d))
    rebuild_lattice()
  end
  redraw()
end

function key(n, z)
  if z == 0 then return end
  if n == 2 then
    playing = not playing
  elseif n == 3 then
    -- Reset all voices to unison (phase 0)
    for i = 1, voice_count do
      voices[i].idx = 1  -- all to root
      voices[i].acc = 0
      set_voice_hz(i)
    end
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.aa(1)

  -- ── Title + play state ──
  screen.font_face(7)
  screen.font_size(8)
  screen.level(playing and 15 or 4)
  screen.move(2, 8)
  screen.text("PARTIALS")

  screen.level(playing and 12 or 3)
  screen.move(126, 8)
  screen.text_right(playing and ">" or ".")

  -- ── Base freq display ──
  screen.level(5)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(64, 8)
  screen.text_center(string.format("%.0f Hz", base_freq))

  -- ── Voice lanes ──
  local lane_count = math.min(voice_count, #voices)
  local lane_h = math.floor(38 / math.max(1, lane_count))
  for i = 1, lane_count do
    local v = voices[i]
    if not v then break end
    local y = 12 + (i - 1) * lane_h
    local ratio = (v.idx - 1) / (#PARTIALS - 1)
    local x = math.floor(ratio * 100) + 10

    -- Voice label
    screen.level(3)
    screen.font_size(8)
    screen.move(2, y + lane_h - 2)
    screen.text(i)

    -- Lane track with partial markers
    screen.level(1)
    screen.move(10, y + math.floor(lane_h / 2))
    screen.line(110, y + math.floor(lane_h / 2))
    screen.stroke()

    -- Tick marks at microtonal positions
    for idx, _ in pairs(MICROTONAL) do
      local tick_x = math.floor(((idx - 1) / (#PARTIALS - 1)) * 100) + 10
      screen.level(2)
      screen.move(tick_x, y + 2)
      screen.line(tick_x, y + lane_h - 2)
      screen.stroke()
    end

    -- Voice position dot
    local is_micro = MICROTONAL[v.idx]
    local dot_r = is_micro and 4 or 3
    screen.level(is_micro and 15 or 10)
    screen.circle(x, y + math.floor(lane_h / 2), dot_r)
    screen.fill()

    -- Partial ratio label
    screen.level(is_micro and 12 or 4)
    screen.font_size(8)
    local lx = math.min(x + 6, 108)
    screen.move(lx, y + math.floor(lane_h / 2) + 3)
    local num = math.floor(PARTIALS[v.idx] * 4 + 0.5)
    screen.text(num .. "/4")
  end

  -- ── Bottom bar: drift + division ──
  screen.font_face(1)
  screen.font_size(8)

  -- Drift label + bar
  screen.level(4)
  screen.move(2, 60)
  screen.text("drift")
  -- Bar background
  screen.level(2)
  screen.rect(30, 57, 60, 3)
  screen.stroke()
  -- Bar fill
  local drift_w = math.floor(drift / 0.05 * 60)
  if drift_w > 0 then
    screen.level(8)
    screen.rect(30, 57, drift_w, 3)
    screen.fill()
  end

  -- Division
  screen.level(6)
  screen.move(126, 60)
  screen.text_right(DIVNAMES[div_idx])

  screen.update()
end

function cleanup()
  if main_lattice then main_lattice:destroy() end
  if midi_out then for ch=1,16 do midi_out:cc(123,0,ch) end end
  if opxy_out then for ch=1,16 do opxy_out:cc(123,0,ch) end end
end