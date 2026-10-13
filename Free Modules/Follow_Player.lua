-- Follow RTS extraido de Macros_PT.lua - OTCv8
-- Carregue somente uma copia deste Follow.
-- Cache curto de spectators (evita varias leituras iguais do mapa no mesmo ciclo)
FREE_GET_SPECTATORS_CACHED = FREE_GET_SPECTATORS_CACHED or function(multifloor, ttl)
  ttl = tonumber(ttl) or 40
  local cache = FREE_SPECTATORS_CACHE
  if type(cache) ~= "table" then
    cache = {}
    FREE_SPECTATORS_CACHE = cache
  end

  local clockNow = tonumber(now) or 0
  local key = multifloor and "multi" or "single"
  if cache[key] and (clockNow - (cache[key].at or 0)) <= ttl then
    return cache[key].list
  end

  local ok, list = pcall(function()
    return getSpectators(multifloor == true)
  end)
  if not ok or type(list) ~= "table" then
    return {}
  end

  cache[key] = {at = clockNow, list = list}
  return list
end


-----------------------------------------------------------------------------
-- FOLLOW RTS / FOLLOW PLAYER PROTOTYPE OTIMIZADO  (aba OTHERS)
-- Substitui SOMENTE o antigo Follow RTS.
-- Follow Target (Follow_target.lua) e Attack Target (Target.lua) permanecem intactos.
-----------------------------------------------------------------------------
setDefaultTab("Others")

FollowPlayerRTS = FollowPlayerRTS or {
  obstaclesQueue = {},
  currentTargetId = nil,
  obstacleWalkTime = 0,
  lastPathAt = 0,
  lastPathKey = nil,
  lastPath = nil,
  lastLeaderPos = nil,
  lastLeaderSeen = 0,
  walkDirTable = {
    [0]={'y',-1}, [1]={'x',1}, [2]={'y',1}, [3]={'x',-1}
  },
  flags = {ignoreNonPathable=true, precision=0, ignoreCreatures=true},
  jumpSpell = {up='jump', down='jump'},
  defaultItem = 1111,
  defaultSpell = 'jump',
  customIds = {
    {id=1948,castSpell=false}, {id=595,castSpell=false},
    {id=1067,castSpell=false}, {id=1080,castSpell=false},
    {id=386,castSpell=true},
  }
}
-- IDs das escadas de USE (adicione os IDs reais do servidor, separados por virgula).
storage.rtsLadderIds = storage.rtsLadderIds or ""
local ladderText, ladderSet = nil, {}
local function ladderIds()
  local value = tostring(storage.rtsLadderIds or "")
  if value ~= ladderText then
    ladderText, ladderSet = value, {}
    for n in value:gmatch("%d+") do ladderSet[tonumber(n)] = true end
  end
  return ladderSet
end

local function findLadderNear(p)
  if not p then return nil end
  local ids = ladderIds()
  for radius=0,1 do
    for dx=-radius,radius do
      for dy=-radius,radius do
        if math.max(math.abs(dx),math.abs(dy)) == radius then
          local tilePos={x=p.x+dx,y=p.y+dy,z=p.z}
          local tile=g_map.getTile(tilePos)
          if tile then
            for _,item in ipairs(tile:getItems() or {}) do
              if ids[item:getId()] then return tilePos,item:getId() end
            end
          end
        end
      end
    end
  end
  return nil
end

local FP=FollowPlayerRTS

local function fpCopy(p) return p and {x=p.x,y=p.y,z=p.z} or nil end
local function fpSame(a,b) return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
local function fpDist(a,b)
  if not a or not b then return 999 end
  return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))
end

local function fpPath(fromPos,toPos,maxDist,flags,ttl)
  if ShazamCore and ShazamCore.findPath then
    return ShazamCore.findPath(fromPos,toPos,maxDist,flags,ttl or 180)
  end
  return findPath(fromPos,toPos,maxDist,flags)
end

function FP.getDirection(p,dir)
  local o={x=p.x,y=p.y,z=p.z}
  local d=FP.walkDirTable[dir]
  if d then o[d[1]]=o[d[1]]+d[2] end
  return o
end

function FP.walkPath(path)
  if path and path[1] then g_game.walk(path[1],false) return true end
  return false
end

function FP.checkItem(tile,list)
  if not tile then return nil end
  local items=tile:getItems()
  if not items then return nil end
  for _,item in ipairs(items) do
    local id=item:getId()
    for _,v in ipairs(list) do if id==v.id then return v end end
  end
end

local function fpQueueKey(o)
  local p=o.tilePos or o.oldPos
  return (o.isLadder and "L" or o.isDoor and "D" or o.isStair and "S" or o.isJump and "J" or "C")..
    ":"..(p and (p.x..":"..p.y..":"..p.z) or "?")
end

function FP.enqueue(o)
  local key=fpQueueKey(o)
  for _,v in ipairs(FP.obstaclesQueue) do if fpQueueKey(v)==key then return end end
  if #FP.obstaclesQueue>=4 then table.remove(FP.obstaclesQueue,1) end
  o.createdAt = now
  table.insert(FP.obstaclesQueue,o)
end

function FP.shift()
  if g_game.getFollowingCreature() then g_game.cancelFollow() end
  table.remove(FP.obstaclesQueue,1)
end

local function fpLeader()
  local name=tostring(storage.rtsFollow or "")
  if name=="" then return nil end
  if type(getCreatureByName)=="function" then
    local c=getCreatureByName(name)
    if c and c:isPlayer() then return c end
  end
  local list=(ShazamCore and ShazamCore.getSpectators(false,80)) or FREE_GET_SPECTATORS_CACHED(false,80)
  for _,c in ipairs(list or {}) do
    if c:isPlayer() and c:getName():lower()==name:lower() then return c end
  end
end

local function fpDetectDoor(newPos,oldPos)
  if not newPos or not oldPos or newPos.z~=oldPos.z then return end
  if math.abs(newPos.x-oldPos.x)~=2 and math.abs(newPos.y-oldPos.y)~=2 then return end
  local d={z=oldPos.z}
  if math.abs(oldPos.x-newPos.x)>math.abs(oldPos.y-newPos.y) then
    d.x=newPos.x+(oldPos.x-newPos.x>0 and 1 or -1); d.y=newPos.y
  else
    d.x=newPos.x; d.y=newPos.y+(oldPos.y-newPos.y>0 and 1 or -1)
  end
  local tile=g_map.getTile(d)
  if tile and not tile:isPathable() and not tile:isWalkable() then
    FP.enqueue({newPos=fpCopy(newPos),tilePos=d,tile=tile,isDoor=true})
  end
end

local function fpHasNearbyStair(p)
  for x=-1,1 do for y=-1,1 do
    if g_map.getMinimapColor({x=p.x+x,y=p.y+y,z=p.z})==210 then return true end
  end end
  return false
end

local function fpDetectFloor(newPos,oldPos)
  if not newPos or not oldPos or newPos.z==oldPos.z then return end
  local ladderPos,ladderId=findLadderNear(oldPos)
  if ladderPos then
    FP.enqueue({oldPos=fpCopy(oldPos),newPos=fpCopy(newPos),tilePos=ladderPos,isLadder=true,ladderId=ladderId})
    return
  end
  local tile=g_map.getTile(oldPos)
  if g_map.getMinimapColor(oldPos)==210 and tile and not tile:isPathable() then
    FP.enqueue({oldPos=fpCopy(oldPos),newPos=fpCopy(newPos),tilePos=fpCopy(oldPos),tile=tile,isStair=true})
    return
  end
  local custom=FP.checkItem(tile,FP.customIds)
  if custom then
    FP.enqueue({oldPos=fpCopy(oldPos),newPos=fpCopy(newPos),tilePos=fpCopy(oldPos),tile=tile,customId=custom,isCustom=true})
    return
  end
  -- Nao descarte a transicao so porque ha uma escada perto.
  -- Esse retorno fazia o Follow ignorar a maioria das escadas.
  local spell=newPos.z>oldPos.z and FP.jumpSpell.down or FP.jumpSpell.up
  local dir
  if newPos.z>oldPos.z then dir=newPos.y~=oldPos.y and 2 or 1
  else dir=newPos.x~=oldPos.x and 3 or 0 end
  FP.enqueue({oldPos=fpCopy(oldPos),oldTile=tile,spell=spell,dir=dir,isJump=true})
end

local function fpApproach(p,maxDist)
  local path=fpPath(pos(),p,maxDist or 35,{ignoreNonPathable=true,precision=0,ignoreCreatures=false},180)
  return FP.walkPath(path)
end

local function fpProcessObstacle()
  local o=FP.obstaclesQueue[1]
  if not o then return false end
  if now - (o.createdAt or now) > 6500 then FP.shift(); return false end
  local me=pos()
  local p=o.isJump and o.oldPos or o.tilePos
  if not p then FP.shift(); return true end
  if p.z~=posz() then FP.shift(); return true end
  local dist=fpDist(me,p)

  if o.isLadder then
    local tile=g_map.getTile(o.tilePos)
    if dist<=1 then
      if now>=FP.obstacleWalkTime and tile then
        for _,item in ipairs(tile:getItems() or {}) do
          if item:getId()==o.ladderId then
            use(item)
            FP.obstacleWalkTime=now+450
            break
          end
        end
      end
    else
      fpApproach(o.tilePos,35)
    end
    return true
  end

  if o.isDoor then
    if o.newPos and fpSame(me,o.newPos) then FP.shift(); return true end
    if dist<=1 and now>=FP.obstacleWalkTime then
      local tile=g_map.getTile(o.tilePos) or o.tile
      if tile and tile:getTopThing() then g_game.use(tile:getTopThing()) end
      FP.obstacleWalkTime=now+400
    else fpApproach(o.tilePos,35) end
    return true
  end

  if o.isStair then
    local tile=g_map.getTile(o.tilePos) or o.tile
    if dist<2 and now>=FP.obstacleWalkTime then
      if tile and tile:getTopUseThing() then
        use(tile:getTopUseThing())
      elseif dist == 0 then
        -- Escadas e portais de pisar: nao exigem use.
      else
        fpApproach(o.tilePos,2)
      end
      FP.obstacleWalkTime=now+250
    else fpApproach(o.tilePos,35) end
    return true
  end

  if o.isJump then
    if dist==0 then
      if now>=FP.obstacleWalkTime then
        g_game.turn(o.dir); say(o.spell); FP.obstacleWalkTime=now+450
      end
    elseif dist<2 then fpApproach(o.oldPos,2)
    else fpApproach(o.oldPos,35) end
    return true
  end

  if o.isCustom then
    local tile=g_map.getTile(o.tilePos) or o.tile
    if dist==0 and o.customId.castSpell then
      if now>=FP.obstacleWalkTime then say(FP.defaultSpell); FP.obstacleWalkTime=now+450 end
    elseif dist<2 then
      local item=findItem(FP.defaultItem)
      if not o.customId.castSpell and item and tile then g_game.useWith(item,tile); FP.shift()
      else fpApproach(o.tilePos,2) end
    else fpApproach(o.tilePos,35) end
    return true
  end
  return false
end

-- Um unico callback para observar o lider: menos custo que os 4 callbacks do Prototype.
onCreaturePositionChange(function(creature,newPos,oldPos)
  if not ultimateFollow or ultimateFollow.isOff() then return end
  if not creature or creature:getId()~=FP.currentTargetId or not oldPos then return end
  if newPos then FP.lastLeaderPos=fpCopy(newPos); FP.lastLeaderSeen=now end
  if newPos and newPos.z==oldPos.z then fpDetectDoor(newPos,oldPos)
  elseif newPos then fpDetectFloor(newPos,oldPos)
  elseif oldPos then
    -- Teleporte/portal pode remover o lider sem informar posicao nova.
    local tile=g_map.getTile(oldPos)
    local lp,lid=findLadderNear(oldPos)
    if lp then
      FP.enqueue({tilePos=lp,oldPos=fpCopy(oldPos),isLadder=true,ladderId=lid})
    elseif tile then
      FP.enqueue({tilePos=fpCopy(oldPos),oldPos=fpCopy(oldPos),isStair=true})
    end
  end
end)

-- Mantem o nome/atalho ultimateFollow para compatibilidade com Atalhos.
ultimateFollow=macro(100,"Follow Player",function()
  -- Processa a escada/portal mesmo quando o lider sumiu da tela.
  if fpProcessObstacle() then return end
  local target=fpLeader()
  if not target then return end
  FP.currentTargetId=target:getId()

  local tpos=target:getPosition()
  if not tpos then return end
  FP.lastLeaderPos=fpCopy(tpos)
  FP.lastLeaderSeen=now
  local following=g_game.getFollowingCreature()

  if tpos.z==posz() then
    -- Follow nativo evita reenvio de comandos de caminhada e funciona
    -- mesmo se o pathfinder nao encontrar rota momentaneamente.
    if not following or following:getId()~=target:getId() then g_game.follow(target) end
  elseif following and following:getId()==target:getId() then
    g_game.cancelFollow()
  end
end)

-- Campo do lider fica imediatamente abaixo da macro Follow RTS.
local followNameLabel = UI.Label("Player do Follow:")
local followNameEdit = UI.TextEdit(storage.rtsFollow or "Nome do player", function(widget, text)
  storage.rtsFollow = text
  FP.currentTargetId = nil
  FP.obstaclesQueue = {}
  FP.lastLeaderPos = nil
end)

-- Config de escadas no mesmo formato visual do Auto-Escadas:
-- botao Config e container de itens com icones, sem campo de IDs solto.
local ladderConfigRow = setupUI([[
Panel
  height: 17

  Button
    id: config
    anchors.fill: parent
    text: Config Escadas / Portais
]])

local ladderConfigWidgets = {}
local ladderConfigOpen = false
local function addLadderConfigWidget(widget)
  table.insert(ladderConfigWidgets, widget)
  widget:setVisible(false)
  return widget
end

addLadderConfigWidget(UI.Separator())
addLadderConfigWidget(UI.Label("IDs das Escadas/Portais"))
local ladderContainer = addLadderConfigWidget(UI.Container(function(widget, items)
  local ids, seen = {}, {}
  for _, entry in ipairs(items or {}) do
    local id = tonumber(entry.id)
    if id and id > 0 and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = tostring(math.floor(id))
    end
  end
  storage.rtsLadderIds = table.concat(ids, ",")
  ladderText = nil -- atualiza o cache da deteccao imediatamente
end, true))
ladderContainer:setHeight(35)

local initialItems = {}
local seenInitial = {}
for id in tostring(storage.rtsLadderIds or ""):gmatch("%d+") do
  local number = tonumber(id)
  if number and not seenInitial[number] then
    seenInitial[number] = true
    initialItems[#initialItems + 1] = {id = number}
  end
end
ladderContainer:setItems(initialItems)
addLadderConfigWidget(UI.Separator())

ladderConfigRow.config.onClick = function()
  ladderConfigOpen = not ladderConfigOpen
  for _, widget in ipairs(ladderConfigWidgets) do
    widget:setVisible(ladderConfigOpen)
  end
end

-- Limpeza leve. Nao existe macro(1).
macro(300,function()
  if not ultimateFollow or ultimateFollow.isOff() then
    if #FP.obstaclesQueue>0 then FP.obstaclesQueue={} end
    return
  end
  local o=FP.obstaclesQueue[1]
  if o then
    local p=o.isJump and o.oldPos or o.tilePos
    if p and math.abs(p.z-posz())>1 then table.remove(FP.obstaclesQueue,1) end
  end
end)


-- Atalho Follow RTS (compatibilidade com Atalhos).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["followRts"] = {macro = ultimateFollow}
end
