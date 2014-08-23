local spellList = {
	[47528] = 15,	-- DeathKnight Mind Freeze
	[80965] = 15,  	-- Skull Bash (Cat)
	[2139] = 20,	-- Mage Counterspell
	[96231] = 15,  	-- Paladin Rebuke
	[1766] = 15,	-- Rogue Kick
	[57994] = 12,	-- Shaman Wind Shear
	[19647] = 24,	-- Warlock Spell Lock
	[115781] = 24,	-- Warlock Optic blast
	[132409] = 24, 	-- Warlock Sacrifice Spell Lock
	[6552] = 15,	-- Warrior Pummel
	[102060] = 40,	-- 전사 시발 훼방
	[116705] = 15,	-- 손날찌르기(수도사)
	[147362] = 24,  -- 반격의 사격
	[34490] = 24, 	-- 침묵의 사격
	[119911] = 24, 	-- Warlock Optic blast
}

local fadedcolor              = {0.45,0.45,0.45,0.70};
local upcolor                 = {1.00,1.00,1.00,1.00};
local fadedrangecheckcolor    = {0.50,0.00,0.00,0.65};
local uprangecheckcolor       = {1.00,0.00,0.00,0.65};

local frames = {}
local numframes = 0
local playerClass;

local nowPos;

InterruptTrackerUnlock = false
InterruptTrackerSeScale = 1.0
InterruptTrackerSeRotate = false

InterruptTrackerSeMaxFrames = 5


local function InterruptTrackerFormatTime(time)
	if(time >= 1) then
		return floor(time);
	else
		return "."..floor(time*10);
	end
end

local function UnitIsPlayerByGUID(guid)
	-- enemy is player? taken from wowpedia
	local B = tonumber(guid:sub(5,5), 16);
	local maskedB = B % 8;
	if(maskedB == 0) then
		return true
	end

	return false
end

local function InterruptTrackerCreateFrame()
	numframes = numframes + 1

	frames[numframes] = CreateFrame("Frame", nil, UIParent)
	local frame = frames[numframes]

	frame:SetFrameStrata("LOW")
	frame:SetSize(36, 36)
	frame:SetScale(InterruptTrackerSeScale);
	
	frame:Hide()
	frame.fading = false
	frame.startTime = nil

	frame.icon = frame:CreateTexture(nil,"ARTWORK")
	frame.icon:SetAllPoints(frame)

	frame.overlay = CreateFrame("Frame", "InterruptTrackerActivationAlert" .. numframes, frame, "InterruptTrackerActivationAlert")
	frame.overlay:SetSize(36*1.4, 36*1.4)
	frame.overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -36*0.2, 36*0.2)
	frame.overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 36*0.2, -36*0.2)

	frame.ooccounter = CreateFrame("Frame", nil, frame)
	frame.ooccounter:SetScript("OnUpdate", InterruptTrackerOOCCounterFunc)
	frame.ooccounter:Hide()
	frame.ooccounter.startTime = nil

	frame.countframe = CreateFrame("Frame", nil, frame)
	frame.countframe:SetScript("OnUpdate", InterruptTrackerFrameCounter)
	frame.countframe:Hide()
	frame.countframe.endTime = nil

	frame.countframe.durtext = frame.countframe:CreateFontString(nil, "OVERLAY", "InterruptTrackerDurText")
	frame.countframe.durtext:SetPoint("CENTER", frame, "CENTER", 0, 0)

	if(numframes == 1) then
		frame:SetPoint("TOPLEFT", InterruptTrackerHeader, "TOPLEFT", 3, -3)
	else
		if(InterruptTrackerSeRotate) then
			frame:SetPoint("TOPLEFT", frames[numframes-1], "BOTTOMLEFT", 0, -5)
		else
			frame:SetPoint("TOPLEFT", frames[numframes-1], "TOPRIGHT", 5, 0)
		end
	end
end

local function InterruptTrackerShowFrame(num, spellId)
	if(not frames[num]:IsVisible() or frames[num].fading) then
		frames[num]:SetScript("OnUpdate",InterruptTrackerFadeFunc)
		frames[num]:Show()
		frames[num].fading = false
		frames[num].startTime = GetTime()
	end

	local dur = spellList[spellId]
		
	local icon = select(3, GetSpellInfo(spellId))
	frames[num].icon:SetTexture(icon)
	frames[num].spellId = spellId
	frames[num].dur = dur
	
	frames[num].endtime = GetTime() + dur

	frames[num].icon:SetVertexColor(fadedcolor[1], fadedcolor[2], fadedcolor[3], fadedcolor[4])
end

local function InterruptTrackerShowForceFrame(num, spellId , forcetime)
	if(not frames[num]:IsVisible() or frames[num].fading) then
		frames[num]:SetScript("OnUpdate",InterruptTrackerFadeFunc)
		frames[num]:Show()
		frames[num].fading = false
		frames[num].startTime = GetTime()
	end

	local dur = forcetime
	
	local icon = select(3, GetSpellInfo(spellId))
	frames[num].icon:SetTexture(icon)
	frames[num].spellId = spellId
	frames[num].dur = dur
	
	frames[num].endtime = GetTime() + dur

	frames[num].icon:SetVertexColor(fadedcolor[1], fadedcolor[2], fadedcolor[3], fadedcolor[4])
end

local function InterruptTrackerShowNonArenaFrame(num, spellID, guid)
	InterruptTrackerShowFrame(num, spellID)
	frames[num].guid = guid
	--frames[num].ownerguid = ownerguid
	frames[num].ooccounter:Show()
	frames[num].ooccounter.startTime = GetTime()
end

local function InterruptTrackerHideFrame(self)
	if(self:IsVisible() and not self.fading) then
		self:SetScript("OnUpdate",InterruptTrackerFadeFunc)
		self.fading = true
		self.startTime = GetTime()
	end

	self.spellId = nil
	self.dur = nil
	self.guid = nil
	--self.ownerguid = nil
	self.countframe:Hide()
	self.ooccounter:Hide()
--	self.rangecheck:Hide()
--	self.rangecheck.icon:Hide()
end

local function InterruptTrackerInstaHideAll()

	for i=1, numframes do
		frames[i].spellId = nil
		frames[i].dur = nil
		frames[i].guid = nil
		--frames[i].ownerguid = nil
		frames[i]:Hide()
		frames[i].countframe:Hide()
		frames[i].ooccounter:Hide()
--		frames[i].rangecheck:Hide()
--		frames[i].rangecheck.icon:Hide()
	end

end

local function InterruptTrackerStartCounter(num)

	if not ( frames[num].countframe.endTime == nil ) then
		--print( "frames["..num.."].countframe.endTime:"..frames[num].countframe.endTime);
		--print( "GetTime():"..GetTime());
		if( frames[num].countframe.endTime > GetTime()+frames[num].dur ) then 
			frames[num].icon:SetVertexColor(upcolor[1], upcolor[2], upcolor[3], upcolor[4])
			return;
		end;
	end
	
	frames[num].countframe:Show()
	frames[num].countframe.endTime = GetTime() + frames[num].dur
	frames[num].overlay.animIn:Play()

	frames[num].icon:SetVertexColor(upcolor[1], upcolor[2], upcolor[3], upcolor[4])
--	frames[num].rangecheck.icon:SetVertexColor(uprangecheckcolor[1], uprangecheckcolor[2], uprangecheckcolor[3], uprangecheckcolor[4])
end

local function InterruptTrackerStopCounter(frame)
	frame.countframe:Hide()

	frame.icon:SetVertexColor(fadedcolor[1], fadedcolor[2], fadedcolor[3], fadedcolor[4])
--	frame.rangecheck.icon:SetVertexColor(fadedrangecheckcolor[1], fadedrangecheckcolor[2], fadedrangecheckcolor[3], fadedrangecheckcolor[4])
end

local function InterruptTrackerAddNewOpponent(spellID, guid)

	--local ownerguid = ...
	for i=1, numframes do
		if(frames[i].guid == guid and frames[i].spellId == spellID) then
			-- maybe we can fill a missing ownerguid
			-- frames[i].ownerguid = ownerguid
			return nil;
		end
	end

	-- first, try to use an unused existing frame
	local maxavailableframes

	if(InterruptTrackerSeMaxFrames < numframes) then
		maxavailableframes = InterruptTrackerSeMaxFrames
	else
		maxavailableframes = numframes
	end

	for i=1, maxavailableframes do
		if(frames[i].spellId == nil) then
			InterruptTrackerShowNonArenaFrame(i, spellID, guid)
			return i
		end
	end


	if(InterruptTrackerSeMaxFrames >= numframes) then
		-- no unused existing frame found, create a new one
		InterruptTrackerCreateFrame()
		InterruptTrackerShowNonArenaFrame(maxavailableframes+1, spellID, guid)
		return maxavailableframes+1
	else
		-- maximum frame number reached. replace existing one
		local minooc = 0
		local minnum
		for i=1, numframes do
			if(not frames[i].countframe:IsVisible()) then
				local oocstart = frames[i].ooccounter.startTime
				if(minooc < oocstart) then
					minooc = oocstart
					minnum = i
				end
			end
		end

		if(minnum ~= nil) then
			InterruptTrackerShowNonArenaFrame(minnum, spellID, guid)
			return minnum
		end
	end
	
	return nil
end

--[[
local function InterruptTrackerSetupArenaOpponents()
	if(not UnitIsDeadOrGhost("player")) then
		for i=1, 5 do
			if(UnitExists("arena" .. i) and not UnitIsDead("arena" .. i)) then
				local class = select(2, UnitClass("arena" .. i))

				if(spellList[class] ~= nil) then
					InterruptTrackerAddNewArenaOpponent(class, i)
				end

			end
		end
	end
end
]]--

function InterruptTrackerOnLoad(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("ARENA_OPPONENT_UPDATE")

	self:SetBackdropColor(0, 0, 0);
	self:RegisterForClicks("RightButtonUp")
	self:RegisterForDrag("LeftButton")
	self:SetClampedToScreen(true)

	playerClass = select(2, UnitClass("player"))
end

function CheckArea()
	local a,type = IsInInstance()
	if (type == "pvp") then
		nowPos = type;
		return
	elseif (type == "arena") then
		nowPos = type;
		return
	else
		nowPos = "field";
		return
	end
end


function InterruptTrackerOnEvent(self, event, ...)

	if(InterruptTrackerUnlock) then
		return
	end

	if(event == "COMBAT_LOG_EVENT_UNFILTERED") then	

		if(UnitIsDeadOrGhost("player")) then
			return
		end

		local type = select(2, ...)
		local sourceGUID = select(4, ...)

		-- hide frame if unit died
		if (type == "UNIT_DIED") then
			local destGUID = select(8, ...)

			for i=1, numframes do
				if(destGUID == frames[i].guid) then
					InterruptTrackerHideFrame(frames[i])
					return
				end
			end
		end

		local sourceFlags = select(6, ...)
		local isSrcEnemy = (bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE)
		local isSrcPlayerControlled = (bit.band(sourceFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) == COMBATLOG_OBJECT_CONTROL_PLAYER)

		if(not isSrcEnemy or not isSrcPlayerControlled) then
			return
		end

		-- update ooc timers
		--if(not inArena and InterruptTrackerEnableNonArena) then
			for i=1, numframes do
				if(sourceGUID == frames[i].guid) then					
					frames[i].ooccounter.startTime = GetTime()
					--break
				end
			end
		--end

		if (type == "SPELL_CAST_SUCCESS" or type == "SPELL_MISS") then
			local spellId = select(12, ...)
			-- first, search for new opponents
			-- add opponents that use interrupt spells
			local destGUID = select(8, ...)
			
			if spellList[spellId] then
				--print("0:"..sourceGUID.."-"..spellId)
				--일단 찾아보자			
				for i=1, numframes do
					if frames[i].guid==sourceGUID and frames[i].spellId == spellId then
						InterruptTrackerShowFrame(i, spellId)
						InterruptTrackerStartCounter(i)
						
						--print("1:"..sourceGUID.."-"..spellId)
						
						if( spellId == 6552 ) then
							--print("6552!!")
							--자루치기일 경우 훼방도 15초 쿨다운
							for i=1, numframes do
								if frames[i].guid==sourceGUID and frames[i].spellId == 102060 then
									InterruptTrackerShowForceFrame(i, 102060, 15)
									InterruptTrackerStartCounter(i)
									return;
								end
							end
							
							newFrame = InterruptTrackerAddNewOpponent( 102060, sourceGUID)
							if( newFrame ~= nil ) then
								InterruptTrackerShowForceFrame(newFrame, 102060, 15)
								InterruptTrackerStartCounter(newFrame)
								return;
							end	
						elseif( spellId == 102060 ) then
							--훼방일경우 자루치기도 15초 쿨다운
							--print("6552!!")
							--자루치기일 경우 훼방도 15초 쿨다운
							for i=1, numframes do
								if frames[i].guid==sourceGUID and frames[i].spellId == 6552 then
									InterruptTrackerShowForceFrame(i, 6552, 15)
									InterruptTrackerStartCounter(i)
									return;
								end
							end
							
							newFrame = InterruptTrackerAddNewOpponent( 6552, sourceGUID)
							if( newFrame ~= nil ) then
								InterruptTrackerShowForceFrame(newFrame, 6552, 15)
								InterruptTrackerStartCounter(newFrame)
								return;
							end	
						end
						
						return;
					end
				end
				
				--없을경우 새로만들고 한번더 검색
				--print("1:"..sourceGUID.."-"..spellId)
				newFrame = InterruptTrackerAddNewOpponent( spellId, sourceGUID)
				if( newFrame ~= nil ) then
					--print("2:"..sourceGUID.."-"..spellId)
					InterruptTrackerShowFrame(newFrame, spellId)
					InterruptTrackerStartCounter(newFrame)
					
					if( spellId == 6552 ) then
						--print("6552!!")
						--자루치기일 경우 훼방도 15초 쿨다운
						for i=1, numframes do
							if frames[i].guid==sourceGUID and frames[i].spellId == 102060 then
								InterruptTrackerShowForceFrame(i, 102060, 15)
								InterruptTrackerStartCounter(i)
								return;
							end
						end
						
						newFrame = InterruptTrackerAddNewOpponent( 102060, sourceGUID)
						if( newFrame ~= nil ) then
							InterruptTrackerShowForceFrame(newFrame, 102060, 15)
							InterruptTrackerStartCounter(newFrame)
							return;
						end	
					elseif( spellId == 102060 ) then
						--훼방일경우 자루치기도 15초 쿨다운
						--print("6552!!")
						--자루치기일 경우 훼방도 15초 쿨다운
						for i=1, numframes do
							if frames[i].guid==sourceGUID and frames[i].spellId == 6552 then
								InterruptTrackerShowForceFrame(i, 6552, 15)
								InterruptTrackerStartCounter(i)
								return;
							end
						end
						
						newFrame = InterruptTrackerAddNewOpponent( 6552, sourceGUID)
						if( newFrame ~= nil ) then
							InterruptTrackerShowForceFrame(newFrame, 6552, 15)
							InterruptTrackerStartCounter(newFrame)
							return;
						end	
					end
					return;
				end				
			end
		end
	elseif(event == "PLAYER_ENTERING_WORLD") then
		InterruptTrackerInstaHideAll()
	elseif (event == "ARENA_OPPONENT_UPDATE") then
		--InterruptTrackerSetupArenaOpponents()
	elseif(event == "PLAYER_DEAD") then
		for i=1, numframes do
			InterruptTrackerHideFrame(frames[i])
		end
	elseif(event == "ADDON_LOADED" and arg1 == "InterruptTrackerSe") then
		print("Interrupt Tracker SE 1.06 By Azshara_kr - |cffDA70D6Lapresis" )
		InterruptTrackerSetScale()
		InterruptTrackerSetLayout()
		CheckArea()
	end

end

------------------------
-- OnUpdate Functions --
------------------------

function InterruptTrackerFrameCounter(self)
	local time = self.endTime - GetTime()

	if(time <= 0) then
		InterruptTrackerStopCounter(self:GetParent())
	else
		self.durtext:SetText(InterruptTrackerFormatTime(time))
	end
end

function InterruptTrackerFadeFunc(self)
	local elapsed = GetTime() - self.startTime;

	if(elapsed > 0.4) then
		self:SetScript("OnUpdate", nil);

		if(self.fading) then
			self:Hide()
		end
	end

	if(self.fading) then
		self:SetAlpha(1-elapsed*2.5);
	else
		self:SetAlpha(elapsed*2.5);
	end
end

function InterruptTrackerOOCCounterFunc(self)
	if(GetTime() - self.startTime > 15) then
		InterruptTrackerHideFrame(self:GetParent())
	end
end



---------------------------
-- Config Menu Functions --
---------------------------

function InterruptTrackerUnlockFunc()
	InterruptTrackerHeader:Show();
	--HideUIPanel(InterfaceOptionsFrame)
	InterruptTrackerUnlock = true

	InterruptTrackerInstaHideAll()

	if(numframes < 5) then
		for i=numframes+1, 5 do
			InterruptTrackerCreateFrame()
		end
	end
	
	InterruptTrackerShowFrame(1, 47528)
	InterruptTrackerShowFrame(2, 80965)
	InterruptTrackerShowFrame(3, 2139)
	InterruptTrackerShowFrame(4, 96231)
	InterruptTrackerShowFrame(5, 1766)
	InterruptTrackerStartCounter(2)
	InterruptTrackerStartCounter(3)
	InterruptTrackerStartCounter(5)
end

function InterruptTrackerLockFunc()
	InterruptTrackerHeader:Hide();
	InterruptTrackerUnlock = false

	InterruptTrackerInstaHideAll()

end

function InterruptTrackerSetLayout()

	if(InterruptTrackerSeRotate) then
		InterruptTrackerHeader:SetHeight(InterruptTrackerSeMaxFrames*41+1)
		InterruptTrackerHeader:SetWidth(44)

		if(numframes > 1) then
			for i=2, numframes do
				frames[i]:ClearAllPoints()
				frames[i]:SetPoint("TOPLEFT", frames[i-1], "BOTTOMLEFT", 0, -5);
			end
		end
	else
		InterruptTrackerHeader:SetHeight(44)
		InterruptTrackerHeader:SetWidth(InterruptTrackerSeMaxFrames*41+1)

		if(numframes > 1) then
			for i=2, numframes do
				frames[i]:ClearAllPoints()
				frames[i]:SetPoint("TOPLEFT", frames[i-1], "TOPRIGHT", 5, 0);
			end
		end
	end

end

function InterruptTrackerSetScale()
	for i=1, numframes do
		frames[i]:SetScale(InterruptTrackerSeScale);
	end

	InterruptTrackerHeader:SetScale(InterruptTrackerSeScale);
end

function InterruptTrackerUpdateMaxNum()
	if(not InterruptTrackerUnlock and InterruptTrackerSeMaxFrames < numframes) then
		for i=InterruptTrackerSeMaxFrames+1, numframes do
			InterruptTrackerHideFrame(frames[i])
		end
	end
end
