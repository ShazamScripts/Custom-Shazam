-- ============================================================================
-- COMBO UNIFICADO: ATTACK TARGET + FAST ATTACK PACKET (Sem sistema anterior)
-- ============================================================================
setDefaultTab("Main")

storage["scrollBars"] = storage["scrollBars"] or {}
local keepTarget = {
    actionKey = "Escape", -- Tecla para cancelar o ataque manualmente
    delayTime = 0,
    creatureId = nil,
    creatureName = nil
}

-- [SISTEMA FAST ATTACK] - Função que injeta o clique ultra rápido
local function doFastAttack(creature)
    if not creature or not g_game.isOnline() then return false end
    
    local playerPos = g_game.getLocalPlayer():getPosition()
    local creaturePos = creature:getPosition()
    if not playerPos or not creaturePos or creaturePos.z ~= playerPos.z then return false end

    -- Força a seleção visual e envia o pacote direto pro servidor
    local gameMapPanel = modules.game_interface.getMapPanel()
    if gameMapPanel then
        local oldValue = gameMapPanel.allowNextRelease
        gameMapPanel.allowNextRelease = true
        g_game.attack(creature) -- Injeta o ataque nativo direto
        gameMapPanel.allowNextRelease = oldValue
    end
    return true
end

function keepTarget:resetVariables()
    self.delayTime = 0
    self.creatureId = nil
    self.creatureName = nil
    g_game.cancelAttack()
end

function keepTarget:setAttackingCreature(creature)
    self.creatureId = creature:getId()
    self.creatureName = creature:getName()
end

function keepTarget:verifyAttackingCreature()
    if not self.creatureId then return nil end
    return getCreatureById(self.creatureId)
end

local isKeyPressed = modules.corelib.g_keyboard.isKeyPressed

-- [SISTEMA ATTACK TARGET] - Macro que gerencia quem atacar
attackTargetMacro = macro(100, "Attack Target", function(self)
    -- O callback da macro so roda quando ela esta ON. Mantemos o caminho comum
    -- (alvo ja atacado) o mais leve possivel para evitar Slow Macro.
    if isKeyPressed(keepTarget.actionKey) then
        return keepTarget:resetVariables()
    end

    local creature = g_game.getAttackingCreature()
    if creature and creature:isPlayer() then
        local id = creature:getId()
        if keepTarget.creatureId ~= id then
            keepTarget:setAttackingCreature(creature)
        end
        -- Se o cliente ja esta atacando o alvo salvo, nao ha nada pesado a fazer.
        return
    end

    if not keepTarget.creatureId then return end
    if keepTarget.delayTime and keepTarget.delayTime >= now then return end
    if type(isInPz) == "function" and isInPz() then return end

    -- So procura pelo ID quando realmente perdemos o ataque atual.
    local target = getCreatureById(keepTarget.creatureId)
    if not target then
        -- Ao trocar de andar, o cliente pode recriar o ID da criatura.
        -- Procura o mesmo jogador pelo nome, sem apagar o lock anterior.
        if keepTarget.creatureName then
            for _, candidate in ipairs(getSpectators() or {}) do
                if candidate:isPlayer() and candidate:getName() == keepTarget.creatureName then
                    target = candidate
                    keepTarget.creatureId = candidate:getId()
                    break
                end
            end
        end
        if not target then
            keepTarget.delayTime = now + 300
            return
        end
    end

    if not target:isPlayer() then return end

    if doFastAttack(target) then
        keepTarget.delayTime = now + math.random(200, 300)
    end
end)


-- Atalhos: registra esta macro para aparecer na janela Atalhos (aba User).
do
  local g = (type(_G) == "table" and _G) or modules["_G"]
  g.configData = g.configData or {}
  g.configData["attackTarget"] = {macro = attackTargetMacro}
end
