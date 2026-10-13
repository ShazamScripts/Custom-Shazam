-- ============================================================================
-- SHAZAM CUSTOM - MAIN
-- Cabecalho principal da Custom Shazam.
-- Este arquivo e carregado primeiro pelo Loader.lua.
-- ============================================================================

setDefaultTab("Main")

-- Separador superior
local separatorTop = UI.Separator()
separatorTop:setColor("green")

-- Titulo centralizado
local shazamTitle = UI.Label("              Shazam Custom")
shazamTitle:setColor("green")
shazamTitle:setTextAlign(AlignCenter)
shazamTitle:setHeight(20)

-- Separador inferior
local separatorBottom = UI.Separator()
separatorBottom:setColor("green")

-- ============================================================================
-- TAMANHO DA JANELA DO BOT (Largura / Altura)
-- Sistema portado do CUSTOM SHAZAM / LoboScripts (extras/img_background.lua).
-- Mude os dois numeros abaixo para ajustar o tamanho da janela do bot.
-- ============================================================================
local botWindowSize = {
  largura = 225,
  altura  = 600,
}

local rootWidget = g_ui.getRootWidget()
if rootWidget then
  local botWindow = rootWidget:recursiveGetChildById("botWindow")
  if botWindow then
    local realG = modules["_G"]

    -- Guarda o tamanho ORIGINAL da janela (so na primeira vez) para devolver
    -- quando voce trocar de custom. Assim as outras customs nao ficam com a
    -- janela apertada/cortada.
    if not realG["__ShazamBotWindowOriginal"] then
      realG["__ShazamBotWindowOriginal"] = {
        largura = botWindow:getWidth(),
        altura = botWindow:getHeight(),
      }
    end

    botWindow:setWidth(botWindowSize.largura)
    botWindow:setHeight(botWindowSize.altura)

    ShazamGuard.onCleanup(function()
      local original = realG["__ShazamBotWindowOriginal"]
      realG["__ShazamBotWindowOriginal"] = nil
      -- So restaura se ninguem mexeu no tamanho depois de nos.
      if original and botWindow:getWidth() == botWindowSize.largura and botWindow:getHeight() == botWindowSize.altura then
        botWindow:setWidth(original.largura)
        botWindow:setHeight(original.altura)
      end
    end)
  end
end
