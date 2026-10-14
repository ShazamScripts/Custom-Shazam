--[[
    ESPECIAIS + TIMESPELL + STACK MOB INTEGRADO
    Interface padronizada: Macro + Config na mesma linha, com borda vermelha.
    Stack normal continua restrito a Player; Stack Mob trabalha somente com mobs validos.
]]

local function getAttackingCreature()
    local game = g_game or (modules and modules._G and modules._G.g_game)
    if game and type(game.getAttackingCreature) == "function" then return game.getAttackingCreature() end
    return nil
end

local function doAttack(creature)
    if not creature then return false end
    local game = g_game or (modules and modules._G and modules._G.g_game)
    if game and type(game.attack) == "function" then game.attack(creature) return true end
    return false
end

local function isCreatureInPz(creature)
    if not creature then return false end
    if type(creature.isInPz) == "function" then return creature:isInPz() end
    local pos = creature:getPosition()
    if not pos then return false end
    local tile = g_map.getTile(pos)
    return tile and type(tile.isProtectionZone) == "function" and tile:isProtectionZone() or false
end

local isKeyPressed = modules.corelib.g_keyboard.isKeyPressed
local gameRootPanel = g_ui.getRootWidget():recursiveGetChildById("gameRootPanel")
local AnchorTop, AnchorBottom, AnchorLeft, AnchorRight = 1, 2, 3, 4

local spellsTypes = {TRAP="Traps", STACK="Stack", STRAIGHT="Retas", DEFAULT="Outros"}
local spellsOptions = {spellsTypes.TRAP, spellsTypes.STACK, spellsTypes.STRAIGHT, spellsTypes.DEFAULT}
local spellsRespectOrder = {spellsTypes.TRAP}

local arrowKeys = {"Up", "Left", "Down", "Right"}
local wasdKeys = {"W", "A", "S", "D", "E", "Z", "Q", "C"}
local numpadKeys = {"Numpad8", "Numpad4", "Numpad2", "Numpad6", "Numpad9", "Numpad1", "Numpad7", "Numpad3"}
local stackDirections = {
    W={keys={"y"},signals={">"}}, A={keys={"x"},signals={">"}}, S={keys={"y"},signals={"<"}}, D={keys={"x"},signals={"<"}},
    C={keys={"x","y"},signals={"<","<"}}, Z={keys={"x","y"},signals={">","<"}}, E={keys={"x","y"},signals={">",">"}}, Q={keys={"x","y"},signals={"<",">"}}
}

local MobPatterns = {
    north=[[11111
11111
11111
11111
11111
11111
11111
11111
00000
00000
00000
00000
00000
00000
00000
00000
00000]],
    south=[[00000
00000
00000
00000
00000
00000
00000
00000
00000
11111
11111
11111
11111
11111
11111
11111
11111]],
    west=[[1111111110000000000
1111111110000000000
1111111110000000000
1111111110000000000
1111111110000000000]],
    east=[[0000000000111111111
0000000000111111111
0000000000111111111
0000000000111111111
0000000000111111111]],
    northEast=[[000011111
000011111
000011111
000011111
000001111
000000111
000000011
000000001
000000000]],
    northWest=[[111110000
111110000
111110000
111110000
111100000
111000000
110000000
100000000
000000000]],
    southEast=[[000000000
000000001
000000011
000000111
000001111
000011111
000011111
000011111
000011111]],
    southWest=[[000000000
100000000
110000000
111000000
111100000
111110000
111110000
111110000
111110000]]
}

local displayOptions = {
    {title="Nome time spell (Player)",var_name="showMsg",default_value="spellName"},
    {[spellsTypes.STACK]={title="Nome time spell (Mob)",var_name="showMsgMob"},title="Ignorar",var_name="dummyMobMsg",skip={spellsTypes.TRAP,spellsTypes.STRAIGHT,spellsTypes.DEFAULT}},
    {title="Mensagem em laranja",var_name="orangeMsg",default_value="spellName"},
    {title="Cooldown da magia (Player)",var_name="cooldownTotal",range={min=0,max=600}},
    {[spellsTypes.STACK]={title="Cooldown da magia (Mob)",var_name="cooldownTotalMob",range={min=0,max=600}},title="Ignorar CD",var_name="dummyMobCD",skip={spellsTypes.TRAP,spellsTypes.STRAIGHT,spellsTypes.DEFAULT}},
    {[spellsTypes.TRAP]={title="Tempo trapado",range={min=0,max=60}},[spellsTypes.STACK]={title="Distância máxima",var_name="distance",range={min=1,max=10}},title="Tempo active",var_name="activeTotal",range={min=0,max=180}},
    {[spellsTypes.DEFAULT]={title="Porcentagem do target",range={min=0,max=100}},title="Porcentagem",var_name="percent",range={min=0,max=100},skip={spellsTypes.TRAP,spellsTypes.STACK,spellsTypes.STRAIGHT}},
    {[spellsTypes.STACK]={title="Teclas direcionais (Stack Player)",var_name="selectedKeys",values={table.concat(wasdKeys,", "),table.concat(arrowKeys,", "),table.concat(numpadKeys,", ")}},[spellsTypes.STRAIGHT]={title="Porcentagem do target",var_name="percent",range={min=0,max=100}},title="Tecla para utilizar",var_name="key"},
    {[spellsTypes.STACK]={title="Controle do Stack em MOB",var_name="mobControlLayout",values={"WASD","Numpad","Setas"}},title="Configuração Extra",var_name="extraDummy",skip={spellsTypes.TRAP,spellsTypes.STRAIGHT,spellsTypes.DEFAULT}},
    {title="Usar somente em Players",var_name="onlyTarget",checkbox=true,only={spellsTypes.TRAP,spellsTypes.DEFAULT}}
}

local config, stackData, stackingCreature
local doRefreshSpells, doRegisterSpell
local spellsWidgets = {}
local stackIconWidget, stackMobIconWidget

local function persistEspecial()
    if type(ShazamPersistNow) == "function" then ShazamPersistNow()
    elseif type(saveConfig) == "function" then saveConfig() end
end

local function getAllKeys()
    local keys = {}
    local isMobileApp = (g_app and g_app.isMobile and g_app.isMobile()) or false

    if isMobileApp then
        keys = {"None", "F1", "F2", "Escape"}
    else
        local keyDescs = modules and modules.corelib and modules.corelib.KeyCodeDescs
        if type(keyDescs) == "table" then
            for _, key in pairs(keyDescs) do
                if key ~= "Unknown" then
                    table.insert(keys, key)
                end
            end
        end
    end

    table.sort(keys)
    table.insert(keys, 1, "None")
    table.insert(keys, 1, "AUTO")
    return keys
end

local function doConfigCheck()
    if type(storage.especiaisTS) ~= "table" then
        storage.especiaisTS={spells={},enabled=true,selected_type=spellsOptions[1],stackIconEnabled=true,stackIconPos={x=200,y=50},stackMobIconEnabled=true,stackMobIconPos={x=200,y=80}}
    end
    for _, option in ipairs(spellsOptions) do if storage.especiaisTS.spells[option] == nil then storage.especiaisTS.spells[option]={} end end
    if type(storage.especiaisTS.selected_type) ~= "string" or not table.find(spellsOptions, storage.especiaisTS.selected_type) then storage.especiaisTS.selected_type=spellsOptions[1] end
    if storage.especiaisTS.stackIconEnabled == nil then storage.especiaisTS.stackIconEnabled=true end
    if storage.especiaisTS.stackIconPos == nil then storage.especiaisTS.stackIconPos={x=200,y=50} end
    if storage.especiaisTS.stackMobIconEnabled == nil then storage.especiaisTS.stackMobIconEnabled=true end
    if storage.especiaisTS.stackMobIconPos == nil then storage.especiaisTS.stackMobIconPos={x=200,y=80} end
    config=storage.especiaisTS
end
doConfigCheck()

local function firstLetterUpper(str)
    if not str then return "" end
    return str:gsub("(%a)([%w_']*)",function(first,rest) return first:upper()..rest:lower() end)
end
local function formatRemainingTime(time)
    if not time or time <= os.time() then return "Pronto!" end
    return string.format("%.0f",time-os.time()).."s"
end

-- Visual do Time Spell padronizado com Fugas (TyrLivre).
local timespellStyle=[[UIWidget
  background-color: black
  padding: 0 5
  text-auto-resize: true
  focusable: true
  phantom: false
  draggable: true]]

local function attachSpellWidgetCallbacks(widget,isMob)
    widget.onDragEnter=function(self,mousePos)
        if not modules.corelib.g_keyboard.isCtrlPressed() then return false end
        self:breakAnchors(); self.movingReference={x=mousePos.x-self:getX(),y=mousePos.y-self:getY()}; self.isDragging=true; return true
    end
    widget.onDragMove=function(self,mousePos,moved)
        local parentRect=self:getParent():getRect()
        local newX=math.min(math.max(parentRect.x,mousePos.x-self.movingReference.x),parentRect.x+parentRect.width-self:getWidth())
        local newY=math.min(math.max(parentRect.y-self:getParent():getMarginTop(),mousePos.y-self.movingReference.y),parentRect.y+parentRect.height-self:getHeight())
        self:move(newX,newY)
        if isMob then self.entry.posMob={x=newX,y=newY} else self.entry.pos={x=newX,y=newY} end
        return true
    end
    widget.onMouseRelease=function(self,mousePos,mouseButton)
        if self.isDragging then
            self.isDragging=false
            persistEspecial()
            return true
        end
    end
end

local function getAllScreenWidgets()
    local widgets={}; for _,byName in pairs(spellsWidgets) do for _,widget in pairs(byName) do table.insert(widgets,widget) end end; return widgets
end
local function destroyAllWidgets()
    for _,widget in ipairs(getAllScreenWidgets()) do widget:destroy() end
    table.clear(spellsWidgets)
end
local function setupTimespellWidget(entry,isMob)
    local widget=setupUI(timespellStyle,g_ui.getRootWidget())
    local pName=isMob and entry.spellName.."_mob" or entry.spellName
    widget:setPosition(isMob and (entry.posMob or {x=50,y=80}) or (entry.pos or {x=50,y=50}))
    local name=firstLetterUpper((isMob and entry.showMsgMob) or (not isMob and entry.showMsg) or entry.spellName)
    widget:setText(name..": 0s")
    widget:setColor("green")
    widget.entry=entry; widget.isMobWidget=isMob
    attachSpellWidgetCallbacks(widget,isMob)
    spellsWidgets[entry.type]=spellsWidgets[entry.type] or {}
    spellsWidgets[entry.type][pName]=widget
end

local function doSetWidgetContent(widget)
    local entry=widget.entry
    local isMob=widget.isMobWidget
    local name=firstLetterUpper((isMob and entry.showMsgMob) or (not isMob and entry.showMsg) or entry.spellName)
    local nowTime=os.time()
    local activeTime=not isMob and (entry.activeTime or 0)-nowTime or -1
    local cooldownTime=(isMob and (entry.cooldownTimeMob or 0) or (entry.cooldownTime or 0))-nowTime
    local textToSet=name..": 0s"
    local color="green"
    if activeTime>=0 then
        textToSet=name..": "..math.ceil(activeTime).."s"
        color="orange"
    elseif cooldownTime>=0 then
        textToSet=name..": "..math.ceil(cooldownTime).."s"
        color="red"
    else
        if isMob then entry.cooldownTimeMob=nil
        else entry.activeTime=nil; entry.cooldownTime=nil end
    end
    if widget._text~=textToSet or widget._color~=color then
        widget:setText(textToSet); widget:setColor(color)
        widget._text=textToSet; widget._color=color
    end
end

local function hasStackAttack()
    local stackSpells = config and config.spells and config.spells[spellsTypes.STACK]
    return type(stackSpells) == "table" and #stackSpells > 0
end

local function updateStackIconsVisibility()
    local visible = hasStackAttack()
    if stackIconWidget then
        if visible then stackIconWidget:show() else stackIconWidget:hide() end
    end
    if stackMobIconWidget then
        if visible then stackMobIconWidget:show() else stackMobIconWidget:hide() end
    end
end

local function refreshStackIconVisual()
    if not stackIconWidget then return end
    if config.stackIconEnabled then stackIconWidget:setText("[Stack: ON]"); stackIconWidget:setColor("#00FFFF") else stackIconWidget:setText("[Stack: OFF]"); stackIconWidget:setColor("#FF4040") end
    updateStackIconsVisibility()
end
local function refreshStackMobIconVisual()
    if not stackMobIconWidget then return end
    if config.stackMobIconEnabled then stackMobIconWidget:setText("[Stack Mob: ON]"); stackMobIconWidget:setColor("#00FFFF") else stackMobIconWidget:setText("[Stack Mob: OFF]"); stackMobIconWidget:setColor("#FF4040") end
    updateStackIconsVisibility()
end

local function setupToggleIcon(pos,isMob)
    local widget=setupUI(timespellStyle,g_ui.getRootWidget()); widget:setPosition(pos)
    local function refresh() if isMob then refreshStackMobIconVisual() else refreshStackIconVisual() end end
    widget.onDragEnter=function(self,mousePos)
        if not modules.corelib.g_keyboard.isCtrlPressed() then return false end
        self:breakAnchors(); self.movingReference={x=mousePos.x-self:getX(),y=mousePos.y-self:getY()}; self.isDragging=true; return true
    end
    widget.onDragMove=function(self,mousePos,moved)
        local parentRect=self:getParent():getRect()
        local newX=math.min(math.max(parentRect.x,mousePos.x-self.movingReference.x),parentRect.x+parentRect.width-self:getWidth())
        local newY=math.min(math.max(parentRect.y-self:getParent():getMarginTop(),mousePos.y-self.movingReference.y),parentRect.y+parentRect.height-self:getHeight())
        self:move(newX,newY)
        if isMob then config.stackMobIconPos={x=newX,y=newY} else config.stackIconPos={x=newX,y=newY} end
        return true
    end
    widget.onMouseRelease=function(self,mousePos,mouseButton)
        if self.isDragging then self.isDragging=false; return true end
        if mouseButton==1 and not modules.corelib.g_keyboard.isCtrlPressed() then
            if isMob then config.stackMobIconEnabled=not config.stackMobIconEnabled else config.stackIconEnabled=not config.stackIconEnabled end
            refresh(); persistEspecial(); return true
        end
    end
    return widget
end

-- Macro + Config padronizados.
local botWidget=setupUI("Panel\n  height: 17\n\n  BotSwitch\n    id: switch\n    anchors.top: parent.top\n    anchors.left: parent.left\n    text-align: center\n    width: 130\n    !text: tr(\"Especiais\")\n\n  Button\n    id: configButton\n    anchors.top: prev.top\n    anchors.bottom: prev.bottom\n    anchors.left: prev.right\n    anchors.right: parent.right\n    text: Config\n")

local entryWidget=[[Label
  background-color: alpha
  text-offset: 37 4
  focusable: true
  height: 16
  font: verdana-11px-rounded
  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 3
  CheckBox
    id: spellTime
    anchors.left: prev.right
    anchors.verticalCenter: prev.verticalCenter
    width: 15
    height: 15
    margin-left: 3
  $focus:
    background-color: #00000055
  Button
    id: remove
    !text: tr('x')
    anchors.right: parent.right
    margin-right: 15
    text-offset: 1 0
    width: 15
    height: 15]]

local screenWidget=setupUI([[
MainWindow
  size: 320 360
  !text: tr("Especiais By Shazam")
  color: white
  Panel
    id: mainPanel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    image-border: 6
    TextList
      id: spellsList
      image-source: /images/ui/textedit
      anchors.centerIn: parent
      anchors.left: parent.left
      anchors.right: parent.right
      margin-top: 20
      margin-left: 10
      margin-right: 10
      image-border: 6
      height: 180
      vertical-scrollbar: spellsListScroll
    VerticalScrollBar
      id: spellsListScroll
      anchors.top: spellsList.top
      anchors.bottom: spellsList.bottom
      anchors.right: spellsList.right
      step: 10
      pixels-scroll: true
    TextEdit
      id: nameField
      anchors.bottom: spellsList.top
      anchors.left: parent.left
      margin-bottom: 5
      margin-left: 10
      width: 185
    Label
      !text: tr("Nome da Magia")
      anchors.bottom: prev.top
      anchors.left: prev.left
      margin-left: 50
      margin-bottom: 2
    ComboBox
      id: typeList
      anchors.top: parent.top
      anchors.left: spellsList.left
      anchors.right: spellsList.right
      text-offset: 3 0
      margin-top: 5
    Button
      id: addButton
      !text: tr("Adicionar")
      anchors.top: nameField.top
      anchors.bottom: nameField.bottom
      anchors.left: nameField.right
      anchors.right: spellsList.right
      margin-left: 5
    Label
      anchors.top: spellsList.bottom
      anchors.right: parent.right
      anchors.left: parent.left
      id: message
      margin-top: 2
      text-auto-resize: true
      text-align: center
      text-wrap: true
    Button
      id: closeButton
      !text: tr("Fechar")
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.left: parent.left
      margin-bottom: 1
]],g_ui.getRootWidget())

local registerWidget=setupUI([[
MainWindow
  size: 320 460
  !text: tr("Especiais + TimeSpell")
  color: white
  Panel
    id: mainPanel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    image-border: 6
  Button
    id: addButton
    !text: tr("Adicionar")
    anchors.left: mainPanel.left
    anchors.bottom: mainPanel.bottom
    margin-bottom: 5
    margin-left: 1
    width: 133
  Button
    id: backButton
    !text: tr("Voltar")
    anchors.bottom: mainPanel.bottom
    anchors.left: addButton.right
    anchors.right: mainPanel.right
    margin-bottom: 5
    margin-right: 2
    @onClick: self:getParent():hide()
]],g_ui.getRootWidget())

screenWidget:hide(); registerWidget:hide()

local function canStack(from,to,data)
    local isFirstCheck=(from.x==player:getPosition().x and from.y==player:getPosition().y)
    for i=1,#data.keys do
        local key,signal=data.keys[i],data.signals[i]
        if signal==">" then
            if from[key]>to[key] then
            elseif from[key]==to[key] then
                if isFirstCheck then return true end
                local sub_key=key=="x" and "y" or "x"; local p=player:getPosition()
                if math.abs(p[sub_key]-to[sub_key])>=math.abs(p[sub_key]-from[sub_key]) then return false end
            else return false end
        else
            if from[key]<to[key] then
            elseif from[key]==to[key] then
                if isFirstCheck then return true end
                local sub_key=key=="x" and "y" or "x"; local p=player:getPosition()
                if math.abs(p[sub_key]-to[sub_key])>=math.abs(p[sub_key]-from[sub_key]) then return false end
            else return false end
        end
    end
    return true
end

local stackSpectatorCache = { expires = 0, list = nil }
local function getCachedStackSpectators()
    if stackSpectatorCache.list and stackSpectatorCache.expires > now then return stackSpectatorCache.list end
    stackSpectatorCache.list = (ShazamCore and ShazamCore.getSpectators(false, 80) or getSpectators())
    stackSpectatorCache.expires = now + 100
    return stackSpectatorCache.list
end

local function getStackingCreature(key,entry)
    local data=stackDirections[key]; if not data then return nil end
    local playerPos=player:getPosition(); local result={pos=playerPos}
    for _,spec in ipairs(getCachedStackSpectators()) do
        local specPos=spec:getPosition()
        if specPos and spec:getId()~=player:getId() and spec:isPlayer() and not spec:isNpc() and not isCreatureInPz(spec) then
            if getDistanceBetween(specPos,playerPos)<=entry.distance and canStack(result.pos,specPos,data) and spec:canShoot() then result.pos=specPos; result.creature=spec end
        end
    end
    return result.creature
end

local function getMobStackingCreature(layout,maxDist)
    local pattern
    if layout=="Setas" then
        if isKeyPressed("Up") then pattern=MobPatterns.north elseif isKeyPressed("Down") then pattern=MobPatterns.south elseif isKeyPressed("Left") then pattern=MobPatterns.west elseif isKeyPressed("Right") then pattern=MobPatterns.east end
    elseif layout=="Numpad" then
        if isKeyPressed("Numpad8") then pattern=MobPatterns.north elseif isKeyPressed("Numpad2") then pattern=MobPatterns.south elseif isKeyPressed("Numpad4") then pattern=MobPatterns.west elseif isKeyPressed("Numpad6") then pattern=MobPatterns.east elseif isKeyPressed("Numpad9") then pattern=MobPatterns.northEast elseif isKeyPressed("Numpad7") then pattern=MobPatterns.northWest elseif isKeyPressed("Numpad3") then pattern=MobPatterns.southEast elseif isKeyPressed("Numpad1") then pattern=MobPatterns.southWest end
    else
        if isKeyPressed("W") then pattern=MobPatterns.north elseif isKeyPressed("S") then pattern=MobPatterns.south elseif isKeyPressed("A") then pattern=MobPatterns.west elseif isKeyPressed("D") then pattern=MobPatterns.east elseif isKeyPressed("E") then pattern=MobPatterns.northEast elseif isKeyPressed("Q") then pattern=MobPatterns.northWest elseif isKeyPressed("C") then pattern=MobPatterns.southEast elseif isKeyPressed("Z") then pattern=MobPatterns.southWest end
    end
    if not pattern then return nil end
    local playerPos=player:getPosition(); local furthestMonster; local maxMonsterDistance=-1
    for _,creature in pairs(getSpectators(playerPos,pattern)) do
        if not creature:isPlayer() and not creature:isNpc() and creature:getId()~=player:getId() and not isCreatureInPz(creature) then
            local cName=creature:getName():lower()
            if not cName:find("trainer") and not cName:find("treino") then
                local d=getDistanceBetween(playerPos,creature:getPosition())
                if d<=maxDist and d>maxMonsterDistance then maxMonsterDistance=d; furthestMonster=creature end
            end
        end
    end
    return furthestMonster
end

local function doCancelStack()
    if not stackData then return end
    for i=1,10 do schedule(i*50,function() local creature=getAttackingCreature(); if not creature or not stackingCreature then stackingCreature=nil; return end; if creature==stackingCreature then g_game.cancelAttack() end end) end
    stackData=nil
end

local function doStack()
    local entry=stackData.entry
    local creature=stackData.isMob and getMobStackingCreature(entry.mobControlLayout or "WASD",entry.distance or 7) or getStackingCreature(stackData.key,entry)
    if not creature then return doCancelStack() end
    -- Stack controla apenas o proprio estado de ataque.
    -- Nao grava nenhum delay compartilhado com Combo/Fugas.
    stackData.creature=creature
    if getAttackingCreature()~=creature then stackingCreature=creature; doAttack(creature) end
    schedule(10,function() say(entry.spellName,#spellsOptions-table.find(spellsOptions,spellsTypes.STACK)) end)
end

local function canUseStraight()
    local target=getAttackingCreature(); if not target then return false end
    local targetPos=target:getPosition(); if not targetPos then return false end
    local playerPos=player:getPosition(); local distance=getDistanceBetween(playerPos,targetPos)
    if distance>0 and distance<=7 then
        if playerPos.x>targetPos.x and math.abs(playerPos.y-targetPos.y)<=1 then turn(West); return true
        elseif playerPos.x<targetPos.x and math.abs(playerPos.y-targetPos.y)<=1 then turn(East); return true
        elseif playerPos.y>targetPos.y and math.abs(playerPos.x-targetPos.x)<=1 then turn(North); return true
        elseif playerPos.y<targetPos.y and math.abs(playerPos.x-targetPos.x)<=1 then turn(South); return true end
    end
    return false
end

local function canCast(entry)
    if not entry.enabled then return false end
    local key=entry.key
    if entry.type==spellsTypes.TRAP then
        if (entry.cooldownTime or 0)>=os.time() then return false end
        if table.find(spellsRespectOrder,entry.type) and hasAnyActive and hasAnyActive(entry.type) then return false end
        if key=="AUTO" then return getAttackingCreature()~=nil end
        if key==nil or not isKeyPressed(key) then return false end
        if entry.onlyTarget then
            local target = getAttackingCreature()
            if not target or not target:isPlayer() then return false end
        end
        return true
    end
    if entry.type==spellsTypes.STACK then
        if config.stackMobIconEnabled and (entry.cooldownTimeMob or 0)<os.time() then
            if getMobStackingCreature(entry.mobControlLayout or "WASD",entry.distance or 7) then return {isMob=true,key="MOB"} end
        end
        if config.stackIconEnabled and (entry.cooldownTime or 0)<os.time() then
            local currentTarget=getAttackingCreature()
            if currentTarget and currentTarget:isPlayer() and not currentTarget:isNpc() then
                for _,k in ipairs((entry.selectedKeys or ""):split(", ")) do if isKeyPressed(k) and getStackingCreature(k,entry) then return {isMob=false,key=k} end end
            end
        end
        return nil
    end
    if entry.type==spellsTypes.STRAIGHT then
        if (entry.cooldownTime or 0)>=os.time() then return false end
        local castPercent=tonumber(entry.percent); local target=getAttackingCreature()
        if castPercent and target and (target:getHealthPercent() or 100)<=castPercent then return canUseStraight() end
        if entry.key=="AUTO" or (key and isKeyPressed(key)) then return canUseStraight() end
        return false
    end
    if entry.type==spellsTypes.DEFAULT then
        if (entry.cooldownTime or 0)>=os.time() then return false end
        local castPercent=tonumber(entry.percent); local target=getAttackingCreature()
        if castPercent and target and (target:getHealthPercent() or 100)<castPercent then return true end
        if not key or not isKeyPressed(key) then return false end
        if entry.onlyTarget and (not target or not target:isPlayer()) then return false end
        return true
    end
    return false
end

local function doSpellCast(t)
    local spells=config.spells[t]; if #spells==0 then return end
    local respectOrder=table.find(spellsRespectOrder,t)
    for _,entry in ipairs(spells) do
        local result=canCast(entry)
        if result then
            if entry.type==spellsTypes.STACK then stackData={key=result.key,entry=entry,isMob=result.isMob}
            else say(entry.spellName,#spellsOptions-table.find(spellsOptions,entry.type)); if respectOrder then return end end
        end
    end
end

local function addAnchors(widget)
    local isLabel=widget:getStyleName()=="Label"; local hasAnyChild=registerWidget.mainPanel:getChildCount()~=1
    local lastAnchor=(hasAnyChild or not isLabel) and "prev" or "parent"; local lastDirection=(hasAnyChild or not isLabel) and AnchorBottom or AnchorTop
    widget:addAnchor(AnchorRight,"parent",AnchorRight); widget:addAnchor(AnchorLeft,"parent",AnchorLeft); widget:addAnchor(AnchorTop,lastAnchor,lastDirection)
end
local function createComboBox(data)
    local label=UI.createWidget("Label",registerWidget.mainPanel); addAnchors(label); label:setMarginTop(7); label:setMarginLeft(10); label:setText(data.title)
    local comboBox=UI.createWidget("ComboBox",registerWidget.mainPanel); addAnchors(comboBox); comboBox:setMarginLeft(10); comboBox:setMarginRight(10)
    for _,value in ipairs(data.values) do comboBox:addOption(value) end
    comboBox:setId(data.var_name); comboBox:setCurrentOption(data.text); comboBox.menuScroll=true; comboBox.menuScrollStep=10
end
local function createTextEdit(data)
    local label=UI.createWidget("Label",registerWidget.mainPanel); addAnchors(label); label:setMarginTop(7); label:setMarginLeft(10); label:setText(data.title)
    local textEdit=UI.createWidget("TextEdit",registerWidget.mainPanel); addAnchors(textEdit); textEdit:setMarginLeft(10); textEdit:setMarginRight(10); textEdit:setText(data.text); textEdit:setId(data.var_name)
end
local function createCheckBox(data)
    local label=UI.createWidget("Label",registerWidget.mainPanel); addAnchors(label); label:setMarginTop(7); label:setMarginLeft(10); label:setText(data.title)
    local checkBox=setupUI("CheckBox\n  width: 15\n  height: 15",registerWidget.mainPanel); addAnchors(checkBox); checkBox:setMarginLeft(10); checkBox:setMarginTop(2); checkBox:setId(data.var_name); checkBox:setChecked(data.text and true or false)
end
-- ============================================================
--  STEPPER  ( -  [valor]  +  )  -- substitui a barra com setas < >
--  Mesmo estilo dos botoes do Auto Treino. Mantem a API:
--  getValue() / setValue(v) / onValueChange(widget, valor)
-- ============================================================
local STEPPER_UI = [[
Panel
  height: 22

  Button
    id: minus
    anchors.top: parent.top
    anchors.left: parent.left
    width: 28
    height: 22
    text: <

  TextEdit
    id: edit
    anchors.top: parent.top
    anchors.left: minus.right
    margin-left: 4
    width: 60
    height: 22
    text-align: center

  Button
    id: plus
    anchors.top: parent.top
    anchors.left: edit.right
    margin-left: 4
    width: 28
    height: 22
    text: >

  Label
    id: unit
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: plus.right
    margin-left: 6
]]

local function createStepper(parent, minV, maxV, startValue, unit)
    local w = setupUI(STEPPER_UI, parent)
    w.isStepper = true
    w.minV = minV
    w.maxV = maxV
    w.value = minV
    w.busy = false
    w.unit:setText(unit or "")

    w.getValue = function(self) return self.value end

    w.setValue = function(self, v)
        v = math.floor(tonumber(v) or self.minV)
        v = math.max(self.minV, math.min(self.maxV, v))
        self.value = v
        self.busy = true
        self.edit:setText(tostring(v))
        self.busy = false
        if self.onValueChange then self.onValueChange(self, v) end
    end

    w.minus.onClick = function() w:setValue(w.value - 1) end
    w.plus.onClick = function() w:setValue(w.value + 1) end

    -- tambem da para digitar o valor direto
    w.edit.onTextChange = function(widget, text)
        if w.busy then return end
        local n = tonumber(text)
        if not n then return end
        if n < w.minV or n > w.maxV then
            w:setValue(n)
        else
            w.value = math.floor(n)
            if w.onValueChange then w.onValueChange(w, w.value) end
        end
    end

    w:setValue(startValue or minV)
    return w
end

local function createScrollBar(data)
    local label=UI.createWidget("Label",registerWidget.mainPanel); addAnchors(label); label:setMarginTop(7); label:setMarginLeft(10); label:setText(data.title)
    local suffix="s"; if data.range.min==1 then suffix="" elseif data.range.max==100 then suffix="%" end
    local stepper=createStepper(registerWidget.mainPanel,data.range.min,data.range.max,data.text or data.range.min,suffix)
    addAnchors(stepper); stepper:setMarginLeft(10); stepper:setMarginTop(2); stepper:setId(data.var_name)
end

doRegisterSpell=function(entry)
    screenWidget:hide(); registerWidget:show(); registerWidget.mainPanel:destroyChildren()
    for _,_data in ipairs(displayOptions) do
        local data=table.copy(_data)
        if data.skip and table.find(data.skip,config.selected_type) then goto continue end
        if data.only and not table.find(data.only,config.selected_type) then goto continue end
        local exclusive_data=data[config.selected_type]
        if exclusive_data then if data.range and not exclusive_data.range then data.range=nil end; for key,value in pairs(exclusive_data) do data[key]=value end end
        if data.var_name=="extraDummy" or data.var_name=="dummyMobMsg" or data.var_name=="dummyMobCD" then goto continue end
        if data.default_value then data.text=entry[data.default_value] end
        if entry[data.var_name]~=nil then data.text=entry[data.var_name] end
        if data.var_name=="key" then data.values=getAllKeys() end
        if data.values then createComboBox(data) goto continue end
        if data.range then createScrollBar(data) goto continue end
        if data.checkbox then createCheckBox(data) goto continue end
        createTextEdit(data)
        ::continue::
    end
end

-- Indice O(1) para mensagens laranja. Evita percorrer todas as categorias/magias
-- dentro do onTalk, que e um callback sensivel e estava gerando Slow onTalk.
local orangeMsgIndex = {}
local function rebuildOrangeMsgIndex()
    orangeMsgIndex = {}
    if not config or not config.spells then return end
    for _, t in ipairs(spellsOptions) do
        local spells = config.spells[t] or {}
        for _, entry in ipairs(spells) do
            local msg = entry.orangeMsg
            if type(msg) == "string" and msg ~= "" then
                msg = msg:trim():lower()
                local bucket = orangeMsgIndex[msg]
                if not bucket then bucket = {}; orangeMsgIndex[msg] = bucket end
                bucket[#bucket + 1] = entry
            end
        end
    end
end

doRefreshSpells=function()
    rebuildOrangeMsgIndex()
    destroyAllWidgets(); screenWidget.mainPanel.spellsList:destroyChildren()
    updateStackIconsVisibility()
    for _,t in ipairs(spellsOptions) do for _,entry in ipairs(config.spells[t]) do
        if config.enabled and entry.enabled and entry.spellTime then setupTimespellWidget(entry,false); if entry.type==spellsTypes.STACK and entry.showMsgMob then setupTimespellWidget(entry,true) end end
    end end
    local selectedSpells=config.spells[config.selected_type]
    for index,entry in ipairs(selectedSpells) do
        local widget=setupUI(entryWidget,screenWidget.mainPanel.spellsList)
        local function removeSpell() screenWidget.mainPanel.nameField:setText(entry.spellName); table.remove(selectedSpells,index); doRefreshSpells(); persistEspecial() end
        widget.onDoubleClick=function() doRegisterSpell(table.copy(entry)); removeSpell() end; widget.remove.onClick=removeSpell
        widget.enabled:setChecked(entry.enabled); widget.spellTime:setChecked(entry.spellTime)
        widget.enabled.onCheckChange=function(_,enabled) entry.enabled=enabled; doRefreshSpells(); persistEspecial() end
        widget.spellTime.onCheckChange=function(_,enabled) entry.spellTime=enabled; doRefreshSpells(); persistEspecial() end
        local text={firstLetterUpper(entry.spellName:sub(1,10)),"CD: "..(entry.cooldownTotal or 0).."s"}
        if entry.cooldownTotalMob then table.insert(text,"Mob CD: "..entry.cooldownTotalMob.."s") end
        if entry.percent then table.insert(text,((entry.percent==100 and "AUTO" or entry.percent).."%")) end
        if entry.key then table.insert(text,((entry.key=="AUTO" and "" or "Key: ")..entry.key)) end
        if entry.mobControlLayout then table.insert(text,"Mob: "..entry.mobControlLayout) end
        widget:setText(table.concat(text," | ")); widget:setId(entry.spellName)
    end
end

local warn=function(msg)
    local widget=screenWidget.mainPanel.message; widget.added=now+3000; widget:setText(msg); widget:setColor("yellow")
end
for _,option in ipairs(spellsOptions) do screenWidget.mainPanel.typeList:addOption(option) end
screenWidget.mainPanel.typeList:setCurrentOption(config.selected_type)

screenWidget.mainPanel.addButton.onClick=function()
    local spellName=screenWidget.mainPanel.nameField:getText():lower():trim(); local spells=config.spells[config.selected_type]
    if spellName:len()==0 then warn("Insira uma magia!"); return end
    for _,entry in ipairs(spells) do if entry.spellName==spellName then warn("Essa magia já existe"); return end end
    doRegisterSpell({spellName=spellName})
end

registerWidget.addButton.onClick=function()
    local children=registerWidget.mainPanel:getChildren(); local spellName=screenWidget.mainPanel.nameField:getText():trim():lower(); local spells=config.spells[config.selected_type]
    if spellName:len()==0 then return end
    local entry={spellName=spellName,enabled=true,type=config.selected_type,spellTime=true}
    for _,child in ipairs(children) do
        local value; local var_name=child:getId(); local styleName=child:getStyleName()
        if styleName=="ComboBox" then value=child:getCurrentOption().text; if value=="None" then value=nil end
        elseif styleName=="TextEdit" then local text=child:getText():trim():lower(); if text:len()>=1 then value=text end
        elseif styleName=="HorizontalScrollBar" or child.isStepper then value=child:getValue()
        elseif styleName=="CheckBox" then value=child:isChecked() end
        if value~=nil then entry[var_name]=value end
    end
    if entry.key=="AUTO" and (tonumber(entry.percent) or 0)>0 then entry.key=nil end
    if entry.percent==0 then entry.percent=nil end
    table.insert(spells,entry); doRefreshSpells(); screenWidget:show(); registerWidget:hide(); screenWidget.mainPanel.nameField:clearText(); persistEspecial()
end

screenWidget.mainPanel.typeList.onOptionChange=function(widget,option) if config then config.selected_type=option; doRefreshSpells(); persistEspecial() end end
screenWidget.mainPanel.closeButton.onClick=function() screenWidget:hide(); gameRootPanel:focus() end
screenWidget.onEscape=screenWidget.mainPanel.closeButton.onClick
screenWidget.onEnter=screenWidget.mainPanel.addButton.onClick
registerWidget.backButton.onClick=function() registerWidget:hide(); screenWidget:show() end

botWidget.configButton.onClick=function() screenWidget:show(); screenWidget:raise(); screenWidget:focus() end
botWidget.onMouseRelease=function(self,mousePos,mouseButton) if mouseButton==2 then screenWidget:show(); screenWidget:raise(); screenWidget:focus() end end
botWidget.switch.onClick=function() config.enabled=not config.enabled; botWidget.switch:setOn(config.enabled); doRefreshSpells(); persistEspecial() end
botWidget.switch:setOn(config.enabled)

stackIconWidget=setupToggleIcon(config.stackIconPos or {x=200,y=50},false)
stackMobIconWidget=setupToggleIcon(config.stackMobIconPos or {x=200,y=80},true)
refreshStackIconVisual(); refreshStackMobIconVisual(); doRefreshSpells()

local function isStackMovementPressed()
    local keys={"W","A","S","D","E","Z","Q","C","Up","Down","Left","Right","Numpad8","Numpad4","Numpad2","Numpad6","Numpad9","Numpad1","Numpad7","Numpad3"}
    for i=1,#keys do if isKeyPressed(keys[i]) then return true end end
    return false
end

local especiaisCastIndex = 1
macro(50,function()
    if not config.enabled or isCreatureInPz(player) then return end
    if stackData and not isStackMovementPressed() then doCancelStack() end
    if stackData then doStack() end

    -- Distribui a verificacao das categorias entre os ticks. Antes todas as
    -- categorias eram processadas no mesmo callback de 50ms, criando picos.
    -- Duas por tick mantem resposta rapida sem concentrar todo o trabalho.
    local total = #spellsOptions
    if total == 0 then return end
    for _=1,math.min(2,total) do
        doSpellCast(spellsOptions[especiaisCastIndex])
        especiaisCastIndex = especiaisCastIndex + 1
        if especiaisCastIndex > total then especiaisCastIndex = 1 end
    end
end)

macro(500,function()
    -- Evita varrer todos os widgets da tela quando Especiais esta desligado.
    if not config.enabled and screenWidget:isHidden() and registerWidget:isHidden() then return end
    for _,widget in ipairs(getAllScreenWidgets()) do doSetWidgetContent(widget) end
end)

onTalk(function(name,level,mode,text)
    -- Saida imediata para qualquer fala que nao possa atualizar cooldown.
    if mode~=44 or name~=g_game.getCharacterName() then return end
    local bucket = orangeMsgIndex[text:trim():lower()]
    if not bucket then return end

    local currentTime = os.time()
    for i=1,#bucket do
        local entry = bucket[i]
        if stackData and table.equal(entry,stackData.entry) then
            if stackData.isMob then
                local cd=entry.cooldownTotalMob or 0
                if cd>0 then entry.cooldownTimeMob=currentTime+cd end
            else
                local cd=entry.cooldownTotal or 0
                if cd>0 then entry.cooldownTime=currentTime+cd end
                if entry.activeTotal and entry.activeTotal>0 then entry.activeTime=currentTime+entry.activeTotal end
            end
            doCancelStack()
        elseif (entry.cooldownTime or 0)<currentTime then
            local cd=entry.cooldownTotal or 0
            if cd>0 then entry.cooldownTime=currentTime+cd end
            if entry.activeTotal and entry.activeTotal>0 then entry.activeTime=currentTime+entry.activeTotal end
        end
    end
end)

local windowPos
macro(500,function()
    if not config.enabled and screenWidget:isHidden() and registerWidget:isHidden() then return end
    if windowPos then for _,widget in ipairs({screenWidget,registerWidget}) do if widget:isHidden() then widget:breakAnchors(); widget:setPosition(windowPos) end end; windowPos=nil end
    if screenWidget:isVisible() then windowPos=screenWidget:getPosition() elseif registerWidget:isVisible() then windowPos=registerWidget:getPosition() end
end)
macro(500,function()
    if not config.enabled then return end
    local widget=screenWidget.mainPanel.message
    if widget.added then if widget.added<now then widget.added=nil elseif widget:isHidden() then widget:show() end end
    if widget.added==nil and widget:isVisible() then widget:hide() end
end)


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["especiais"] = {macro = botWidget.switch}
end
