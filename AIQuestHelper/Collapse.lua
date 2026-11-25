local _, ns = ...

local Q = C_QuestLog

local function count()
	if Q and Q.GetNumQuestLogEntries then return (Q.GetNumQuestLogEntries()) or 0 end
	if GetNumQuestLogEntries then return (GetNumQuestLogEntries()) or 0 end
	return 0
end

local function header(i)
	if Q and Q.GetInfo then
		local info = Q.GetInfo(i)
		if info then return info.isHeader, info.isCollapsed end
		return false, false
	end
	if GetQuestLogTitle then
		local _, _, _, isHeader, isCollapsed = GetQuestLogTitle(i)
		return isHeader, isCollapsed
	end
	return false, false
end

local function anyCollapsed()
	for i = 1, count() do
		local h, c = header(i)
		if h and c then return true end
	end
	return false
end

local function setAll(expand)
	-- Back to front, so lines above keep their index while headers change
	for i = count(), 1, -1 do
		local h, c = header(i)
		if h then
			if expand and c and ExpandQuestHeader then pcall(ExpandQuestHeader, i)
			elseif not expand and not c and CollapseQuestHeader then pcall(CollapseQuestHeader, i) end
		end
	end
	if QuestMapFrame_UpdateAll then pcall(QuestMapFrame_UpdateAll) end
end

local btn
local function refresh()
	if not btn then return end
	local tex = anyCollapsed() and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up"
	btn:SetNormalTexture(tex)
end

local function build(parent, list)
	local b = CreateFrame("Button", "AIQuestHelperCollapseAll", parent)
	b:SetSize(16, 16)
	b:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -2)
	b:SetFrameLevel((list:GetFrameLevel() or 1) + 10)
	b:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
	b:SetScript("OnClick", function()
		setAll(anyCollapsed())
		C_Timer.After(0.05, refresh)
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(anyCollapsed() and "Expand all" or "Collapse all")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	btn = b
	refresh()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		local list = QuestScrollFrame or QuestLogFrame
		if list then build(QuestMapFrame or list, list) end
		return
	end
	refresh()
end)
