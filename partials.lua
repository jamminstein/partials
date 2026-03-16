-- partials
-- harmonic series phase canon
-- three voices walk the overtone series
-- each clock drifts slowly apart
-- v1.0 @jamminstein

engine.name = "Partials"

local lattice = require "lattice"
local sprocket

-- harmonic ratios: partials 4-16
-- these are the pitches that live in every vibrating string
local PARTIALS = {
  4/4,   -- root
  5/4,   -- major third (pure)
  6/4,   -- perfect fifth
  7/4,   -- "blues 7th" — doesn't exist in 12-TET
  8/4,   -- octave
  9/4,   -- major second
  10/4,  -- major third + octave
  11/4,  -- 11th partial — sharp 4th (alien, beautiful)
  12/4,  -- fifth + octave
  13/4,  -- 13th partial — slightly sharp minor 6th
  14/4,  -- flat 7th
  15/4,  -- major 7th
  16/4,  -- 2nd octave
}

-- partials that live outside 12-TET (highlighted on screen)
local MICROTONAL = {[4]=true, [8]=true, [10]=true}  -- indices 4, 8, 10 = 7/4, 11/4, 13/4

local ROOT_HZ = 55.0  -- A1

local voices = {
  {idx = 1,  phase = 0.000, acc = 0.000, hz = ROOT_HZ * (4/4)},
  {idx = 5,  phase = 0.000, acc = 0.003, hz = ROOT_HZ * (8/4)},
  {idx = 9,  phase = 0.000, acc = 0.006, hz = ROOT_HZ * (12/4)},
}

local drift    = 0.003  -- phase drift per tick
local playing  = true
local step_div = 1/8

-- step divisions available
local DIVS     = {1/32, 1/16, 1/8, 1/4, 1/2, 1}
local DIVNAMES = {"1/32","1/16","1/8","1/4","1/2","1"}
local div_idx  = 3  -- default 1/8

-- weighted random walk on harmonic index
-- favors ±1 movement, slight pull back toward center (idx 5)
local function walk(idx)
  local r = math.random()
  if r < 0.45 then
    return math.max(1, math.min(#PARTIALS, idx + 1))
  elseif r < 0.90 then
    return math.max(1, math.min(#PARTIALS, idx - 1))
  elseif idx > 7 then
    return idx - 1  -- gentle drift back toward center
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
  if sprocket then sprocket:destroy() end
  local l = lattice:new()
  sprocket = l:new_sprocket({
    action = function(t)
      if not playing then return end
      for i, v in ipairs(voices) do
        v.acc = v.acc + drift
        if v.acc >= 1.0 then
          v.acc = v.acc - 1.0
          v.idx = walk(v.idx)
          set_voice_hz(i)
        end
        -- voice 1 steps every tick; 2 & 3 accumulate drift
        if i == 1 then
          v.idx = walk(v.idx)
          set_voice_hz(1)
        end
      end
      redraw()
    end,
    division = step_div,
    enabled  = true,
  })
  l:start()
  return l
end

local main_lattice

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

  main_lattice = rebuild_lattice()
  redraw()
end

function enc(n, d)
  if n == 1 then
    -- root frequency: semitone steps
    local factor = d > 0 and 1.05946 or 0.94387
    ROOT_HZ = math.max(27.5, math.min(440, ROOT_HZ * factor))
    engine.root_hz(ROOT_HZ)
    -- retune all voices immediately
    for i = 1, 3 do set_voice_hz(i) end
  elseif n == 2 then
    drift = math.max(0.0, math.min(0.05, drift + d * 0.001))
  elseif n == 3 then
    div_idx = math.max(1, math.min(#DIVS, div_idx + d))
    step_div = DIVS[div_idx]
    main_lattice = rebuild_lattice()
  end
  redraw()
end

function key(n, z)
  if z == 0 then return end
  if n == 2 then
    playing = not playing
  elseif n == 3 then
    -- randomize starting positions
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

  -- play indicator
  if playing then
    screen.level(15)
    screen.move(120, 7)
    screen.text("▶")
  else
    screen.level(4)
    screen.move(120, 7)
    screen.text("■")
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

    -- dot: brighter for microtonal partials
    local brightness = MICROTONAL[v.idx] and 15 or 10
    screen.level(brightness)
    screen.circle(x, y + 4, 3)
    screen.fill()

    -- partial label
    screen.level(MICROTONAL[v.idx] and 12 or 5)
    screen.move(x + 5, y + 8)
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
