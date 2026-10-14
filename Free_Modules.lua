-- ============================================================================
-- SHAZAM SCRIPTS - LOADER (baseado no #zloader)
--
-- Carregamento seguro e explicito:
-- * cada arquivo e protegido por pcall;
-- * erro em um modulo nao derruba o restante da custom;
-- * CaveBot e TargetBot sao carregados diretamente pelas pastas reais;
-- * ordem das macros controlada pelas listas abaixo;
-- * evita carregar o mesmo modulo duas vezes.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Abas / compatibilidade basica
-- ---------------------------------------------------------------------------
-- Ordem fixa das abas da Custom Shazam:
-- Main -> User -> Others -> Cave -> Target
setDefaultTab("Main")
setDefaultTab("User")
setDefaultTab("Others")
setDefaultTab("Cave")
setDefaultTab("Target")

storage = storage or {}
_G = _G or modules["_G"]
_G.configData = _G.configData or {}
storage.extras = storage.extras or {}
tk = tk or {}
tk.storage = storage

-- ---------------------------------------------------------------------------
-- 2) Helpers de carregamento seguro
-- ---------------------------------------------------------------------------
local function load(path)
  local ok, result = pcall(dofile, path)
  if not ok then
    print("[Loader] erro ao carregar '" .. path .. "': " .. tostring(result))
    return nil
  end
  return result
end

local function style(path)
  local ok, result = pcall(importStyle, path)
  if not ok then
    print("[Loader] erro ao importar estilo '" .. path .. "': " .. tostring(result))
    return nil
  end
  return result
end

-- ---------------------------------------------------------------------------
-- 3) Core da Custom Shazam
-- ---------------------------------------------------------------------------
-- Mantem apenas o Guard/Storage da Shazam. O CaveBot e TargetBot abaixo sao
-- os arquivos originais da Arts, sem vlib/new_cavebot_lib e sem extensoes do
-- CaveBot antigo da Shazam. Isso reduz callbacks/loops carregados em background.
load("Free Modules/Core_System_Otimizado.lua")

if type(ShazamGuard) ~= "table" then
  ShazamGuard = {
    session = {}, alive = function() return true end, check = function() return true end,
    beat = function() end, onCleanup = function() end, trackWidget = function(widget) return widget end,
    connect = function(object, handlers)
      local connectFn = modules["_G"]["connect"]
      if type(connectFn) == "function" then pcall(connectFn, object, handlers) end
      return handlers
    end,
  }
end

load("Cavebot/items.lua")
load("Cavebot/vlib.lua")
load("Cavebot/new_cavebot_lib.lua")

load("Free Modules/Storage.lua")
load("Free Modules/Queue_call.lua")
tk.storage = storage
storage.extras = storage.extras or {}

-- ---------------------------------------------------------------------------
-- 4) CaveBot
-- ---------------------------------------------------------------------------
setDefaultTab("Cave")

CaveBot = CaveBot or {}
CaveBot.Extensions = {}

style("Cavebot/cavebot.otui")
style("Cavebot/config.otui")
style("Cavebot/editor.otui")

load("Cavebot/actions.lua")
load("Cavebot/config.lua")
load("Cavebot/editor.lua")
load("Cavebot/example_functions.lua")
load("Cavebot/recorder.lua")
load("Cavebot/walking.lua")
load("Cavebot/minimap.lua")
load("Cavebot/sell_all.lua")
load("Cavebot/depositor.lua")
load("Cavebot/buy_supplies.lua")
load("Cavebot/d_withdraw.lua")
load("Cavebot/supply_check.lua")
load("Cavebot/travel.lua")
load("Cavebot/doors.lua")
load("Cavebot/pos_check.lua")
load("Cavebot/withdraw.lua")
load("Cavebot/inbox_withdraw.lua")
load("Cavebot/lure.lua")
load("Cavebot/bank.lua")
load("Cavebot/clear_tile.lua")
load("Cavebot/tasker.lua")
load("Cavebot/imbuing.lua")
load("Cavebot/stand_lure.lua")
load("Cavebot/cavebot.lua")

-- ---------------------------------------------------------------------------
-- 5) TargetBot
-- ---------------------------------------------------------------------------
setDefaultTab("Target")

TargetBot = TargetBot or {}

style("Target/looting.otui")
style("Target/target.otui")
style("Target/creature_editor.otui")

load("Target/creature.lua")
load("Target/creature_attack.lua")
load("Target/creature_editor.lua")
load("Target/creature_priority.lua")
load("Target/looting.lua")
load("Target/walking.lua")
load("Target/target.lua")

-- ---------------------------------------------------------------------------
-- 5.5) Coordenador de casts: Fugas tem prioridade absoluta
-- ---------------------------------------------------------------------------
ShazamCastCoordinator = ShazamCastCoordinator or {}
local _castLockUntil = 0
local _lastCastKind = nil
local _castGap = 0.08

function ShazamCastCoordinator.canCast(kind)
  local nowClock = os.clock()
  if kind == "fuga" then return true end
  if type(ShazamFugaPriorityReady) == "function" and ShazamFugaPriorityReady() then return false end
  return nowClock >= _castLockUntil
end

function ShazamCastCoordinator.claim(kind)
  local nowClock = os.clock()
  if kind ~= "fuga" and type(ShazamFugaPriorityReady) == "function" and ShazamFugaPriorityReady() then return false end
  _lastCastKind = kind
  _castLockUntil = nowClock + _castGap
  return true
end

function ShazamCastCoordinator.getLastCastKind() return _lastCastKind end

-- ---------------------------------------------------------------------------
-- 6) Macros
-- ---------------------------------------------------------------------------

setDefaultTab("Main")

local MACRO_ORDER = {
  "pktime.lua",
  "Battle_filter.lua",
  "Combo.lua",
  "Buffs.lua",
  "Especiais.lua",
  "Fugas.lua",
  "Target.lua",
  "Follow_target.lua",
  "Potion.lua",
  "Auto_kai.lua",
  "Summon.lua",
  "Sense.lua",
  "Escadas.lua",
  "Jump.lua",
  "Enemy.lua",
  "BugMap.lua",
}

local USER_ORDER = {
  "User.lua",
  "Loot_Channel.lua",
}

local OTHERS_ORDER = {
  "Bless.lua",
  "Macros_PT.lua",
  "Follow_Player.lua",
  "travel_system.lua",
  "Auto_Treino.lua",
  "Loot Pouch.lua",
  "IngameScripts.lua",
}

-- Macros extras da aba Cave.
-- Exemplo: coloque "Alarms.lua" no topo para carrega-la primeiro.
local CAVEBOT_ORDER = {
  -- "Alarms.lua",
}

-- Macros extras da aba Target.
-- Exemplo: coloque "MinhaMacro.lua" aqui para controla-la separadamente.
local TARGET_ORDER = {
  -- "MinhaMacro.lua",
}

local loadedMacro = {}

local function loadMacro(tabName, fileName)
  if loadedMacro[fileName] then
    return
  end

  loadedMacro[fileName] = true
  setDefaultTab(tabName)
  return load("Free Modules/" .. fileName)
end

-- Main primeiro: cria o cabecalho visual da Custom Shazam na aba Main.
-- O arquivo fica separado para facilitar futuras edicoes.
loadMacro("Main", "Main.lua")
loadMacro("Main", "Slow_Monitor.lua")

-- User primeiro, pois fornece helpers usados por outras macros.
for _, fileName in ipairs(USER_ORDER) do
  loadMacro("User", fileName)
end

-- Others: ferramentas e scripts editaveis da aba Others.
for _, fileName in ipairs(OTHERS_ORDER) do
  loadMacro("Others", fileName)
end

-- Main na ordem definida acima.
for _, fileName in ipairs(MACRO_ORDER) do
  loadMacro("Main", fileName)
end

-- Icones de CAVE / TARGET (liga/desliga pela tela). Depois do User.lua e das macros.
loadMacro("Main", "Icon.lua")

-- Cavebot na ordem definida acima.
for _, fileName in ipairs(CAVEBOT_ORDER) do
  loadMacro("Cave", fileName)
end

-- Target na ordem definida acima.
for _, fileName in ipairs(TARGET_ORDER) do
  loadMacro("Target", fileName)
end

setDefaultTab("Main")
