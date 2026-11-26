local _, ns = ...
local call = ns.call

local M = {}

local MODULES = {
	db = "QuestieDB", zones = "ZoneDB", logCache = "QuestLogCache", events = "QuestEventHandler", hbd = "HBD",
}

function ns.questieModules()
	if QuestieLoader and QuestieLoader.ImportModule then
		for key, name in pairs(MODULES) do
			if not M[key] then M[key] = call(QuestieLoader.ImportModule, QuestieLoader, name) end
		end
	end
	if not (M.hbd and M.hbd.GetPlayerWorldPosition) and LibStub then
		M.hbd = LibStub("HereBeDragons-2.0", true)
	end
	return M
end

function ns.questie()
	local db = ns.questieModules().db
	return type(db) == "table" and db.QueryQuestSingle and db or nil
end

-- Questie's list includes quests under collapsed headers; the game's log is the fallback.
function ns.questIds()
	local ids = {}
	local ev = ns.questieModules().events
	local states = ev and call(ev.GetQuestLogStates)
	if type(states) == "table" then
		for id in pairs(states) do ids[#ids + 1] = id end
		if #ids > 0 then return ids end
	end
	for i = 1, (call(GetNumQuestLogEntries) or 0) do
		local _, _, _, isHeader, _, _, _, id = call(GetQuestLogTitle, i)
		if not isHeader and id then ids[#ids + 1] = id end
	end
	return ids
end

-- Done when the game says so, when Questie's cache says so, or when every
-- objective in the quest log is finished. Questie's cache can lag behind.
function ns.isQuestDone(id)
	if C_QuestLog and call(C_QuestLog.IsComplete, id) == true then return true end
	local cache = ns.questieModules().logCache
	local c = cache and call(cache.TryGetQuest, id)
	if type(c) == "table" and (c.isComplete == 1 or c.isComplete == true) then return true end
	local objs = C_QuestLog and call(C_QuestLog.GetQuestObjectives, id)
	if type(objs) ~= "table" or #objs == 0 then return false end
	for _, o in ipairs(objs) do
		if type(o) ~= "table" or not o.finished then return false end
	end
	return true
end

local uiMapCache = {}
function ns.uiMapOfArea(area)
	local m = uiMapCache[area]
	if m == nil then
		local zones = ns.questieModules().zones
		m = (zones and call(zones.GetUiMapIdByAreaId, zones, area)) or false
		uiMapCache[area] = m
	end
	return m or nil
end

local function zoneName(area)
	local ui = ns.uiMapOfArea(area)
	local info = ui and C_Map and call(C_Map.GetMapInfo, ui)
	return (type(info) == "table" and info.name) or ("area " .. tostring(area))
end

local function playerArea()
	local mapID, x, y = ns.playerMapPosition()
	local zones = ns.questieModules().zones
	local area = mapID and zones and call(zones.GetAreaIdByUiMapId, zones, mapID)
	return area, x and x * 100, y and y * 100
end

-- Spawn tables are { [areaId] = { {x, y}, ... } }. The player's zone wins if it
-- has spawns, otherwise the zone with the most spawns.
local function pickZone(spawns)
	if type(spawns) ~= "table" then return nil end
	local area, px, py = playerArea()
	local best, bestN = nil, 0
	for zone, list in pairs(spawns) do
		if type(list) == "table" and #list > bestN then best, bestN = zone, #list end
	end
	if not best then return nil end
	local here = area and type(spawns[area]) == "table" and #spawns[area] > 0
	return here and area or best, here, px, py
end

local function spawnText(spawns)
	local zone, here, px, py = pickZone(spawns)
	if not zone then return nil end
	local cx, cy, n, nx, ny, nd = 0, 0, 0
	for _, c in ipairs(spawns[zone]) do
		local x, y = c[1], c[2]
		if type(x) == "number" and type(y) == "number" and x >= 0 then
			cx, cy, n = cx + x, cy + y, n + 1
			if px then
				local d = (x - px) ^ 2 + (y - py) ^ 2
				if not nd or d < nd then nx, ny, nd = x, y, d end
			end
		end
	end
	if n == 0 then return zoneName(zone) .. " (no coordinates)" end
	local out = string.format("%s, around %.1f, %.1f (%s)", zoneName(zone), cx / n, cy / n, ns.plural(n, "spawn"))
	if here and nx then out = out .. string.format(", nearest to you %.1f, %.1f", nx, ny) end
	return out
end
ns.spawnText = spawnText

-- Returns uiMapID, zone name, x, y of the nearest spawn and whether it is in the player's zone.
function ns.bestSpawn(spawns)
	local zone, here, px, py = pickZone(spawns)
	if not zone then return nil end
	local bx, by, bd
	for _, c in ipairs(spawns[zone]) do
		local x, y = c[1], c[2]
		if type(x) == "number" and type(y) == "number" and x >= 0 then
			local d = px and ((x - px) ^ 2 + (y - py) ^ 2) or 0
			if not bd or d < bd then bx, by, bd = x, y, d end
		end
	end
	return ns.uiMapOfArea(zone), zoneName(zone), bx, by, here and true or false
end

local function npcLine(id)
	local db = ns.questie()
	local name = db and call(db.QueryNPCSingle, id, "name")
	if not name then return nil end
	local sub = call(db.QueryNPCSingle, id, "subName")
	local lvl1, lvl2 = call(db.QueryNPCSingle, id, "minLevel"), call(db.QueryNPCSingle, id, "maxLevel")
	local lvl = lvl1 and ((lvl2 and lvl2 ~= lvl1) and (lvl1 .. "-" .. lvl2) or tostring(lvl1)) or nil
	local where = spawnText(call(db.QueryNPCSingle, id, "spawns"))
	return string.format("NPC %s (ID %d%s%s)%s", name, id, sub and (", <" .. sub .. ">") or "",
		lvl and (", level " .. lvl) or "", where and (": " .. where) or "")
end

local function objectLine(id)
	local db = ns.questie()
	local name = db and call(db.QueryObjectSingle, id, "name")
	if not name then return nil end
	local where = spawnText(call(db.QueryObjectSingle, id, "spawns"))
	return string.format("Object %s (ID %d)%s", name, id, where and (": " .. where) or "")
end

local function addIds(out, ids, fn, max)
	if type(ids) ~= "table" then return end
	local n = 0
	for _, id in ipairs(ids) do
		if n >= (max or 4) then out[#out + 1] = "    - (more sources not listed)" break end
		local l = fn(id)
		if l then out[#out + 1] = "    - " .. l n = n + 1 end
	end
end

local function prefixed(prefix, fn)
	return function(id)
		local l = fn(id)
		return l and (prefix .. l)
	end
end

local function itemSources(itemID, out)
	local db = ns.questie()
	if not db then return end
	local before = #out
	addIds(out, call(db.QueryItemSingle, itemID, "npcDrops"), prefixed("dropped by ", npcLine), 4)
	addIds(out, call(db.QueryItemSingle, itemID, "objectDrops"), prefixed("looted from ", objectLine), 3)
	addIds(out, call(db.QueryItemSingle, itemID, "vendors"), prefixed("sold by ", npcLine), 2)
	if #out == before then out[#out + 1] = "    - (no source in Questie data)" end
end

local function logItemNames(questID)
	local names = {}
	local objs = C_QuestLog and C_QuestLog.GetQuestObjectives and call(C_QuestLog.GetQuestObjectives, questID)
	for _, o in ipairs(type(objs) == "table" and objs or {}) do
		if type(o) == "table" and o.type == "item" and o.text then
			names[#names + 1] = (o.text:gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub(":%s*%d+%s*/%s*%d+%s*$", ""))
		end
	end
	return names
end

local function questName(db, id)
	return (call(db.QueryQuestSingle, id, "name") or "?") .. " (" .. id .. ")"
end

-- Returns the Questie text block and the set of itemIDs that belong to the quest.
function ns.questieBlock(questID)
	local db = ns.questie()
	if not db or not questID then return nil, {} end
	local related = {}
	local lines = { "## Quest data (from Questie database)" }

	local function startEnd(label, data)
		if type(data) ~= "table" then return end
		local out = {}
		addIds(out, data[1], npcLine, 3)
		addIds(out, data[2], objectLine, 2)
		for _, id in ipairs(type(data[3]) == "table" and data[3] or {}) do
			related[id] = true
			out[#out + 1] = "    - Item " .. (call(GetItemInfo, id) or "?") .. " (ID " .. id .. ")"
		end
		if #out > 0 then
			lines[#lines + 1] = "- " .. label .. ":"
			for _, l in ipairs(out) do lines[#lines + 1] = l end
		end
	end
	startEnd("Quest giver", call(db.QueryQuestSingle, questID, "startedBy"))
	startEnd("Turn in to", call(db.QueryQuestSingle, questID, "finishedBy"))

	local obj = call(db.QueryQuestSingle, questID, "objectives")
	if type(obj) == "table" then
		local out = {}
		local function note(o) return o and (" (" .. o .. ")") or "" end
		for _, o in ipairs(obj[1] or {}) do
			local l = npcLine(o[1])
			if l then out[#out + 1] = "- Kill/interact" .. note(o[2]) .. ": " .. l end
		end
		for _, o in ipairs(obj[2] or {}) do
			local l = objectLine(o[1])
			if l then out[#out + 1] = "- Use" .. note(o[2]) .. ": " .. l end
		end
		local logNames = logItemNames(questID)
		for k, o in ipairs(obj[3] or {}) do
			local id = o[1]
			related[id] = true
			local name = call(GetItemInfo, id) or o[2] or logNames[k] or "?"
			out[#out + 1] = "- Collect " .. name .. " (itemID " .. id .. "), sources:"
			itemSources(id, out)
			for _, l in ipairs(ns.learnedLines and ns.learnedLines(id, "    ") or {}) do out[#out + 1] = l end
		end
		for _, o in ipairs(obj[5] or {}) do
			local l = o[2] and npcLine(o[2])
			out[#out + 1] = "- Kill credit" .. note(o[3]) .. (l and (": " .. l) or "")
		end
		if #out > 0 then
			lines[#lines + 1] = "### Where to do the objectives"
			for _, l in ipairs(out) do lines[#lines + 1] = l end
		end
	end

	local te = call(db.QueryQuestSingle, questID, "triggerEnd")
	if type(te) == "table" and te[1] then
		local spot = spawnText(te[2])
		lines[#lines + 1] = "- Explore: " .. te[1] .. (spot and (" at " .. spot) or "")
	end
	local src = call(db.QueryQuestSingle, questID, "sourceItemId")
	if type(src) == "number" and src > 0 then related[src] = true end
	for _, id in ipairs(call(db.QueryQuestSingle, questID, "requiredSourceItems") or {}) do related[id] = true end

	local pre = call(db.QueryQuestSingle, questID, "preQuestSingle") or call(db.QueryQuestSingle, questID, "preQuestGroup")
	if type(pre) == "table" and #pre > 0 then
		local t = {}
		for _, id in ipairs(pre) do t[#t + 1] = questName(db, id) end
		lines[#lines + 1] = "- Previous quest: " .. table.concat(t, ", ")
	end
	local nxt = call(db.QueryQuestSingle, questID, "nextQuestInChain")
	if type(nxt) == "number" and nxt > 0 then
		lines[#lines + 1] = "- Next quest in chain: " .. questName(db, nxt)
	end
	if #lines == 1 then return nil, related end
	return table.concat(lines, "\n"), related
end

local function turnInFrom(name, spawns)
	local ui, zone, x, y, here = ns.bestSpawn(spawns)
	return { who = name, zone = zone, map = ui, x = x, y = y, here = here }
end

function ns.turnInOf(questID)
	local db = ns.questie()
	local fin = db and call(db.QueryQuestSingle, questID, "finishedBy")
	if type(fin) == "table" then
		for _, id in ipairs(fin[1] or {}) do
			local name = call(db.QueryNPCSingle, id, "name")
			if name then return turnInFrom(name, call(db.QueryNPCSingle, id, "spawns")) end
		end
		for _, id in ipairs(fin[2] or {}) do
			local name = call(db.QueryObjectSingle, id, "name")
			if name then return turnInFrom(name, call(db.QueryObjectSingle, id, "spawns")) end
		end
	end
	-- Forever quests unknown to Questie: Forever Dungeon Journal's notes.
	local F = _G.ForeverDungeonJournal_NS
	local d = F and type(F.QUEST_PREREQ_DETAILS) == "table" and F.QUEST_PREREQ_DETAILS[questID]
	if type(d) == "table" and type(d.turnin) == "string" then
		local m = type(d.turninMap) == "table" and d.turninMap or nil
		local here = m and C_Map and m.mapID == call(C_Map.GetBestMapForUnit, "player")
		return { who = d.turnin, map = m and m.mapID, x = m and m.x and m.x * 100, y = m and m.y and m.y * 100, here = here, text = true }
	end
end
