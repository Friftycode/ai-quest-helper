local _, ns = ...
local call, clean, opt = ns.call, ns.clean, ns.opt

-- Own observations that fill Questie's gaps (Forever zones):
--   db.learned[itemID][sourceKey] = { kind, id, name, item, points = { {map, x, y} }, n }
--   db.kills[mobName]             = { id, points = { {map, x, y} }, n }
local MAX_POINTS = 40
local TIP_TTL = 15
local WANTED_TTL = 10

local lastWorldTip, lastWorldTipTime
local recentlyLearned = {}
local wanted, wantedTime = {}, -100

local function learned() return ns.db().learned end
local function kills() return ns.db().kills end

local function recentTip()
	if lastWorldTip and GetTime() - (lastWorldTipTime or 0) < TIP_TTL then return lastWorldTip end
end

local function addPoint(e, pt)
	if not pt then return end
	for _, q in ipairs(e.points) do
		if q[1] == pt[1] and math.abs(q[2] - pt[2]) < 0.7 and math.abs(q[3] - pt[3]) < 0.7 then return end
	end
	if #e.points < MAX_POINTS then e.points[#e.points + 1] = pt end
end

local function questItemSet()
	if GetTime() - wantedTime < WANTED_TTL then return wanted end
	wantedTime, wanted = GetTime(), {}
	local qdb = ns.questie()
	if not qdb then return wanted end
	for _, qid in ipairs(ns.questIds()) do
		local obj = call(qdb.QueryQuestSingle, qid, "objectives")
		for _, o in ipairs(type(obj) == "table" and obj[3] or {}) do wanted[o[1]] = qid end
	end
	return wanted
end

local function isQuestItem(itemID)
	if questItemSet()[itemID] then return true end
	return select(6, call(GetItemInfoInstant, itemID)) == 12
end

local function remember(itemID, kind, id, name)
	if not itemID then return end
	local L = learned()
	L[itemID] = L[itemID] or {}
	local key = kind .. ":" .. tostring(id or name or "?")
	local e = L[itemID][key]
	if not e then
		e = { kind = kind, id = id, name = name, points = {}, n = 0 }
		L[itemID][key] = e
	end
	e.name = e.name or name
	e.n = (e.n or 0) + 1
	e.item = e.item or call(GetItemInfo, itemID)
	addPoint(e, ns.playerPoint())
	recentlyLearned[itemID] = GetTime()
end

local function lootSource(slot)
	local guid = call(GetLootSourceInfo, slot)
	if issecretvalue and guid ~= nil and issecretvalue(guid) then guid = nil end
	if type(guid) ~= "string" then
		local tip = recentTip()
		return tip and "object" or "unknown", nil, tip
	end
	local t, _, _, _, _, gid = strsplit("-", guid)
	gid = tonumber(gid)
	local qdb = ns.questie()
	if t == "Creature" or t == "Vehicle" then
		local name = call(UnitGUID, "target") == guid and call(UnitName, "target") or nil
		return "npc", gid, name or (qdb and call(qdb.QueryNPCSingle, gid, "name"))
	elseif t == "GameObject" then
		return "object", gid, (qdb and call(qdb.QueryObjectSingle, gid, "name")) or recentTip()
	elseif t == "Item" then
		return "container"
	end
	return "unknown"
end

local function onLootOpened()
	if not opt("learnItems") then return end
	for slot = 1, (call(GetNumLootItems) or 0) do
		local itemID = ns.itemIDFromLink(call(GetLootSlotLink, slot))
		if itemID and isQuestItem(itemID) then
			remember(itemID, lootSource(slot))
		end
	end
end

-- Items that arrive without a loot window (clicked objects, quest scripts).
local function onChatLoot(msg)
	if not opt("learnItems") then return end
	if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
	if not (msg:find("^You receive") or msg:find("^Du mottar")) then return end
	local itemID = tonumber(msg:match("item:(%d+)"))
	if not itemID or not isQuestItem(itemID) then return end
	if recentlyLearned[itemID] and GetTime() - recentlyLearned[itemID] < 3 then return end
	remember(itemID, "pickup", nil, recentTip())
end

local function onInfoMessage(a1, a2)
	if not opt("learnItems") then return end
	local msg = type(a2) == "string" and a2 or a1
	if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
	local mob = msg:match("^(.-) slain: %d+/%d+$") or msg:match("^(.-) drept: %d+/%d+$")
	if not mob or mob == "" then return end
	local K = kills()
	local e = K[mob] or { points = {}, n = 0 }
	K[mob] = e
	if call(UnitName, "target") == mob and call(UnitIsDead, "target") then e.id = e.id or ns.npcID("target") end
	e.n = (e.n or 0) + 1
	addPoint(e, ns.playerPoint())
end

-- Learned points for a quest's unfinished objectives, matched on the objective text.
function ns.learnedPoints(questID)
	local out = {}
	local objs = C_QuestLog and call(C_QuestLog.GetQuestObjectives, questID)
	if type(objs) ~= "table" then return out end
	local L, K = learned(), kills()
	local function addAll(points, text)
		for _, p in ipairs(points or {}) do out[#out + 1] = { p[1], p[2], p[3], text } end
	end
	for _, o in ipairs(objs) do
		if type(o) == "table" and not o.finished and type(o.text) == "string" then
			local t = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
			local mob = t:match("^(.-) slain") or t:match("^(.-) drept")
			local name = mob or t:match("^(.-):%s*%d+%s*/%s*%d+") or t
			if mob and K[mob] then addAll(K[mob].points, o.text) end
			for itemID, sources in pairs(L) do
				local item = call(GetItemInfo, itemID)
				for _, e in pairs(sources) do
					if (item or e.item) == name then addAll(e.points, o.text) end
				end
			end
		end
	end
	return out
end

local HOW = {
	npc = "dropped by NPC", object = "looted from object", container = "from a container item",
	pickup = "picked up", unknown = "looted from",
}

function ns.learnedLines(itemID, indent)
	local L = learned()[itemID]
	if type(L) ~= "table" then return {} end
	local out = {}
	for _, e in pairs(L) do
		local where = ns.pointList(e.points)
		out[#out + 1] = string.format("%s- learned by you: %s %s%s, %d time%s%s", indent or "", HOW[e.kind] or "from",
			e.name or "unknown", e.id and (" (ID " .. e.id .. ")") or "", e.n or 1, (e.n or 1) == 1 and "" or "s",
			#where > 0 and (" at " .. table.concat(where, "; ")) or "")
	end
	return out
end

function ns.fromLearned()
	local L, K = learned(), kills()
	local lines = { ns.aiHeader("learned quest item sources"), "",
		"Where this player has looted quest items in WoW Forever (own observations, not from any database).",
		"Format: itemID name, then each source with location (zone x, y)." }
	local n = 0
	for itemID, sources in pairs(L) do
		n = n + 1
		local name = call(GetItemInfo, itemID)
		for _, e in pairs(sources) do name = name or e.item break end
		lines[#lines + 1] = "\n" .. itemID .. " " .. (name or "?")
		for _, l in ipairs(ns.learnedLines(itemID, "  ")) do lines[#lines + 1] = l end
	end
	local first = true
	for mob, e in pairs(K) do
		if first then lines[#lines + 1] = "\nQuest kills (where this player killed mobs for kill objectives):" first = false end
		n = n + 1
		local where = ns.pointList(e.points)
		lines[#lines + 1] = string.format("- %s%s, %d kill%s%s", mob, e.id and (" (ID " .. e.id .. ")") or "",
			e.n or 1, (e.n or 1) == 1 and "" or "s", #where > 0 and (" at " .. table.concat(where, "; ")) or "")
	end
	if n == 0 then return nil end
	return table.concat(lines, "\n")
end

if GameTooltip and GameTooltip.HookScript then
	GameTooltip:HookScript("OnShow", function(tt)
		if tt.GetUnit and tt:GetUnit() then return end
		if tt.GetItem and tt:GetItem() then return end
		local owner = tt.GetOwner and tt:GetOwner()
		if owner and owner ~= UIParent and owner ~= WorldFrame then return end
		local line = _G["GameTooltipTextLeft1"]
		local text = line and clean(line:GetText())
		if text then lastWorldTip, lastWorldTipTime = text, GetTime() end
	end)
end

local HANDLERS = {
	LOOT_OPENED = onLootOpened,
	CHAT_MSG_LOOT = onChatLoot,
	UI_INFO_MESSAGE = onInfoMessage,
}

local events = CreateFrame("Frame")
for event in pairs(HANDLERS) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, ...) pcall(HANDLERS[event], ...) end)
