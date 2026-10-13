-- ============================================================================
-- SHAZAM CUSTOM - INGAME SCRIPTS
-- Sistema de scripts editaveis dentro do client.
-- O botao fica na aba Others e o script salvo e executado ao carregar.
-- ============================================================================

setDefaultTab("Others")

-- Migracao unica: se ja existia um script salvo no formato antigo
-- (storage.shadow_scripts, compartilhado entre todos os personagens),
-- copia ele para o storage por personagem na primeira vez.
if not tk.storage["scriptsArea"] and type(storage.shadow_scripts) == "string" and storage.shadow_scripts:len() > 3 then
    tk.storage["scriptsArea"] = storage.shadow_scripts
end

-- O storage desta custom e salvo por vocacao. Alem do saveConfig nativo,
-- gravamos explicitamente o arquivo da vocacao antes do reload.
local function saveIngameScripts()
    if type(saveConfig) == "function" then
      pcall(saveConfig)
    end
end

UI["Button"]("Ingame Scripts", function()
    UI["MultilineEditorWindow"](tk.storage["scriptsArea"] or "", {
        title = "Ingame Scripts",
        description = "Coloque seus scripts aqui."
    }, function(text)
        tk.storage["scriptsArea"] = text

        -- Precisa do saveConfig() ANTES do reload(): sem ele, o reload
        -- recarrega a storage do disco antes do texto novo ser gravado.
        saveIngameScripts()
        schedule(150, reload)
    end)
end)

UI.Separator()

-- Volta para a aba Main depois de criar o botao na aba Others.
setDefaultTab("Main")

-- Executa o script salvo (se houver) toda vez que a custom carrega/recarrega.
for _, scripts in pairs({tk.storage["scriptsArea"]}) do
    if type(scripts) == "string" and scripts:len() > 3 then
        schedule(5, function()
            local status, result = pcall(function()
                local call = {"setDefaultTab(\"Others\")", scripts}
                load(table["concat"](call, "\n"))()
            end)
            if not status then
                error("Ingame Scripts:\n" .. tostring(result))
            end
        end)
    end
end
