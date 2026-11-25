local _, ns = ...
local call = ns.call

local SLOTS = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
	"Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" }
local COSMETIC = { [4] = true, [19] = true }

local scanTip

local function tooltipLines(slot)
	local out = {}
	if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
		local data = call(C_TooltipInfo.GetInventoryItem, "player", slot)
		for _, l in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
			if type(l) == "table" and type(l.leftText) == "string" then out[#out + 1] = l.leftText end
		end
		if #out > 0 then return out end
	end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "AIQuestHelperScanTip", UIParent, "GameTooltipTemplate")
	end
	scanTip:ClearLines()
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	call(scanTip.SetInventoryItem, scanTip, "player", slot)
	for i = 1, scanTip:NumLines() do
		local fs = _G["AIQuestHelperScanTipTextLeft" .. i]
		local t = fs and fs:GetText()
		if t then out[#out + 1] = t end
	end
	return out
end

local function statText(link)
	local get = (C_Item and C_Item.GetItemStats) or GetItemStats
	local st = get and call(get, link)
	if type(st) ~= "table" then return nil end
	local parts = {}
	for k, v in pairs(st) do
		local label = _G[k]
		if type(label) == "string" and type(v) == "number" and not k:find("^EMPTY_SOCKET") then
			parts[#parts + 1] = string.format("%+d %s", v, label)
		end
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, ", ") or nil
end

local function isExtraLine(t)
	return t:find("^Equip:") or t:find("^Use:") or t:find("^Chance on hit:") or t:find("^%(%d%) Set:") or t:find("^Set:")
end

local function enchantOf(t)
	return t:match("^Enchanted: (.+)")
		or (ENCHANTED_TOOLTIP_LINE and t:match("^" .. ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)")))
end

local function gearRow(slot, link)
	local id = ns.itemIDFromLink(link)
	local name = link:match("%[(.-)%]") or "?"
	local ilvl = (GetDetailedItemLevelInfo and call(GetDetailedItemLevelInfo, link)) or select(4, call(GetItemInfo, link))
	local istr = { strsplit(":", link:match("item:([^|]+)") or "") }
	local enchID = tonumber(istr[2] or "")
	local gems = {}
	for g = 3, 6 do
		local gid = tonumber(istr[g] or "")
		if gid and gid > 0 then gems[#gems + 1] = gid end
	end
	local enchant, extra = nil, {}
	for _, t in ipairs(tooltipLines(slot)) do
		local e = enchantOf(t)
		if e then enchant = e elseif isExtraLine(t) then extra[#extra + 1] = t end
	end
	local hasEnchID = enchID and enchID > 0
	local cur, max = call(GetInventoryItemDurability, slot)
	local row = {
		SLOTS[slot], tostring(id or "?"), name, ilvl and ("ilvl " .. ilvl) or "ilvl ?",
		statText(link) or "-",
		enchant and ("enchant: " .. enchant .. (hasEnchID and (" (ID " .. enchID .. ")") or ""))
			or (hasEnchID and ("enchant ID " .. enchID)) or "no enchant",
		#gems > 0 and ("gems: " .. table.concat(gems, ", ")) or "-",
		#extra > 0 and table.concat(extra, " / ") or "-",
		(cur and max) and (cur .. "/" .. max) or "-",
	}
	return table.concat(row, " | "), ilvl
end

function ns.fromGear()
	local lines = {
		string.format("Equipped gear for %s (level %s %s)", UnitName("player") or "?", UnitLevel("player") or "?",
			(UnitClass("player")) or "?"),
		"Format: slot | itemID | name | item level | stats | enchant | gems | Equip/Use/set lines | durability",
	}
	local sum, n = 0, 0
	for slot = 1, 19 do
		local link = call(GetInventoryItemLink, "player", slot)
		if link then
			local row, ilvl = gearRow(slot, link)
			lines[#lines + 1] = row
			if ilvl and not COSMETIC[slot] then sum, n = sum + ilvl, n + 1 end
		elseif not COSMETIC[slot] then
			lines[#lines + 1] = SLOTS[slot] .. " | (empty)"
		end
	end
	if n > 0 then lines[#lines + 1] = string.format("Average item level: %.1f (%d items)", sum / n, n) end
	return table.concat(lines, "\n")
end
