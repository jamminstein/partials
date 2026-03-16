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

local ROOT_HZ = 55.0  -- A1

-- FIX: declare main_lattice BEFORE rebuild_lattice so it is in upvalue scope
local main_lattice

local voices = {
  {idx = 1, acc = 0.000, hz = ROOT_HZ * (4/4)},
  {idx = 5, acc = 0.000, hz = ROOT_HZ * (8/4)},
  {idx = 9, acc = 0.000, hz = ROOT_HZ * (12/4)},
}

local drift    = 0.003  -- how much slower voices 2+3 run vs voice 1
local playing  = true

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
  local v = voices[i]
  v.hz = ROOT_HZ * PARTIALS[v.idx]
  engine["v" .. i .. "_hz"](v.hz)
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
        if i == 1 then
          -- FIX: voice 1 uses a simple every-tick step (no acc)
          -- Previously voice 1 was walked unconditionally AND
          -- also walked again when its acc overflowed, causing
          -- occasional double-steps.
          v.idx = walk(v.idx)
          set_voice_hz(1)
        else
          -- FIX: voices 2 and 3 each accumulate at their own rate
          -- rate = 1.0 - (drift * i), so:
          --   voice 2 at drift=0.003 accumulates 0.994/tick -> steps every ~1.006 ticks
          --   voice 3 at drift=0.003 accumulates 0.991/tick -> steps every ~1.009 ticks
          -- This gives genuine, independent phase drift between all three voices.
          -- Previously all voices shared the same drift amount, so voices 2 and 3
          -- always overflowed at the same tick -- no actual relative drift.
          local rate = 1.0 - (drift * i)
          v.acc = v.acc + rate
          if v.acc >= 1.0 then
            v.acc = v.acc - 1.0
            v.idx = walk(v.idx)
            set_voice_hz(i)
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
  engine.root_hz(ROOT_HZ)
  engine.shimmer(0.002)

  params:add_separator("PARTIALS")

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
    -- root frequency: semitone steps (12-TET ratio)
    local factor = d > 0 and 1.05946 or 0.94387
    ROOT_HZ = math.max(27.5, math.min(440, ROOT_HZ * factor))
    engine.root_hz(ROOT_HZ)
    -- retune all voices immediately
    for i = 1, 3 do set_voice_hz(i) end
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
    -- randomize all voice positions
    for i, v in ipairs(voices) do
      v.idx = math.random(1, #PARTIALS)
      set_voice_hz(i)
    end
  end
  redraw()
end

function redraw()
  screen.clear()

  -- title
  screen.level(3)
  screen.move(1, 7)
  screen.text("partials")

  -- FIX: replaced Unicode symbols (not in norns bitmap font) with ASCII
  if playing then
    screen.level(15)
    screen.move(120, 7)
    screen.text(">")
  else
    screen.level(4)
    screen.move(120, 7)
    screen.text(".")
  end

  -- three voice lanes
  for i, v in ipairs(voices) do
    local y = 16 + (i - 1) * 16
    local ratio = (v.idx - 1) / (#PARTIALS - 1)
    local x = math.floor(ratio * 96) + 10

    -- lane background track
    screen.level(2)
    screen.move(10, y + 4)
    screen.line(106, y + 4)
    screen.stroke()

    -- dot: brighter for microtonal partials (7/4, 11/4, 13/4)
    local brightness = MICROTONAL[v.idx] and 15 or 10
    screen.level(brightness)
    screen.circle(x, y + 4, 3)
    screen.fill()

    -- FIX: clamp label x so it never clips past the right edge (128px)
    screen.level(MICROTONAL[v.idx] and 12 or 5)
    local lx = math.min(x + 5, 108)
    screen.move(lx, y + 8)
    local num = math.floor(PARTIALS[v.idx] * 4 + 0.5)
    screen.text(num .. "/4")
  end

  -- drift indicator bar
  screen.level(4)
  screen.move(1, 60)
  screen.text("drift")
  screen.level(8)
  screen.move(28, 60)
  screen.line(28 + math.floor(drift / 0.05 * 60), 60)
  screen.stroke()

  -- step div
  screen.level(4)
  screen.move(100, 60)
  screen.text(DIVNAMES[div_idx])

  screen.update()
end

function cleanup()
  if main_lattice then main_lattice:destroy() end
end
