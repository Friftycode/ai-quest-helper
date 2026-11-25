-- Zone and instance data adapted from Extended Map Info (Goose__).
local _, ns = ...
local D = AIQuestHelperData or {}

local opt = ns.opt

local MAPTYPE = Enum and Enum.UIMapType or {}
local T_CONT, T_ZONE, T_MICRO = MAPTYPE.Continent or 2, MAPTYPE.Zone or 3, MAPTYPE.Micro or 4

local function color(lo, hi, instance)
	if not opt("mapColors") then return 0.85, 0.85, 0.85 end
	local p = UnitLevel("player") or 1
	if lo > p then
		local d = lo - p
		if instance or d >= 5 then return 1, 0.25, 0.25 end
		if d >= 3 then return 1, 0.55, 0.15 end
		return 1, 0.9, 0.2
	end
	if p - hi >= 5 then return 0.6, 0.6, 0.6 end
	return 0.35, 0.9, 0.35
end
local function hex(r, g, b) return string.format("%02x%02x%02x", r * 255, g * 255, b * 255) end
local function range(lo, hi) return lo == hi and tostring(lo) or (lo .. "-" .. hi) end

local canvas, layer, zoneLine
local labels, pins = {}, {}

local function mapInfo(id)
	local ok, info = pcall(C_Map.GetMapInfo, id)
	return ok and info or nil
end

local function translate(fromMap, x, y, toMap)
	if fromMap == toMap then return x, y end
	if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
	local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, fromMap, CreateVector2D(x, y))
	if not ok or not world then return nil end
	local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, world, toMap)
	if not ok2 or not pos or pos.x < 0 or pos.x > 1 or pos.y < 0 or pos.y > 1 then return nil end
	return pos.x, pos.y
end

local function label(i)
	local l = labels[i]
	if not l then
		l = layer:CreateFontString(nil, "OVERLAY")
		l:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
		l:SetShadowOffset(0, 0)
		labels[i] = l
	end
	return l
end

local function showPinTip(pin)
	local d = pin.data
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	local r, g, b = color(d.minLevel, d.maxLevel, true)
	GameTooltip:AddDoubleLine(d.name, range(d.minLevel, d.maxLevel), 1, 0.82, 0, r, g, b)
	local kind = d.type == "raid" and "Raid" or "Dungeon"
	local bits = { kind, (d.players or "?") .. " players" }
	if d.bosses then bits[#bits + 1] = d.bosses .. " bosses" end
	if d.duration then bits[#bits + 1] = d.duration end
	GameTooltip:AddLine(table.concat(bits, "  ·  "), 0.75, 0.75, 0.75)
	if d.faction and d.faction ~= "Both" and d.faction ~= "Neutral" then
		local mine = d.faction == UnitFactionGroup("player")
		GameTooltip:AddLine(d.faction .. " only", mine and 0.75 or 1, mine and 0.75 or 0.35, mine and 0.75 or 0.35)
	end
	if d.prereq then GameTooltip:AddLine("Needs: " .. d.prereq, 1, 0.75, 0.4) end
	if d.desc and d.desc ~= "" then GameTooltip:AddLine(d.desc, 0.9, 0.9, 0.9, true) end
	if d.approx then GameTooltip:AddLine("Approximate position", 1, 0.4, 0.4) end
	GameTooltip:Show()
end

local function pin(i, d)
	local p = pins[i]
	if not p then
		p = CreateFrame("Button", nil, layer)
		p.tex = p:CreateTexture(nil, "OVERLAY")
		p.tex:SetAllPoints()
		p:SetScript("OnEnter", showPinTip)
		p:SetScript("OnLeave", function() GameTooltip:Hide() end)
		pins[i] = p
	end
	p.data = d
	p.tex:SetTexture(d.type == "raid" and "Interface\\MINIMAP\\Raid" or "Interface\\MINIMAP\\Dungeon")
	if not p.ring then
		p.ring = p:CreateTexture(nil, "BACKGROUND")
		p.ring:SetTexture("Interface\\Cooldown\\star4")
		p.ring:SetBlendMode("ADD")
		p.ring:SetPoint("CENTER")
		p.ring:SetVertexColor(1, 0.85, 0.2)
	end
	p.ring:SetShown(ns.focusInstance == d)
	return p
end

local function hideAll()
	for _, l in ipairs(labels) do l:Hide() end
	for _, p in ipairs(pins) do p:Hide() end
	if zoneLine then zoneLine:Hide() end
end

local function update()
	if not layer then return end
	hideAll()
	if not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
	local mapID = WorldMapFrame:GetMapID()
	local info = mapID and mapInfo(mapID)
	if not info then return end
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	if not w or w == 0 then return end
	local isCont = info.mapType == T_CONT
	local isZone = info.mapType == T_ZONE or info.mapType == T_MICRO

	if opt("mapZoneLevels") and D.Zones then
		if isCont then
			local n = 0
			for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, T_ZONE) or {}) do
				local rg = D.Zones[child.mapID]
				if rg then
					local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, child.mapID, mapID)
					if ok and l then
						n = n + 1
						local fs = label(n)
						fs:SetTextColor(color(rg[1], rg[2]))
						fs:SetText(range(rg[1], rg[2]))
						fs:ClearAllPoints()
						fs:SetPoint("CENTER", canvas, "TOPLEFT", (l + r) / 2 * w, -((t + b) / 2) * h + 12)
						fs:Show()
					end
				end
			end
		elseif isZone then
			local rg = D.Zones[mapID] or (info.parentMapID and D.Zones[info.parentMapID])
			if rg and zoneLine then
				local r, g, b = color(rg[1], rg[2])
				zoneLine:SetText(string.format("%s  |cff%s%s|r", info.name, hex(r, g, b), range(rg[1], rg[2])))
				zoneLine:Show()
			end
		end
	end

	if (opt("mapDungeons") or opt("mapRaids")) and D.Instances and (isCont or isZone) then
		local cs = canvas:GetEffectiveScale() / (UIParent:GetEffectiveScale() or 1)
		if not cs or cs <= 0 then cs = 1 end
		local size = 24 * (opt("mapPinScale") or 1) / cs
		local n = 0
		for _, d in ipairs(D.Instances) do
			local want = (d.type == "raid" and opt("mapRaids")) or (d.type ~= "raid" and opt("mapDungeons"))
			local here = isCont and d.continentID == mapID or isZone and (d.map == mapID or d.parent == mapID)
			if want and not d.ignore and here and d.map and d.x then
				local x, y = translate(d.map, d.x, d.y, mapID)
				if x then
					n = n + 1
					local p = pin(n, d)
					p:SetSize(size, size)
					p.ring:SetSize(size * 2.6, size * 2.6)
					p:ClearAllPoints()
					p:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
					p:Show()
				end
			end
		end
	end
end
local lastErr, lastPins = nil, 0
local rawUpdate = update
update = function()
	if ns.refreshSearch then ns.refreshSearch() end
	local ok, err = pcall(rawUpdate)
	if not ok and err ~= lastErr then
		lastErr = err
	end
end
ns.refreshMap = update

function ns.mapDebug()
	local id = WorldMapFrame and WorldMapFrame:GetMapID()
	local info = id and mapInfo(id)
	local shown = 0
	for _, p in ipairs(pins) do if p:IsShown() then shown = shown + 1 end end
	local here = 0
	for _, d in ipairs(D.Instances or {}) do
		if d.map == id or d.parent == id or d.continentID == id then here = here + 1 end
	end
	print(string.format("|cff66ccffAI Quest Helper:|r map %s (%s, type %s) layer=%s canvas=%sx%s instances=%d here=%d pins shown=%d dungeons=%s raids=%s error=%s",
		tostring(id), info and info.name or "?", info and tostring(info.mapType) or "?",
		tostring(layer ~= nil), canvas and math.floor(canvas:GetWidth()) or "?", canvas and math.floor(canvas:GetHeight()) or "?",
		#(D.Instances or {}), here, shown, tostring(opt("mapDungeons")), tostring(opt("mapRaids")), tostring(lastErr)))
end

local function setup()
	if layer or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
	canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas() or WorldMapFrame.ScrollContainer
	layer = CreateFrame("Frame", nil, canvas)
	layer:SetAllPoints(canvas)
	layer:SetFrameStrata("HIGH")
	layer:SetFrameLevel(canvas:GetFrameLevel() + 40)

	local top = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
	top:SetAllPoints(WorldMapFrame.ScrollContainer)
	top:SetFrameStrata("HIGH")
	zoneLine = top:CreateFontString(nil, "OVERLAY")
	zoneLine:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	zoneLine:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer, "TOPLEFT", 10, -8)
	zoneLine:SetTextColor(1, 0.82, 0)

	if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() update() end) end
	WorldMapFrame:HookScript("OnShow", function() update() end)
	canvas:HookScript("OnSizeChanged", function() update() end)
	if WorldMapFrame.ScrollContainer.SetZoomTarget then hooksecurefunc(WorldMapFrame.ScrollContainer, "SetZoomTarget", function() C_Timer.After(0.3, update) end) end
	update()
end

local search, list, rows = nil, nil, {}
local MAXROWS, ROWH = 8, 30

local function norm(t) return (t or ""):lower():gsub("[^%w ]", "") end

local function matches(q)
	local out = {}
	q = norm(q)
	for _, d in ipairs(D.Instances or {}) do
		if not d.ignore and d.map and d.x then
			local hay = norm(d.name .. " " .. (d.shortName or "") .. " " .. (d.zone or ""))
			if q == "" or hay:find(q, 1, true) then out[#out + 1] = d end
		end
	end
	table.sort(out, function(a, b)
		if (a.minLevel or 0) ~= (b.minLevel or 0) then return (a.minLevel or 0) < (b.minLevel or 0) end
		return a.name < b.name
	end)
	return out
end

local function go(d)
	ns.focusInstance = d
	if search then search:ClearFocus() end
	if list then list:Hide() end
	WorldMapFrame:SetMapID(d.map)
	C_Timer.After(0.05, update)
	C_Timer.After(6, function() if ns.focusInstance == d then ns.focusInstance = nil; update() end end)
end

local function fill()
	local res = matches(search:GetText())
	local n = math.min(#res, MAXROWS)
	for i = 1, MAXROWS do
		local r = rows[i]
		if i <= n then
			local d = res[i]
			local cr, cg, cb = color(d.minLevel, d.maxLevel, true)
			r.data = d
			r.left:SetText(d.name)
			r.right:SetText(string.format("|cff%s%s|r  |cff999999%s%s|r", hex(cr, cg, cb), range(d.minLevel, d.maxLevel), d.zone or "", d.type == "raid" and "  ·  Raid" or ""))
			r:Show()
		else
			r:Hide()
		end
	end
	list:SetHeight(n * ROWH + 8)
	local typed = (search:GetText() or ""):gsub("%s", "") ~= ""
	list:SetShown(typed and n > 0 and search:HasFocus())
	list.first = res[1]
end

local function setupSearch()
	if search or not WorldMapFrame.ScrollContainer then return end
	local holder = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
	holder:SetAllPoints(WorldMapFrame.ScrollContainer)
	holder:SetFrameStrata("DIALOG")

	local ok, box = pcall(CreateFrame, "EditBox", "AIQuestHelperMapSearch", holder, "SearchBoxTemplate")
	if not ok then box = CreateFrame("EditBox", "AIQuestHelperMapSearch", holder, "InputBoxTemplate") end
	search = box
	search:SetSize(170, 20)
	search:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -12, -8)
	search:SetAutoFocus(false)
	if search.Instructions then search.Instructions:SetText("Find dungeon/raid") end

	list = CreateFrame("Frame", nil, holder, BackdropTemplateMixin and "BackdropTemplate" or nil)
	list:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 4, -2)
	list:SetWidth(280)
	if list.SetBackdrop then
		list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		list:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
		list:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
	end
	list:Hide()

	for i = 1, MAXROWS do
		local r = CreateFrame("Button", nil, list)
		r:SetSize(272, ROWH)
		r:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * ROWH)
		local hl = r:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		r.left = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.left:SetPoint("TOPLEFT", 6, -3); r.left:SetPoint("TOPRIGHT", -6, -3)
		r.left:SetJustifyH("LEFT"); r.left:SetWordWrap(false)
		r.right = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		r.right:SetPoint("BOTTOMLEFT", 6, 3); r.right:SetPoint("BOTTOMRIGHT", -6, 3)
		r.right:SetJustifyH("LEFT"); r.right:SetWordWrap(false)
		r:SetScript("OnClick", function(self) if self.data then go(self.data) end end)
		rows[i] = r
	end

	search:HookScript("OnTextChanged", fill)
	search:HookScript("OnEditFocusGained", fill)
	search:HookScript("OnEditFocusLost", function() C_Timer.After(0.2, function() if not search:HasFocus() then list:Hide() end end) end)
	search:SetScript("OnEnterPressed", function() if list.first then go(list.first) end end)
	search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); list:Hide() end)

	ns.refreshSearch = function() holder:SetShown(opt("mapSearch") ~= false) end
	ns.refreshSearch()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LEVEL_UP" then
		C_Timer.After(0.5, update)
	else
		setup()
		if layer then pcall(setupSearch) end
	end
end)
