--[[
    Pawn integration for Ludwig. It shows Pawn values in LW list and sorts by them.
    Install:
        1. Ludwig and Pawn addons required.
        2. Copy pawn_integration.lua and pawn_integration.xml files to "WoW\Interface\AddOns\Ludwig" directory.
        3. Append line "pawn_integration.xml" (without quotes) to the end of "WoW\Interface\AddOns\Ludwig\Ludwig.toc"
           file using any text editor.
    Tested with Ludwig  1.6.0 and Pawn 1.1.2 for WoW 2.4.3.
    Author: Dawer
    Version: 0.2.0-beta
	Commands:
		/lw --pawn|Scale name
            Sorts by Pawn's scale values.
        /lw --pawn
            Disables sorting.
 ]]

local lwSlashHandler = SlashCmdList["LudwigSlashCOMMAND"]
local getItems = Ludwig.GetItems

local pawnTooltipAnnotation = "|cff8ec3e6(*)|r "
local pawnCache, underestimatedCache = {}, {}

local function LMsg(msg)
    ChatFrame1:AddMessage(format("|cFF00EE00Ludwig|r: %s", tostring(msg)))
end

--[[ Override functions ]]

SlashCmdList["LudwigSlashCOMMAND"] = function(msg)
    if msg and msg:lower():match("%-%-pawn") then
        if not PawnGetItemData then
            LMsg("Pawn is not available")
            return
        end

        local scale_name = msg:match("||(.*)")
        if scale_name then
            if not PawnOptions.Scales[scale_name] then
                Ludwig.pawnSort = false
                LMsg("Pawn scale not found: " .. scale_name)
            else
                Ludwig.pawnSort = true
                Ludwig.pawnScaleName = scale_name
                LMsg("Pawn sorting enabled (" .. scale_name .. ")")
            end
        else
            Ludwig.pawnSort = false
            LMsg("Pawn sorting disabled")
        end
        LudwigUI_UpdateList(true)
    else
        lwSlashHandler(msg)
    end
end

-- Add right justified label to items
do
    local function setID(button, id)
        if PawnGetItemData and Ludwig.pawnSort then
            local text = ''
            local pval = pawnCache[id]

            if pval then
                pval = string.format("%." .. PawnOptions.Digits .. "f", pval)
                text = pval or ''
            end

            if underestimatedCache[id] then
                text = pawnTooltipAnnotation .. text
            end
            button.RightText:SetText(text)
        else
            button.RightText:SetText('')
        end
    end

    local rtext
    for _, button in ipairs(LudwigFrame.items) do
        rtext = button:CreateFontString(button:GetName() .. 'RightText')
        rtext:SetPoint('RIGHT', -4, 0);
        rtext:SetJustifyH('RIGHT')
        rtext:SetFont(button:GetFont())
        button.RightText = rtext
        hooksecurefunc(button, 'SetID', setID)
    end
end

--[[
Checks the class allowed to use current item.
The current item is set to PawnPrivateTooltip after PawnGetItemData(...) call
even the item was in cache (cache miss bug in Pawn).
Suppose cache miss bug is not fixed.
Parameters:
    className: Class name in English.
]]
local function isAllowedForClass(className)
    local tooltip = PawnPrivateTooltip
    local leftLineText
    for i = 1, tooltip:NumLines() do
        leftLineText = getglobal('PawnPrivateTooltipTextLeft' .. i):GetText()
        if string.match(leftLineText, "^Classes:") then
            return string.match(leftLineText, className) ~= nil
        end
    end
    -- If not specified allow by default.
    return true
end

function Ludwig:GetItems(name, quality, typefilters, minLevel, maxLevel)
    -- disable sorting if no filter set
    if not (name or quality or (typefilters and next(typefilters) ~= nil) or minLevel or maxLevel) then
        Ludwig.pawnSort = false
    end

    local items = getItems(self, name, quality, typefilters, minLevel, maxLevel)

    if PawnGetItemData and Ludwig.pawnSort then
        -- cache Pawn values
        local itemData, pval
        local playerClass = UnitClass('player')
        pawnCache = {}
        underestimatedCache = {}
        for _, id in pairs(items) do
            itemData = PawnGetItemData(Ludwig:GetItemLink(id))
            pval = PawnGetSingleValueFromItem(itemData, Ludwig.pawnScaleName)
            if not isAllowedForClass(playerClass) then
                pval = nil
            end
            if pval then
                pawnCache[id] = pval
            end

            if itemData.UnknownLines then
                underestimatedCache[id] = itemData.UnknownLines
            end
        end

        table.sort(items, function(id1, id2)
            local pval1 = pawnCache[id1]
            local pval2 = pawnCache[id2]

            if pval1 == pval2 then
                return Ludwig.SortByEverything(id1, id2)
            end

            return (pval1 or 0) > (pval2 or 0)
        end)
    end

    return items
end

