UI.Separator()
leaderPositions = {}
local leaderDirections = {}
local leader
local lastLeaderFloor
local ropeId = 9596
local standTime = now
local lastLeaderMoveAt = 0
local lastFollowWalkAt = 0
local lastFollowDestination = nil
local FOLLOW_DISTANCE = 1
local FOLLOW_WALK_INTERVAL = 300
local LEADER_STILL_MS = 450
local lastLeaderRemoval
local currentPosition

local function copyPosition(position)
  if not position then return nil end
  local x, y, z = tonumber(position.x), tonumber(position.y), tonumber(position.z)
  if x == nil or y == nil or z == nil then return nil end
  return {x = x, y = y, z = z}
end

local function safeMethod(object, methodName)
  if not object or type(object[methodName]) ~= "function" then return nil end
  local ok, value = pcall(function() return object[methodName](object) end)
  if ok then return value end
  return nil
end

local function isLeaderCreature(creature)
  if not creature or safeMethod(creature, "isPlayer") ~= true then return false end
  local name = safeMethod(creature, "getName")
  local configuredName = tostring(storage.rtsFollow or "")
  return name and configuredName ~= "" and name:lower() == configuredName:lower()
end

local function removedTilePosition(tile)
  return copyPosition(safeMethod(tile, "getPosition"))
end

local function samePosition(first, second)
  return first and second and first.x == second.x and first.y == second.y and first.z == second.z
end

local function followRemovedLeaderTile(tile, creature)
  if ultimateFollow and ultimateFollow.isOff and ultimateFollow.isOff() then return end
  if not player or not currentPosition() or not isLeaderCreature(creature) then return end

  local tilePos = removedTilePosition(tile)
  if not tilePos then return end
  local direction = safeMethod(creature, "getDirection")
  local capturedAt = tonumber(now) or 0

  leaderPositions[tilePos.z] = copyPosition(tilePos)
  lastLeaderFloor = tilePos.z
  if direction ~= nil then leaderDirections[tilePos.z] = direction end
  lastLeaderRemoval = {position = copyPosition(tilePos), tile = tile, at = capturedAt}
  leader = nil

  local walkPrecision = safeMethod(tile, "hasCreature") == false and 0 or 1
  autoWalk(tilePos, 40, {
  ignoreNonPathable = true,
  ignoreCreatures = false,
  precision = walkPrecision
  })
end

currentPosition = function()
  if not g_game or type(g_game.isOnline) ~= "function" or not g_game.isOnline() then
    return nil
  end
  if type(pos) ~= "function" then return nil end
  local ok, position = pcall(pos)
  if ok and position then return position end
  return nil
end

FloorChangers = {
RopeSpots = {
Up = {386, 12202, 211966},
Down = {}
},

Use = {
Up = {1948, 14559, 5542, 16693, 16692, 1723, 7771, 28906, 20474, 33770, 33985, 5129, 5111, 16277, 37001, 28906},
Down = {435, 28906, 1648, 1646, 8912, 8911, 32642, 5952, 1644, 25054, 1764, 1968}
}
}

local function getPlayerByName(name)
  if not name then
    return nil
  end

  local center = currentPosition()
  if not center or not g_map or type(g_map.getSpectators) ~= "function" then return nil end
  local spectators = type(OblivionGetSpectatorsCached) == "function"
    and OblivionGetSpectatorsCached(false) or nil
  if type(spectators) ~= "table" then
    local ok
    ok, spectators = pcall(function() return g_map.getSpectators(center, false) end)
    if not ok or type(spectators) ~= "table" then return nil end
  end

  local wantedName = tostring(name):lower()

  for _, creature in ipairs(spectators) do
    if creature:isPlayer() and creature:getName():lower() == wantedName then
      return creature
    end
  end

  return nil
end

-- Algumas builds deste client nao exportam o helper global levitate. Nesse
-- caso a acao nao existia de qualquer forma, mas a tentativa gerava um erro a
-- cada ciclo do follow e alimentava o log sem parar.
local function tryLevitate(direction)
  if type(levitate) ~= "function" then return false end
  local ok = pcall(levitate, direction)
  return ok
end

local function handleUse(pos)
  local lastZ = posz()
  if posz() == lastZ then
    local newTile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
    if newTile then
      g_game.use(newTile:getTopUseThing())
    end
  end
end

local function handleRope(pos)
  local lastZ = posz()
  if posz() == lastZ then
    local newTile = g_map.getTile({x = pos.x, y = pos.y, z = pos.z})
    if newTile then
      useWith(ropeId, newTile:getTopUseThing())
    end
  end
end

local floorChangeSelector = {
RopeSpots = {Up = handleRope, Down = handleRope},
Use = {Up = handleUse, Down = handleUse}
}

local function distance(pos1, pos2)
  local pos2 = pos2 or player:getPosition()
  return math.abs(pos1.x - pos2.x) + math.abs(pos1.y - pos2.y)
end

local function executeClosest(possibilities)
  local closest
  local closestDistance = 99999

  for _, data in ipairs(possibilities) do
    local dist = distance(data.pos)

    if dist < closestDistance then
      closest = data
      closestDistance = dist
    end
  end

  if closest then
    closest.changer(closest.pos)
    return true
  end

  return false
end

local function handleFloorChange()
  local range = 1
  local p = player:getPosition()
  local possibleChangers = {}

  for _, dir in ipairs({"Down", "Up"}) do
    for changer, data in pairs(FloorChangers) do
      for x = -range, range do
        for y = -range, range do
          local tile = g_map.getTile({
          x = p.x + x,
          y = p.y + y,
          z = p.z
          })

          if tile and tile:getTopUseThing() then
            if table.find(data[dir], tile:getTopUseThing():getId()) then
              table.insert(possibleChangers, {
              changer = floorChangeSelector[changer][dir],
              pos = {
              x = p.x + x,
              y = p.y + y,
              z = p.z
              }
              })
            end
          end
        end
      end
    end
  end

  if #possibleChangers > 0 then
    return executeClosest(possibleChangers)
  end

  return false
end

local function matchPos(p1, p2)
  return (p1.x == p2.x and p1.y == p2.y)
end

local function handleUsing()
  if true then
    handleFloorChange()
  else
    local usePos = leaderUsePositions[posz()]

    if usePos then
      local useTile = g_map.getOrCreateTile(usePos)

      if useTile then
        use(useTile:getTopUseThing())
      end
    end
  end
end

local function useRope(pos)
  if not pos then
    pos = player:getPosition()
  end

  local dirs = {
  {0, 0},
  {-1, 0},
  {1, 0},
  {0, -1},
  {0, 1},
  {1, -1},
  {1, 1},
  {-1, 1},
  {-1, -1}
  }

  for i = 1, #dirs do
    local tpos = {
    x = pos.x + dirs[i][1],
    y = pos.y + dirs[i][2],
    z = posz()
    }

    local tile = g_map.getTile(tpos)

    if tile then
      if tile:getGround() then
        local ropeSpots = FloorChangers.RopeSpots.Up

        if table.contains(ropeSpots, tile:getGround():getId()) then
          local waitTime = getDistanceBetween(player:getPosition(), tpos) * 60
          handleRope(tpos)
          delay(waitTime)
          return true
        end
      end
    end
  end

  return false
end

local function getStandTime()
  return now - standTime
end

ultimateFollow = macro(350, "Follow RTS", function()
  if not leader then
    local leaderPos = leaderPositions[posz()]

    if leaderPos then
      if getDistanceBetween(player:getPosition(), leaderPos) > 0 then
        if autoWalk(leaderPos, 80, {
        ignoreNonPathable = true,
        precision = 0
        }) then
          delay(200)
          return
        end
      end
    end

    if lastLeaderFloor and lastLeaderFloor ~= posz() then
      if handleFloorChange() then
        return
      end

      local dir = leaderDirections[posz()]

      if dir then
        tryLevitate(dir)
      end
    else
      local levitatePos = listenedLeaderPosDir

      if levitatePos and matchPos(player:getPosition(), levitatePos) then
        tryLevitate(listenedLeaderDir)
        return
      end

      if useRope(leaderPos) then
        return
      end

      handleUsing()
    end
  else
    listenedLeaderPosDir = nil
    listenedLeaderDir = nil

    local lpos = leader:getPosition()
    local distance = getDistanceBetween(player:getPosition(), lpos)

    -- Evita perseguir cada oscilacao do lider quando ele para.
    if distance <= FOLLOW_DISTANCE then
      lastFollowDestination = nil
      return
    end

    local leaderStopped = (now - lastLeaderMoveAt) >= LEADER_STILL_MS
    local destinationChanged = not samePosition(lastFollowDestination, lpos)
    if now - lastFollowWalkAt >= FOLLOW_WALK_INTERVAL and
       (destinationChanged or distance > 3 or leaderStopped) then
      if getStandTime() > 250 then
        lastFollowWalkAt = now
        lastFollowDestination = copyPosition(lpos)
        if autoWalk(lpos, 40, {
          ignoreNonPathable = true,
          precision = FOLLOW_DISTANCE,
          ignoreCreatures = true
        }) then
          delay(200)
          return
        end
      end
    end

    if distance > 1 and not findPath(
    player:getPosition(),
    lpos,
    20,
    {
    ignoreNonPathable = true,
    precision = 1
    }
    ) then
      handleUsing()
    end
  end
end)

UI.Label("Follow Player:")

UI.TextEdit(storage.rtsFollow or "Name", function(widget, text)
  storage.rtsFollow = text
  leader = getPlayerByName(text)
end)

if type(onRemoveThing) == "function" then
  onRemoveThing(function(tile, thing)
    followRemovedLeaderTile(tile, thing)
  end)
end

onCreaturePositionChange(function(creature, newPos, oldPos)
  if ultimateFollow.isOff() then
    return
  end

  if not player or not currentPosition() then return end

  if creature:getName() == player:getName() then
    standTime = now
    return
  end

  if not creature:isPlayer() then
    return
  end

  if not isLeaderCreature(creature) then
    return
  end

  if newPos then
    leaderPositions[newPos.z] = newPos
    lastLeaderFloor = newPos.z

    if newPos.z == posz() then
      leader = creature
    else
      leader = nil
    end
  else
    leader = nil
  end

  local removalAlreadyHandled = oldPos and lastLeaderRemoval
  and samePosition(lastLeaderRemoval.position, oldPos)
  and (tonumber(now) or 0) - (tonumber(lastLeaderRemoval.at) or 0) <= 100
  if newPos and oldPos and newPos.z == oldPos.z then
    lastLeaderMoveAt = now
  end
  if oldPos and not removalAlreadyHandled and
     (not newPos or newPos.z ~= oldPos.z) then
    if newPos and oldPos.z ~= newPos.z then
      leaderDirections[oldPos.z] = creature:getDirection()
    end
    autoWalk(oldPos, 40, {
      ignoreNonPathable = true,
      ignoreCreatures = false,
      precision = 1
    })
  end
end)

onCreatureAppear(function(creature)
  if ultimateFollow.isOff() then
    return
  end

  if not player or not currentPosition() then return end

  local creaturePosition = safeMethod(creature, "getPosition")
  if not creaturePosition or creaturePosition.z ~= posz() then
    return
  end

  if isLeaderCreature(creature) then
    leader = creature
  elseif creature:getName() == player:getName() then
    if lastLeaderFloor and lastLeaderFloor == posz() then
      leader = getPlayerByName(storage.rtsFollow)
    end
  end
end)

onCreatureDisappear(function(creature)
  if ultimateFollow.isOff() then
    return
  end

  if not player or not currentPosition() then return end

  if isLeaderCreature(creature) then
    leader = nil
  elseif safeMethod(creature, "getName") == safeMethod(player, "getName") and posz() ~= lastLeaderFloor then
    leader = nil
  end
end)

leader = getPlayerByName(storage.rtsFollow)

macro(200, "Follow Normal", function()
  if ultimateFollow and ultimateFollow.isOn() then return end
  local center = currentPosition()
  if not center then return end
  if g_game.isFollowing() then
    return
  end

  local spectators = type(OblivionGetSpectatorsCached) == "function"
    and OblivionGetSpectatorsCached(false) or nil
  if type(spectators) ~= "table" then
    local ok
    ok, spectators = pcall(function() return g_map.getSpectators(center, false) end)
    if not ok or type(spectators) ~= "table" then return end
  end
  for _, followcreature in ipairs(spectators) do
    if followcreature:isPlayer()
    and followcreature:getName():lower() == tostring(storage.rtsFollow or ""):lower()
    and getDistanceBetween(center, followcreature:getPosition()) <= 8 then
      g_game.follow(followcreature)
    end
  end
end)

UI.Separator()
