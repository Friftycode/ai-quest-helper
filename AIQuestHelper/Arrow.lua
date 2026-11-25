local _, ns = ...

local ARROW = "Interface\\Minimap\\MinimapArrow"
local SCAN_EVERY = 2 -- seconds between searches for the nearest objective
local DRAW_EVERY = 0.05

local frame, target
local QDB, QLC, QEH, HBD, ZDB

local call = ns.call
local questIds, isDone, uiMap = ns.questIds, ns.isQuestDone, ns.uiMapOfArea

local function modules()
	local m = ns.questieModules()
	QDB, QLC, QEH, HBD, ZDB = m.db, m.logCache, m.events, m.hbd, m.zones
	return HBD and HBD.GetPlayerWorldPosition and QDB and QDB.GetQuest and ZDB
end

local function eachOpenObjective(quest, fn)
	for _, list in ipairs({ quest.Objectives or {}, quest.SpecialObjectives or {} }) do
		for _, o in pairs(list) do
			if type(o) == "table" and not o.Completed and type(o.spawnList) == "table" then fn(o) end
		end
	end
end

local function dbSpawns(id, add)
	local obj = call(QDB.QueryQuestSingle, id, "objectives")
	if type(obj) ~= "table" then return end
	local function npc(n, what) add(call(QDB.QueryNPCSingle, n, "spawns"), what) end
	local function object(n, what) add(call(QDB.QueryObjectSingle, n, "spawns"), what) end
	for _, o in ipairs(obj[1] or {}) do if o[1] then npc(o[1], o[2]) end end
	for _, o in ipairs(obj[2] or {}) do if o[1] then object(o[1], o[2]) end end
	for _, o in ipairs(obj[3] or {}) do
		local item = o[1]
		local name = item and (call(GetItemInfo, item) or o[2])
		for _, n in ipairs(item and call(QDB.QueryItemSingle, item, "npcDrops") or {}) do npc(n, name) end
		for _, n in ipairs(item and call(QDB.QueryItemSingle, item, "objectDrops") or {}) do object(n, name) end
	end
	for _, o in ipairs(obj[5] or {}) do
		for _, n in ipairs(type(o[1]) == "table" and o[1] or {}) do npc(n, o[3]) end
	end
	local te = call(QDB.QueryQuestSingle, id, "triggerEnd")
	if type(te) == "table" then add(te[2], te[1]) end
end

local last = {}

local function findNearest()
	local st = { questie = modules() and true or false, quests = 0, open = 0, spawns = 0, world = 0, sameMap = 0 }
	last = st
	if not st.questie then return nil end
	local px, py, inst = HBD:GetPlayerWorldPosition()
	local pMap = C_Map and call(C_Map.GetBestMapForUnit, "player")
	local pPos = pMap and call(C_Map.GetPlayerMapPosition, pMap, "player")
	local mx, my
	if pPos and pPos.GetXY then mx, my = pPos:GetXY() end
	st.player = px and string.format("%.0f, %.0f (instance %s)", px, py, tostring(inst)) or "no world position"
	st.map = pMap and string.format("%s %s", tostring(pMap), mx and string.format("%.1f, %.1f", mx * 100, my * 100) or "no position") or "no map"
	local best, bestD

	local function considerMap(m, sx, sy, questName, what)
		if not m or type(sx) ~= "number" or type(sy) ~= "number" or sx < 0 then return end
		local s = { sx, sy }
		local wx, wy, wi = HBD:GetWorldCoordinatesFromZone(s[1] / 100, s[2] / 100, m)
		local d
		if wx and px and wi == inst then
			st.world = st.world + 1
			d = (wx - px) ^ 2 + (wy - py) ^ 2
		elseif m == pMap and mx then
			st.sameMap = st.sameMap + 1
			d = ((s[1] / 100 - mx) ^ 2 + (s[2] / 100 - my) ^ 2) * 1e8
			wx = nil
		end
		if d and (not bestD or d < bestD) then
			bestD = d
			best = { x = wx, y = wy, instance = wi, map = m, mx = s[1] / 100, my = s[2] / 100,
				quest = questName, objective = what or "" }
		end
	end
	local function consider(area, s, questName, what)
		if type(s) ~= "table" or type(s[1]) ~= "number" or type(s[2]) ~= "number" or s[1] < 0 then return end
		st.spawns = st.spawns + 1
		considerMap(uiMap(area), s[1], s[2], questName, what)
	end
	local function addTable(spawns, questName, what)
		if type(spawns) ~= "table" then return end
		for area, list in pairs(spawns) do
			if type(list) == "table" then
				for _, s in ipairs(list) do consider(area, s, questName, what) end
			end
		end
	end

	for _, id in ipairs(questIds()) do
		st.quests = st.quests + 1
		if not isDone(id) then
			st.open = st.open + 1
			local quest = call(QDB.GetQuest, id)
			local name = (type(quest) == "table" and quest.name) or call(QDB.QueryQuestSingle, id, "name") or ("Quest " .. id)
			local before = st.spawns
			if type(quest) == "table" then
				eachOpenObjective(quest, function(o)
					for _, spawnData in pairs(o.spawnList) do
						if type(spawnData) == "table" then addTable(spawnData.Spawns, name, o.Description or spawnData.Name) end
					end
				end)
			end
			if st.spawns == before then
				dbSpawns(id, function(spawns, what) addTable(spawns, name, what) end)
			end
			for _, p in ipairs(ns.learnedPoints and call(ns.learnedPoints, id) or {}) do
				st.learned = (st.learned or 0) + 1
				considerMap(p[1], p[2], p[3], name, p[4])
			end
		end
	end
	return best
end

local function vector(t)
	local px, py, inst = HBD:GetPlayerWorldPosition()
	if t.x and px and inst == t.instance then
		return HBD:GetWorldVector(inst, px, py, t.x, t.y)
	end
	local pMap = C_Map and call(C_Map.GetBestMapForUnit, "player")
	if pMap ~= t.map then return nil end
	local pPos = call(C_Map.GetPlayerMapPosition, pMap, "player")
	if not (pPos and pPos.GetXY) then return nil end
	local mx, my = pPos:GetXY()
	local w, h = 1000, 1000
	local size = C_Map.GetMapWorldSize and { call(C_Map.GetMapWorldSize, pMap) }
	if size and size[1] and size[1] > 0 then w, h = size[1], size[2] end
	local east, south = (t.mx - mx) * w, (t.my - my) * h
	local dist = (east * east + south * south) ^ 0.5
	return math.atan2(-east, -south), (size and size[1]) and dist or nil
end

function ns.arrowDebug()
	local t = findNearest()
	target = t
	local s = last
	local lines = {
		"AI Quest Helper arrow:",
		string.format("  Questie found: %s (QuestieDB %s, ZoneDB %s, HBD %s)", tostring(s.questie),
			tostring(QDB ~= nil), tostring(ZDB ~= nil), tostring(HBD ~= nil)),
		string.format("  Quests in log: %d, unfinished: %d", s.quests or 0, s.open or 0),
		string.format("  Spawn points: %d, learned by you: %d, with world position: %d, on your map only: %d",
			s.spawns or 0, s.learned or 0, s.world or 0, s.sameMap or 0),
		"  You: " .. tostring(s.player) .. ", map " .. tostring(s.map),
		"  Target: " .. (t and (t.quest .. (t.objective ~= "" and (", " .. t.objective) or "")) or "none"),
	}
	for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage(l) end
end

local function savePosition(f)
	local point, _, rel, x, y = f:GetPoint(1)
	ns.db().arrow = { point = point, rel = rel, x = x, y = y }
end

local function build()
	local f = CreateFrame("Button", "AIQuestHelperArrow", UIParent)
	f:SetSize(56, 56)
	local p = ns.db().arrow
	if type(p) == "table" and p.point then
		f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
	else
		f:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not ns.opt("questArrowLock") then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition(self) end)

	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetTexture(ARROW)
	tex:SetSize(48, 48)
	tex:SetPoint("CENTER")
	f.tex = tex

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOP", f, "BOTTOM", 0, -2)
	title:SetWidth(220)
	f.title = title
	local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("TOP", title, "BOTTOM", 0, -1)
	sub:SetWidth(220)
	f.sub = sub

	f:SetScript("OnEnter", function(self)
		if not target then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(target.quest)
		if target.objective ~= "" then GameTooltip:AddLine(target.objective, 1, 1, 1, true) end
		GameTooltip:AddLine("Drag to move. Settings: lock the arrow.", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local sinceScan, sinceDraw = SCAN_EVERY, 0
	f:SetScript("OnUpdate", function(self, elapsed)
		sinceScan, sinceDraw = sinceScan + elapsed, sinceDraw + elapsed
		if sinceScan >= SCAN_EVERY then
			sinceScan = 0
			target = call(findNearest)
		end
		if sinceDraw < DRAW_EVERY then return end
		sinceDraw = 0
		local facing = call(GetPlayerFacing)
		local angle, dist
		if target and facing and HBD then angle, dist = call(vector, target) end
		if not angle then
			self.tex:SetAlpha(0)
			self.title:SetText(target and target.quest or "")
			self.sub:SetText(target and "" or "No unfinished quest nearby")
			return
		end
		self.tex:SetAlpha(1)
		self.tex:SetRotation(angle - facing)
		self.title:SetText(target.quest)
		local d = dist and string.format("%d yd", math.floor(dist + 0.5)) or ""
		self.sub:SetText((target.objective ~= "" and (target.objective .. "  ") or "") .. d)
	end)
	return f
end

function ns.refreshArrow()
	local on = ns.opt("questArrow")
	if on and not frame then frame = build() end
	if frame then frame:SetShown(on and true or false) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
	C_Timer.After(5, function() pcall(ns.refreshArrow) end)
end)
