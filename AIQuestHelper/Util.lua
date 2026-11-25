local _, ns = ...

ns.ICON = "Interface\\Icons\\INV_Misc_Note_02"
ns.PREFIX = "|cff66ccffAI Quest Helper:|r "

function ns.say(msg) print(ns.PREFIX .. msg) end

local function results(ok, ...)
	if ok then return ... end
	return nil
end

function ns.call(fn, ...)
	if type(fn) ~= "function" then return nil end
	return results(pcall(fn, ...))
end
local call = ns.call

function ns.shown(f) return f and f.IsShown and f:IsShown() end

function ns.clean(s)
	if type(s) ~= "string" or s == "" then return nil end
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	s = s:gsub("|H.-|h(.-)|h", "%1")
	s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	s = s:gsub("|n", "\n"):gsub("\r\n", "\n")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then return nil end
	return s
end
local clean = ns.clean

function ns.newDoc()
	local parts, doc = {}, {}
	function doc.add(text, header)
		text = clean(text)
		if not text then return end
		if header then text = header .. "\n" .. text end
		parts[#parts + 1] = text
	end
	function doc.result()
		if #parts == 0 then return nil end
		return table.concat(parts, "\n\n")
	end
	return doc
end

function ns.money(copper)
	copper = tonumber(copper) or 0
	if copper <= 0 then return nil end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

function ns.itemIDFromLink(link)
	return link and tonumber(link:match("item:(%d+)"))
end

function ns.itemLine(link, count, extra)
	if not link then return nil end
	local id = ns.itemIDFromLink(link) or "?"
	local name = link:match("%[(.-)%]") or "?"
	return string.format("%s | %s | %d%s", id, name, tonumber(count) or 1, extra or "")
end

-- GUID format: Creature-0-server-instance-zone-npcID-spawn
function ns.npcID(unit)
	local guid = call(UnitGUID, unit)
	if type(guid) ~= "string" then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
	return nil
end

function ns.zoneText()
	local zone, sub = clean(call(GetZoneText)), clean(call(GetSubZoneText))
	return (zone and sub and sub ~= zone) and (zone .. ", " .. sub) or zone or sub
end

function ns.npcHeader(...)
	for i = 1, select("#", ...) do
		local unit = select(i, ...)
		local name = clean(call(UnitName, unit))
		if name and not call(UnitIsPlayer, unit) then
			local id = ns.npcID(unit)
			local level = call(UnitLevel, unit)
			local where = ns.zoneText()
			local line = "NPC: " .. name .. (id and (" (ID " .. id .. ")") or "")
			if level and level > 0 then line = line .. ", level " .. level end
			if where then line = line .. "\nLocation: " .. where end
			return line
		end
	end
	return nil
end

function ns.playerMapPosition()
	local mapID = C_Map and call(C_Map.GetBestMapForUnit, "player")
	local p = mapID and call(C_Map.GetPlayerMapPosition, mapID, "player")
	if not (p and p.GetXY) then return mapID end
	local x, y = p:GetXY()
	if not x or (x == 0 and y == 0) then return mapID end
	return mapID, x, y
end

function ns.playerPoint()
	local mapID, x, y = ns.playerMapPosition()
	if not x then return nil end
	return { mapID, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10 }
end

function ns.mapName(mapID)
	local info = C_Map and call(C_Map.GetMapInfo, mapID)
	return type(info) == "table" and info.name or ("map " .. tostring(mapID))
end

function ns.pointList(points, max)
	local where = {}
	for k, p in ipairs(points or {}) do
		if k > (max or 12) then where[#where + 1] = "..." break end
		where[#where + 1] = string.format("%s %.1f, %.1f", ns.mapName(p[1]), p[2], p[3])
	end
	return where
end

function ns.plural(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end
