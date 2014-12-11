-- Author      : Matthew Enthoven (Alias: Blacksen) & Nicolau Goncalves (Alias: Excentrik)
-- Create Date : 1/04/2010 1:32:25 PM
-- Modification Date: 21/02/2014 1:48:00 PM
-- MainFrame.lua: Manages the main voting interface and host/client communication

-- 4.0 Change On

local auctionRunning = false; -- 0 if session running, 1 otherwise
local isPrivate = false; -- 0 if this session is private, 1 otherwise
local isSingle = false; -- 0 if this has single vote mode enabled, 1 otherwise
local isShowingSpec = true; -- 1 if showing mainspec/offspec, 0 otherwise
local isSelfVoting = false; -- 0 if can vote for self, 1 otherwise
local isSplitRaids = false; -- 0 if every raid has is own council, 1 otherwise

local itemRunning = nil; -- item link for the auction that's running
local isInitiator = false; -- 0 if we're NOT the initiator, 1 otherwise
local theInitiator = ""; -- Name of the initiator
local specialSlot = false; -- 1 if trinket/ring/neck, 0 otherwise
local theVote = ""; -- Helper variable for static popup (actual vote For/against/none)
local voteFor = ""; -- Who we're voting for
local suggestedBy = ""; -- Who suggested to end the session
local cmdDelim = " "; -- Helper variable in earlier iterations
local voteDelim = " "; -- Helper variable in earlier iterations
local selection = nil; -- Row we have selected
local councilList = " "; -- List of council members
local councilNum = 1; -- Number of council members
local requestedBefore = false;
local itemRemember = nil;
local awardShow = false;
local sanityCheck = 0;

local EnchantersList = {}; -- List of enchanters in the group
--local EnchantersNum = table.getn(EnchantersList); -- Number of enchanters in the group

local entryLinkWaiting = false;
local entryPings = {};

local clientEntryWaiting = false;
local clientEntryPings = {};

local MAX_ENTRIES = 30;
local MAX_VOTERS = 20;
local MAX_RAIDERS = 60;
local MAX_ENTRIES = 12;
local MIN_SIZE = 96;
local oldEntry = 0;
local dataRequest;
local dataTotal = {};

local sortMethod = "asc"
local currSortIndex = 0

local L = LootCouncilLocalization;

LootCouncil_Browser.MainDebug = false; -- Note: This is a variable for ACTIVATING all debug text. Lots of random stuff. Highly recommended to turn OFF
-- 1 = debug on (all print commands fired)
-- 0 = debuf off (no print commands)

-- 4.0 Change On
local LootCouncil_Lite = LibStub("AceAddon-3.0"):NewAddon("LootCouncil_Lite", "AceHook-3.0")

-------------- MainFrame_OnLoad --------------
-- Loads the Addon Frame
----------------------------------------------
function MainFrame_OnLoad()
    MainFrame:RegisterEvent("CHAT_MSG_OFFICER");
    MainFrame:RegisterEvent("CHAT_MSG_CHANNEL");
    MainFrame:RegisterEvent("CHAT_MSG_RAID");
    MainFrame:RegisterEvent("CHAT_MSG_RAID_LEADER");
    MainFrame:RegisterEvent("CHAT_MSG_GUILD");
    MainFrame:RegisterEvent("CHAT_MSG_ADDON");
    MainFrame:RegisterEvent("CHAT_MSG_WHISPER");
    MainFrame:SetScript("OnEvent", MainFrame_EventHandler);
    MainFrame:Hide();
	
	CurrentCouncilLabel:SetText(LootCouncilLocalization["CURRENT_COUNCIL"]);
	CurrentItemLabel:SetText(LootCouncilLocalization["CURRENT_ITEM"]);
	CurrentSelectionItemLevelLabel:SetText(LootCouncilLocalization["ITEM_LEVEL"]);
	CurrentSelectionLabel:SetText(LootCouncilLocalization["SELECTION"]);
	VotesAgainstLabel:SetText(LootCouncilLocalization["VOTES_AGAINST"]);
	VotesForLabel:SetText(LootCouncilLocalization["VOTES_FOR"]);
	
	----------- Voting Reason Popup Box -----------
	-- Loads the voting reason box
	-----------------------------------------------
	StaticPopupDialogs["LOOT_COUNCIL_VOTE_REASON"] = {
		text = "Reason for voting %s?",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		OnAccept = function(self)
			LootCouncil_Browser.updateVotes(LootCouncil_Browser.getUnitName("player"), voteFor, theVote, self.editBox:GetText())
		end,
		OnShow = function(self)
			self.editBox:SetFocus()
		end,
		EditBoxOnEnterPressed = function(self)
			LootCouncil_Browser.updateVotes(LootCouncil_Browser.getUnitName("player"), voteFor, theVote, self:GetText())
			self:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
		timeout=0,
		whileDead  = 1,
		hideOnEscape = 1
	}
	
	StaticPopupDialogs["LOOT_COUNCIL_SUGGEST_ABORT"] = {
		text = LootCouncilLocalization["SUGGEST_ABORT"],
		button1 = "Ignore",
		button2 = "Abort",
		OnAccept = function(self)
			suggestedBy = ""
			self:Hide()
		end,
		OnCancel = function(self)
			LootCouncil_Browser.confirmAbort()
		end,
		timeout=0,
		whileDead  = 1,
		hideOnEscape = 1
	}
	
	StaticPopupDialogs["LOOT_COUNCIL_CONFIRM_ABORT"] = {
		text = LootCouncilLocalization["CONFIRM_END"],
		button1 = "Yes",
		button2 = "No",
		OnAccept = function(self)
			LootCouncil_Browser.closeLootCouncilSession()
			self:Hide()
		end,
		timeout=0,
		whileDead  = 1,
		hideOnEscape = 1
	}
	
	StaticPopupDialogs["LOOT_COUNCIL_CONFIRM_LOOT_DECISION"] = {
		text = LootCouncilLocalization["CONFIRM_AWARD"],
		button1 = "Yes",
		button2 = "No",
		OnAccept = function(self)
			LootCouncil_Browser.itemAwarded = true;
			LootCouncil_Browser.giveItemAway();
		end,
		OnCancel = function(self)
			LootCouncil_Browser.itemAwarded = false;
			LootCouncil_Browser.candidateNum = nil;
			LootCouncil_Browser.slotNum = nil; 
		end,
		timeout=0,
		whileDead  = 1,
		hideOnEscape = 1
	}

	----------- Create Table Entries -----------
	-- Creates the Table Entries
	--------------------------------------------
	local entry = CreateFrame("Button", "$parentEntry1", EntryFrame, "LootCouncil_Entry"); -- Creates the first entry
	entry:SetID(1); -- Sets its id
	entry:SetPoint("TOPLEFT", 4, -28) --Sets its anchor
	for ci = 2, MAX_ENTRIES do --Loops through to create more rows
		local entry = CreateFrame("Button", "$parentEntry"..ci, EntryFrame, "LootCouncil_Entry");
		entry:SetID(ci);
		entry:SetPoint("TOP", "$parentEntry"..(ci-1), "BOTTOM") -- sets the anchor to the row above
	end
	
	councilList = LootCouncil_Browser.getUnitName("player");
	councilNum = 1;
end


-------------- showMainFrame --------------
-- Shows the Main Frame
-------------------------------------------
function LootCouncil_Browser.showMainFrame()
	MainFrame:Show()
end

-------------- resetMainFrame --------------
-- Resets the Main Frame Position
-------------------------------------------
function LootCouncil_Browser.resetMainFrame()
	MainFrame:ClearAllPoints()
	MainFrame:SetPoint("CENTER", UIParent, "CENTER");
end


-------------- hideMainFrame --------------
-- Hides the Main Frame
-------------------------------------------
function LootCouncil_Browser.hideMainFrame()
	MainFrame:Hide()
end


--------- CloseButton_OnClick -------------
-- Closes the Main Frame
-------------------------------------------
function CloseButton_OnClick()
	LootCouncil_Browser.hideMainFrame();
end

-------------- MainFrame_EventHandler --------------
-- Event Handler for the Main Frame
-- EVENTS HANDLED: 
-- -- CHAT_MSG_OFFICER
-- -- CHAT_MSG_ADDON
-- -- CHAT_MSG_WHISPER
-- -- CHAT_MSG_RAID
-- -- CHAT_MSG_GUILD
----------------------------------------------------
function MainFrame_EventHandler(self, event, ...)
	if event == "CHAT_MSG_OFFICER" and LootCouncil_Channel=="OFFICER" and LootCouncil_LinkOfficer == true then
		local msg, sender = ...
		if isInitiator == true then
			LootCouncil_Browser.newEntry(sender, msg);
		end
	elseif event == "CHAT_MSG_CHANNEL" and LootCouncil_Channel~="OFFICER" and LootCouncil_LinkOfficer == true then
		local msg, sender, language, channelString, target, flags, unknown, channelNumber, channelName = ...
		if isInitiator == true and channelName== LootCouncil_Channel then
			LootCouncil_Browser.newEntry(sender, msg);
		end
	elseif event == "CHAT_MSG_WHISPER" and LootCouncil_LinkWhisper == true then
		local msg, sender = ...;
		if isInitiator == true and LootCouncil_Browser.getUnitName("player")~= sender then
			LootCouncil_Browser.newEntry(sender, msg);
		end
	elseif ((event == "CHAT_MSG_RAID" or event== "CHAT_MSG_RAID_LEADER") and LootCouncil_LinkRaid == true) then
		local msg, sender = ...;
		if isInitiator == true then
			LootCouncil_Browser.newEntry(sender, msg);
		end
	elseif event == "CHAT_MSG_GUILD" and LootCouncil_LinkGuild == true then
		local msg, sender = ...;
		if isInitiator == true then
			LootCouncil_Browser.newEntry(sender, msg);
		end
	elseif event == "OPEN_MASTER_LOOT_LIST" then
		LootCouncil_Browser.openMasterLootList();
	elseif event == "UPDATE_MASTER_LOOT_LIST" then
		LootCouncil_Browser.updateMasterLootList();
	elseif event == "LOOT_OPENED" then
		local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod();
		if masterlooterRaidID then
			local name, rank, subgroup = GetRaidRosterInfo(masterlooterRaidID);
			if name == LootCouncil_Browser.getUnitName("player") then
				awardShow = true;
				LootCouncil_Browser.Update()
			end
		end
	elseif event == "LOOT_CLOSED" then
		awardShow = false;
		LootCouncil_Browser.Update();
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, msg, channel, sender = ...
		if prefix == "L00TCOUNCIL" and sender ~= LootCouncil_Browser.getUnitName("player") then
			
			local cmd, other = strsplit(cmdDelim, msg, 2)
			local isSame= (LootCouncil_Browser.searchSameRaid(sender) or not(LootCouncil_SplitRaids) )
			if isSame then
				LootCouncil_Browser.printd("Our Command: " .. cmd);
				if cmd == "start" then
					if other == nil or other == "" then
						print(LootCouncilLocalization["FAILED_START_NO_VALID_LINK"])
					else
						-- Check if initiator is in the same raid as the player					
						if ((not itemRunning) or sender==theInitiator) then
							local name, link = GetItemInfo(other);
							if name == nil then
								LootCouncil_awaitingItem = true;
								dataRequest = other;
								sanityCheck = 0;
								MainFrame:SetScript("OnUpdate", MainFrame_OnUpdate);
							end
							LootCouncil_Browser.heardStart(sender, other);
						else
							print("------------------------------------")
							print(string.format(LootCouncilLocalization["START_WHILE_GOING1"], sender))
							print(LootCouncilLocalization["START_WHILE_GOING2"])
							print("------------------------------------")
						end
					end
				elseif cmd == "suggestAbort" then
					if suggestedBy then
						StaticPopup_Hide("LOOT_COUNCIL_SUGGEST_ABORT")
						StaticPopup_Show("LOOT_COUNCIL_SUGGEST_ABORT", sender)
					end
				elseif cmd == "abort" and sender==theInitiator then
					LootCouncil_Browser.closeLootCouncilSession()	
				elseif cmd == "vote" then
					local char, voter, vote, reason = strsplit(voteDelim, other, 4);
					LootCouncil_Browser.updateVotes(voter, char, vote, reason);
				elseif cmd == "end" then
					LootCouncil_Browser.resetConsideration();
				elseif cmd == "councilList" then
					CurrentCouncilList:SetText(other)
					CurrentCouncilList:Show()
					CurrentCouncilLabel:Show()
				elseif cmd == "echo" then
					LootCouncil_Browser.processEcho(sender, other);
				elseif cmd == "confirmed" then
					local private, single, spec, selfVoting = strsplit(voteDelim, other, 4);
					LootCouncil_Browser.processResponse(tonumber(private), tonumber(single), tonumber(spec), tonumber(selfVoting));
				elseif cmd == "itemEntry" then
					local name, item = strsplit(" ", other, 2);
					LootCouncil_Browser.printd("PULSED ITEM");
					LootCouncil_Browser.receiveItemEntry(name, item);
				elseif cmd == "secondEntry" then
					local name, item = strsplit(" ", other, 2);
					LootCouncil_Browser.receiveSecondEntry(name, item);
				elseif cmd == "data" then
					LootCouncil_Browser.updatePlayerData(other);
				elseif cmd == "remove" and sender==theInitiator then
					LootCouncil_Browser.removePlayer(other)
				elseif cmd == "spec" then
					local char, spec = strsplit(" ", other, 2);
					LootCouncil_Browser.updateSpec(char, spec)
				end
			end
			if cmd == "testCouncil" then -- ADDED IN VERSION 2.0. Test council ping.
				GuildRoster();
				for ci = 1, GetNumGuildMembers() do -- otherwise, start looping through the guild list
					--local theName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
					local theName, rank, rankIndex = LootCouncil_Browser.getCharInfo(ci);
					if sender == theName then -- if we find them
						if (rankIndex+1) <= (LootCouncil_minRank + 0.1) then -- check if they're above the minimum rank
							SendAddonMessage("L00TCOUNCIL", "testReplyGood", "GUILD")
						else
							SendAddonMessage("L00TCOUNCIL", "testReplyBad", "GUILD")
						end
						break;
					end
				end
			end
		end
	end
end


-------------- initiateLootCouncil --------------
-- Tries to initiate a new loot council session
-------------------------------------------------
function LootCouncil_Browser.initiateLootCouncil(item)
	if item == nil then
		print(LootCouncilLocalization["FAILED_START_NO_LINK"])
	else
		if auctionRunning==true and (itemRunning or LootCouncil_awaitingItem) then --If we have a consideration running, tell the user we can't start a new one
			print(LootCouncilLocalization["START_WHILE_SESSION1"]);
			if itemRunning then
				print(string.format(LootCouncilLocalization["START_WHILE_SESSION2"], itemRunning));
			else
				print(LootCouncilLocalization["START_WHILE_SESSION2_NOLINK"]);
			end
		else
			local isValid = LootCouncil_Browser.validInitiator("player");
			if isValid == 0 then -- Fires when player is IN a raid but NOT a raid officer
				print(LootCouncilLocalization["NOSTART_1"]);
				print(LootCouncilLocalization["NOSTART_NOT_RAIDASSIST"]);
			elseif isValid == 3 and LootCouncil_Browser.MainDebug==false then -- Fires when player is NOT in a raid and is NOT the guild leader
				print(LootCouncilLocalization["NOSTART_1"]);
				print(LootCouncilLocalization["NOSTART_NOT_GM"]);
			elseif isValid == 1 or (isValid ==3 and LootCouncil_Browser.MainDebug==true) then -- Fires when player is either a raid officer or guild leader
				GuildRoster();
				--LootCouncil_Browser.updateEnchantersList()
				LootCouncil_Browser.WhisperList = {}
				LootCouncil_Browser.itemAwarded = false;
				entryLinkWaiting = false;
				entryPings = {};
				itemRunning = item; -- Set the current item that's running
				isInitiator=true; -- We're the initiator, so set that
				theInitiator = LootCouncil_Browser.getUnitName("player");
				--Send out the messages regarding the item
				if LootCouncil_debugMode == false then
					LootCouncil_SendChatMessage(LootCouncilLocalization["START_FIRED"], LootCouncil_Channel); 
					LootCouncil_SendChatMessage("item: "..itemRunning, LootCouncil_Channel);
				end
				local found, _, itemString = string.find(itemRunning, "^|c%x+|H(.+)|h%[.*%]");
				LootCouncil_Browser.printd("prep for addon message");
				SendAddonMessage("L00TCOUNCIL", "start"..cmdDelim..itemString, "GUILD");
				LootCouncil_Browser.printd("post addon message");
				CurrentCouncilList:SetText(councilList)
				CurrentCouncilList:Show()
				CurrentCouncilLabel:Show()
				if GetNumLootItems() > 0 then
					awardShow = true;
				else
					awardShow = false;
				end
				isPrivate = LootCouncil_Browser.private;
				isSingle = LootCouncil_Browser.single;
				isShowingSpec = LootCouncil_Browser.spec;
				isSelfVoting = LootCouncil_Browser.self;
				isSplit= LootCouncil_Browser.split;
				--SyncButton:Show();
				LootCouncil_Browser.showMainFrame();
				councilList = LootCouncil_Browser.getUnitName("player");
				councilNum = 1;
				if UnitInRaid("player") and LootCouncil_debugMode == false then
					LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["START_MSG_PULSE1"], itemRunning,theInitiator), "RAID_WARNING");
					LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["START_MSG_PULSE2"], itemRunning,theInitiator), "RAID");
				else
					if LootCouncil_debugMode == false then
						LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["START_MSG_PULSE1"], itemRunning), "GUILD");
						LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["START_MSG_PULSE2"], itemRunning), "GUILD");
					end
				end
				
				if XLootMaster then
					XLootMaster.dewdrop:Refresh(1)
				end
				
				LootCouncil_Browser.prepareLootFrame();
			end
		end
	end
end


-------------- validInitiator ---------------------------
-- Checks if the client or sender is able to initiate a new session
---------------------------------------------------------
function LootCouncil_Browser.validInitiator(sender)	
	if sender == "player" then
		if UnitInRaid("player") then -- If the player is in a raid
			if UnitIsGroupAssistant("player") or UnitIsGroupLeader("player") then
				return 1
			else
				return 0
			end
		else
			if IsGuildLeader(LootCouncil_Browser.getUnitName("player")) == true then -- If they're the guild leader
				return 1; --Then return 1
			else
				return 3; -- Else, return 3
			end
		end
	else
		GuildRoster();
		for ci = 1, GetNumGuildMembers() do
			--local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
			local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = LootCouncil_Browser.getCharInfo(ci);
			--print(name)
			if name == sender then
				if (rankIndex+1) <= (LootCouncil_minRank + 0.1) then
					return 1;
				else
					return 0;
				end
			end
		end
	end
end


-------------- prepareLootFrame -------------------------
-- Prepares the main frame for such
---------------------------------------------------------
function LootCouncil_Browser.prepareLootFrame()
	auctionRunning=true; -- We're running an auction now, so set it to true;
	local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture;
	if itemRunning then
		sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(itemRunning); -- Get the item info
	end
	
	if thisItemTexture then
		CurrentItemTexture:SetTexture(thisItemTexture); -- Set the texture of the icon box
	else
		CurrentItemTexture:SetTexture("Interface\InventoryItems\WoWUnknownItem01");
	end
	
	CurrentItemTexture:Show(); -- Open up the icon box
	AbortButton:Show(); -- Show the Abort Button
	if iLevel then
		CurrentItemLvl:SetText(iLevel); -- Show the Item Level
	else
		CurrentItemLvl:SetText("...");
	end
	
	if sLink then
		CurrentItemLink:SetText(sLink); -- Set the item link for color and such
	else
		CurrentItemLink:SetText(LootCouncilLocalization["LOADING"]);
	end
	CurrentItemLevelLabel:Show(); -- Show the Lable for item level
	
	
	EmptyTexture:Hide(); -- Hide the empty texture
	LootCouncil_Browser.Elects = {} -- Reset all entrants
	LootCouncil_Browser.Votes = {} -- Reset all votes
	RemoveButton:Hide()
	LootCouncil_Browser.printd(thisItemEquipLoc);
	local slotNum = LootCouncil_Browser.translateToSlot(thisItemEquipLoc);
	LootCouncil_Browser.printd("SLOT NUMBER: " .. slotNum);
	if slotNum == 13 or slotNum == 11 or slotNum == 16 then
		specialSlot = true;
	else
		specialSlot = false;
	end
	CurrentItemHover:Show()
	for ci = 1, MAX_ENTRIES do
		if isSingle == true then
			_G["EntryFrameEntry"..ci.."AgainstButton"]:Hide()
		else
			_G["EntryFrameEntry"..ci.."AgainstButton"]:Show()
		end
		
		if isPrivate == true then
			_G["EntryFrameEntry"..ci.."VoteHover1"]:Hide()
		else
			_G["EntryFrameEntry"..ci.."VoteHover1"]:Show()
		end	
		
		if isShowingSpec == false then
			_G["EntryFrameEntry"..ci.."Spec"]:Hide()
			local frame = _G["EntryFrameEntry"..ci.."Itemlvl"]
			--_G["EntryFrameEntry"..ci]:SetWidth(647)
			_G["EntryFrameEntry"..ci.."VotesTotal"]:SetPoint("LEFT", frame, "RIGHT");
		else
			local frame = _G["EntryFrameEntry"..ci.."Spec"]
			frame:Show()
			--_G["EntryFrameEntry"..ci]:SetWidth(687)
			_G["EntryFrameEntry"..ci.."VotesTotal"]:SetPoint("LEFT", frame, "RIGHT");
		end
	end
	if isSingle == true then
		_G["EntryFrameHeaderVotesTotal"]:SetText("Total Votes")
	else
		_G["EntryFrameHeaderVotesTotal"]:SetText("Total Votes (+/-)")
	end
	
	if isShowingSpec == false then
		_G["EntryFrameHeaderSpec"]:Hide()
		--MainFrame:SetWidth(687)
		--EntryFrame:SetWidth(655)
		local frame = _G["EntryFrameHeaderItemlvl"]
		_G["EntryFrameHeaderVotesTotal"]:SetPoint("LEFT", frame, "RIGHT");
	else
		local frame = _G["EntryFrameHeaderSpec"]
		frame:Show()
		--MainFrame:SetWidth(722)
		--EntryFrame:SetWidth(695)
		_G["EntryFrameHeaderVotesTotal"]:SetPoint("LEFT", frame, "RIGHT");
	end
end


-------------- heardStart ---------------------
-- Process a "start" command
-----------------------------------------------
function LootCouncil_Browser.heardStart(sender, item)
	councilList = "";
	councilNum = 0;
	itemRemember = item;
	if (LootCouncil_Browser.validInitiator(sender) == 1) then
		theInitiator = sender;
		isInitiator = false; -- We're NOT the initiator
		local rprsName, rprsLink = GetItemInfo(item); -- Get the item link (since we just got sent the item string)
		itemRunning = rprsLink;
		SendAddonMessage("L00TCOUNCIL", "echo "..LootCouncil_Version, "WHISPER", theInitiator);
	else
		print(string.format(LootCouncilLocalization["TOO_LOW_RANK"], sender));
	end
end


-------------- processEcho ---------------------
-- Process an echo to add to the loot list
-----------------------------------------------
function LootCouncil_Browser.processEcho(sender, ver)
	if isInitiator == true then
		for ci = 1, GetNumGuildMembers() do
			--local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
			local name, rank, rankIndex = LootCouncil_Browser.getCharInfo(ci);
			if name == sender then
				if (rankIndex+1) <= (LootCouncil_minRank + 0.1) then
					table.insert(LootCouncil_Browser.WhisperList, sender)
					councilList = councilList..", "..sender
					councilNum = councilNum + 1
					CurrentCouncilList:SetText(councilList)
					LootCouncil_Browser.sendGlobalMessage("councilList "..councilList)
					SendAddonMessage("L00TCOUNCIL", "confirmed "..LootCouncil_logical2string(LootCouncil_privateVoting).." "..LootCouncil_logical2string(LootCouncil_singleVote).." "..LootCouncil_logical2string(LootCouncil_displaySpec).." "..LootCouncil_logical2string(LootCouncil_selfVoting), "WHISPER", sender);
				end
				break;
			end
		end
		
		if (not ver) or (not (LootCouncil_Version == ver)) then
			if (not ver) or tonumber(LootCouncil_Version) > tonumber(ver) then
				if LootCouncil_debugMode == false then
					LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["OUTDATED"], LootCouncil_Version), "WHISPER", nil, sender)
				end
			else
				print(string.format(LootCouncilLocalization["OUTDATED"], ver))
			end
		end
	end
end


-------------- processResponse-----------------
-- Processes the response to an echo to prepare
-- the Main Frame
-----------------------------------------------
function LootCouncil_Browser.processResponse(prv, sing, spec, selfVoting)
	--SyncButton:Hide();
	isPrivate = prv;
	isSingle = sing;
	isShowingSpec = spec;
	isSelfVoting = selfVoting;
	LootCouncil_Browser.prepareLootFrame()
	MainFrame:Show()
end


-------------- resetConsideration -------------
-- Ends the Loot Council Session
-----------------------------------------------
function LootCouncil_Browser.resetConsideration()
	CurrentItemTexture:SetTexture("Interface\InventoryItems\WoWUnknownItem01");
	LootCouncil_awaitingItem = false;
	RemoveButton:Hide()
	LootCouncil_Browser.ClearSelection()
	EmptyTexture:Show();
	CurrentItemTexture:Hide();
	itemRunning = nil;
	auctionRunning = false;
	LootCouncil_Browser.Elects = {}
	LootCouncil_Browser.Update();
	CurrentItemLevelLabel:Hide();
	AbortButton:Hide();
	CurrentItemLvl:SetText("");
	EmptyTexture:Show();
	CurrentItemLink:SetText("");
	CurrentItemTexture:Hide();
	CurrentCouncilList:SetText("")
	CurrentCouncilList:Hide()
	CurrentCouncilLabel:Hide()
	CurrentItemHover:Hide()
	VotesForLabel:Hide()
	--SyncButton:Hide();
	VotesFor:Hide()
	VotesAgainstLabel:Hide()
	VotesAgainst:Hide();
	selection = nil;
	awardShow = false;
	LootCouncil_Browser.Update();
	oldEntry = 0;
	LootCouncil_Browser.private = LootCouncil_privateVoting;
	LootCouncil_Browser.split = LootCouncil_SplitRaids;
	LootCouncil_Browser.single = LootCouncil_singleVote;
	LootCouncil_Browser.spec = LootCouncil_displaySpec;
	LootCouncil_Browser.self = LootCouncil_selfVoting;
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
	entryLinkWaiting = false;
	entryPings = {};
end


-------------- alreadyLinkedItem --------------
-- Checks if the user has already linked an item
-- If they have, then update it
-----------------------------------------------
function LootCouncil_Browser.alreadyLinkedItem(name, item)
	LootCouncil_Browser.printd("Checking for already linked...");
	local psName, psLink, piRarity, piLevel, piMinLevel, psType, psSubType, piStackCount, pthisItemEquipLoc = GetItemInfo(item); --TODO: Fired problem on multiitemlinks
	if piLevel then
		LootCouncil_Browser.printd("Found item off server");
		for ci = 1, MAX_ENTRIES do
			local entry = LootCouncil_Browser.Elects[ci];
			if entry and entry[1] and entry[1] == name then
				entry[2] = item.." ("..piLevel..")";
				entry[3] = piLevel
				entry[12] = 1;
				entry[13] = psLink;
				entry[14] = nil;
				LootCouncil_Browser.Update()
				LootCouncil_Browser.printd("ALREADY LINKED!");
				return ci;
			end
		end
	else
		LootCouncil_Browser.printd("Could NOT find item");
		local ret = 0;
		for ci = 1, MAX_ENTRIES do
			local entry = LootCouncil_Browser.Elects[ci];
			if entry and entry[1] and entry[1] == name then
				LootCouncil_Browser.printd("ALREADY LINKED!");
				ret = ci;
				local notFound = true;
				for ci = 1, #clientEntryPings do
					local theInfo = clientEntryPings[ci];
					if theInfo and theInfo[1] and theInfo[1] == name then
						theInfo[3] = item;
						notFound = false;
					end
				end
				if notFound then
					clientEntryWaiting = true;
					table.insert(clientEntryPings, {
								 name,
								 "=",
								 item
								 });
					sanityCheck = 0;
					MainFrame:SetScript("OnUpdate", MainFrame_OnUpdate);
				end
				break;
			end
		end
		return ret;
	end
	return 0
end


---------- ShowCurrentItemTooltip -------------
-- Shows item that's under the running Tooltip
-----------------------------------------------
function LootCouncil_Browser.ShowCurrentItemTooltip()
	if itemRunning then
		GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(itemRunning)
		GameTooltip:Show()
	end
	
	if LootCouncil_awaitingItem then
		GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
		GameTooltip:SetText(LootCouncilLocalization["LOADING"]);
		GameTooltip:Show()
	end
end


---------- ShowCurrentSelectionTooltip -------------
-- Shows item that's under the running Tooltip
-----------------------------------------------
function LootCouncil_Browser.ShowCurrentSelectionTooltip()
	if selection then
		GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(selection[13])
		GameTooltip:Show()
	end
end

---------- ShowCurrentSelectionDualTooltip -------------
-- Shows item that's under the running Tooltip
-----------------------------------------------
function LootCouncil_Browser.ShowCurrentSelectionDualTooltip()
	if selection then
		GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(selection[14])
		GameTooltip:Show()
	end
end


------------------ CastVote -------------------
-- Maintains the Cast Vote Buttons
-----------------------------------------------
function LootCouncil_Browser.CastVote(id, vote, click)
	local entry = LootCouncil_Browser.Elects[id];
	if entry and entry[9]~= vote then
		if vote == "None" then
			LootCouncil_Browser.updateVotes(LootCouncil_Browser.getUnitName("player"), entry[1], vote, "");
		else
			theVote = vote;
			voteFor = entry[1];
			if click == "LeftButton" then
				LootCouncil_Browser.updateVotes(LootCouncil_Browser.getUnitName("player"), voteFor, theVote, "No Reason")
			elseif click == "RightButton" and isPrivate == false then
				StaticPopup_Show("LOOT_COUNCIL_VOTE_REASON", ""..string.upper(theVote).." "..voteFor)
			end
		end
	end
end


------------------ newEntry -------------------
-- Adds a new entry if you're the initiator




-- This is one hell of a function




-----------------------------------------------
function LootCouncil_Browser.newEntry(name, msg) --Add a new entry to the loot table
	if auctionRunning==true and itemRunning and name and msg ~= nil and isInitiator == true then -- Make sure we have an auction running
		
		-- Check if they've linked an item
		-- Check if they've linked TWO items
		-- Pull the item info and check if it's valid!
		local theItem = msg:find("|Hitem:"); -- See if they linked an item
		LootCouncil_Browser.printd(theItem);
		if theItem and theItem >= 0 then -- If they entered a valid item
			local flagforwaiting = false;
			local actualItemString2; -- Initialize for possibility of 2 item links
			local startLoc = string.find(msg, "Hitem:") -- Make sure they linked an item
			local endLoc = string.find(msg, "|", startLoc)
		--	local actualItemString = string.sub(msg, startLoc, endLoc) -- Isolate the item string -- OLD AND OUTDATED
		--	local actualItemString = string.match(msg, "item[%-?%d:]+")
			local actualItemString = string.match(msg, "|%x+|Hitem:.-|h.-|h|r");
			LootCouncil_Browser.printd(actualItemString);
		--	LootCouncil_Browser.printd("item... " .. itemString2);
			if (specialSlot == true) then -- If this was a trinket/weapon/rings
				LootCouncil_Browser.printd("Checking for 2 items starting at index " .. endLoc);
				theItem = string.find(msg, "Hitem:", endLoc) --See if they linked a second item
				if theItem and theItem >= 0 then -- If they did
					LootCouncil_Browser.printd("found it");
					local laterString = string.sub(msg, endLoc);
				--	actualItemString2 = string.sub(msg, startLoc, endLoc)
					actualItemString2 = string.match(laterString, "|%x+|Hitem:.-|h.-|h|r");
				end
			end
			local psName, psLink, piRarity, piLevel, piMinLevel, psType, psSubType, piStackCount, pthisItemEquipLoc = GetItemInfo(actualItemString); -- Get better info for item 1
			local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc = GetItemInfo(itemRunning); --Get the current info
			
			if actualItemString == sLink then
				LootCouncil_Browser.printd("MATCH MATCH MATCH MATCH MATCH MATCH MATCH MATCH MATCH MATCH ");
			end
			
			if actualItemString ~= sLink then
				LootCouncil_Browser.printd(actualItemString .. " vs " .. sLink);
				local psName2, psLink2, piRarity2, piLevel2, piMinLevel2, psType2, psSubType2, piStackCount2, pthisItemEquipLoc2; -- Initialize scoping for second variable.
				local spec = "-";
				local fullSpec = "";
				if psName == nil then
				--		print("ERROR!!! "..name.." linked an item that we couldn't pull the data for. Report the item to Blacksen on Curse or Wowinterface.")
				--		LootCouncil_SendChatMessage("ERROR!!! "..name.." linked an item that we couldn't pull the data for. Report the item to Blacksen on Curse or Wowinterface.", "WHISPER", nil, name)
				-- Abort
				--			return;
			
					--VERSION 2.1 FUNCTIONALITY:
					-- So most items we're going to have to wait on.
					-- Luckily, we have an OnUpdate function ready.
					-- We just need to toss in the variables!
					flagforwaiting = true;
				end
				if actualItemString2 and (specialSlot == true) then -- If they linked a second item and it was appropriate
					
					if psName2 == nil then
			--			print("ERROR!!! "..name.." linked an item that we couldn't pull the data for. Report the item to Blacksen on Curse or Wowinterface.")
			--			LootCouncil_SendChatMessage("ERROR!!! "..name.." linked an item that we couldn't pull the data for. Report the item to Blacksen on Curse or Wowinterface.", "WHISPER", nil, name)
			--			-- Abort
			--			return;
						flagforwaiting = true;
					end
				end
				
				-- THIS ENTIRE NEXT PART IS DESIGNED TO GET THE PLAYER'S SPEC
				-- Why is it such a hassle?
				-- -- We want to take out the item links from what they said
				-- -- Technically that's challenging, as we don't want to parse them incorrectly
				-- -- Even worse would be if their item has the word "main" or "OFFSPEC" in it (like Maiden's Offering or something)
				-- -- So, we break apart the message into 3 parts: before the itemlinks, the itemlinks, and after the itemlinks
				-- -- To complicate it even more, colons and dashes won't work, so we have to take them out
				-------------------------------------
				-- DONE SEARCHING FOR SPEC 
				-------------------------------------
				
				
				-------------------------------------
				-- START UPDATING THE TABLES
				-------------------------------------
				
				-- This is a long if statement...
				-- If this item has no equip loc (like tier tokens) OR (the two items they linked have the same equip loc )
				-- AND (there either is no second item OR the second item has the same equip loc)
				
				
				-- VERSION 2.1
					-- All of this has been kept for legacy reasons
					-- New function completely reworks this logic.
				spec = "-";
				if isShowingSpec == true then
					spec = LootCouncil_Browser.parseSpec(msg, actualItemString, actualItemString2) 
				end
				
				LootCouncil_Browser.printd(actualItemString);
				if actualItemString2 then
					LootCouncil_Browser.printd("BANG: " .. actualItemString2);
				end
				table.insert(entryPings, {
							 name,
							 spec,
							 actualItemString,
							 actualItemString2,
							 });
	
				if flagforwaiting then
					entryLinkWaiting = true;
					LootCouncil_Browser.printd("MESSAGE BOUND: " .. msg);
					sanityCheck = 0;
					MainFrame:SetScript("OnUpdate", MainFrame_OnUpdate);
				end
					
				LootCouncil_Browser.addNewEntry2(#entryPings);
				
				--Entry Pings Info
					-- 1: Sender
					-- 2: Spec
					-- 3: ItemString1
					-- 4: ItemString2
				
				
				
				
				
				
				
--[[	
				if ((thisItemEquipLoc == "") or (LootCouncil_Browser.translateToSlot(pthisItemEquipLoc) == LootCouncil_Browser.translateToSlot(thisItemEquipLoc)) and ((not pthisItemEquipLoc2) or (LootCouncil_Browser.translateToSlot(pthisItemEquipLoc2) == LootCouncil_Browser.translateToSlot(thisItemEquipLoc)))) then 
					local indexOfPlayer = LootCouncil_Browser.alreadyLinkedItem(name, psLink); -- Checks if they've linked an item
					if indexOfPlayer > 0 then -- If they have
						theEntry = LootCouncil_Browser.Elects[indexOfPlayer]; -- then get their row
						theEntry[15] = spec; -- and update their spec
						if pthisItemEquipLoc2 then -- If they have already linked an item, we already updated the first item, so we need to update the second
							theEntry[2] = theEntry[2].."\n"..psLink2.." ("..piLevel2..")"; -- append the second item link onto the string
							theEntry[3] = piLevel.." - "..piLevel2 -- Get the itemlevels set
							theEntry[12] = 2; -- switch the flag for two items
							theEntry[14] = psLink2; -- hold the second link
							if LootCouncil_debugMode == false then -- If we're displaying messages
								-- Send the player a message saying we got the update
								if spec == "-" then
									LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED"], itemRunning), "WHISPER", nil, name);
								else
									LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED_SPEC"], fullSpec, itemRunning), "WHISPER", nil, name);
								end
								LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK2"]..theEntry[13].." - "..theEntry[14], "WHISPER", nil, name);
							end
							-- Update the clients
							LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString) -- Send out info to other council
							LootCouncil_Browser.sendGlobalMessage("secondEntry "..name.." "..actualItemString2)
							LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
						else -- Else they only have 1 item, so we don't need to do as much
							if LootCouncil_debugMode == false then -- If we're displaying messages
								-- Send the player a message saying we got the update
								if spec == "-" then
									LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED"], itemRunning), "WHISPER", nil, name);
									LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
								else
									LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED_SPEC"], fullSpec, itemRunning), "WHISPER", nil, name);
									LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
								end
							end
							-- and Update the clients!
							LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString)
							LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
						end
						LootCouncil_Browser.Update(); -- Update the main graphs
						if indexOfPlayer > 0 and LootCouncil_Browser.IsSelected(indexOfPlayer) then -- if they had them selected, update that too
							LootCouncil_Browser.SelectEntry(indexOfPlayer)
						end
					else -- They haven't already linked an item, so we need to put them in the table.
						if LootCouncil_debugMode == false then -- If we're sending messages
							-- then let them know we got the message
							if spec == "-" then 
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["NEW_ENTRY"], itemRunning), "WHISPER", nil, name); -- Whisper them about their consideration
							else
							if spec == "M" then
								fullSpec = "MAIN";
							elseif spec == "OFF" then
								fullSpec = "OFFSPEC";
							elseif spec == "2SET" then
								fullSpec = "BONUS SET (2 parts)";
							elseif spec == "4SET" then
								fullSpec = "BONUS SET (4 parts)";
							elseif spec == "XMOG" then
								fullSpec = "TRANSMOG";
							elseif spec =="BIS" then
								fullSpec = "BiS";
							else
								fullSpec = "UNKNOWN";
							end
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["NEW_ENTRY_SPEC"], fullSpec, itemRunning), "WHISPER", nil, name);
							end
						end
						--Update the clients that we have a new item entry.
						LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString) -- Send out a global 
						if psLink2 and (specialSlot == true) then -- If this is a 2-item slot and they linked 2 items
							if LootCouncil_debugMode == false then -- Send them a message about the items we got
								LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK2"]..psLink.." - "..psLink2, "WHISPER", nil, name); -- Send them about BOTH items
							end
							LootCouncil_Browser.sendGlobalMessage("secondEntry "..name.." "..actualItemString2) -- Alert other councilmen about the second item that we got
							table.insert(LootCouncil_Browser.Elects, { -- put them in the table
								name, -- Player Name
								psLink.." ("..piLevel..")\n"..psLink2.." ("..piLevel2..")", -- String on the table
								piLevel.." - "..piLevel2, -- Item Level of Item they linked
								"-", -- Attendance
								"-", -- Item Density
								"-", -- Last Item
								0, -- Number of Votes For
								0, -- Number of Votes Against
								"None", -- Initialize "No Vote"
								{}, -- No one has voted for this person, so initialize that 
								LootCouncil_Browser.getGuildRank(name), -- Get their guild rank name
								2, -- They linked 2 items
								psLink, -- first item link
								psLink2, -- second item link
								spec -- and their spec
							})
							LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
						else -- Else they only linked 1 item or this isn't a special slot
							if LootCouncil_debugMode == false then -- send them a message saying we got the item
								LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
							end
							table.insert(LootCouncil_Browser.Elects, {
								name, -- Player Name
								psLink.." ("..piLevel..")", -- String on the table
								piLevel, -- Item Level of Item they linked
								"-", -- Attendance
								"-", -- Item Density
								"-", -- Last Item
								0, -- Number of Votes For
								0, -- Number of Votes Against
								"None", -- Initialize "No Vote"
								{}, -- No one has voted for this person yet, so initialize that
								LootCouncil_Browser.getGuildRank(name), -- get their guild rank name
								1, -- they linked 1 item
								psLink, -- first item
								nil, -- no second item, so hold nil
								spec -- and their spec
							})
							LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
						end


						LootCouncil_Browser.Update(); -- AND WE'RE DONE! UPDATE THE FRAME!
					end
				else -- They didn't send items that fit the slots we were considering
					if LootCouncil_debugMode == false then
						LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["BAD_SLOT"], itemRunning), "WHISPER", nil, name);
					end
				end
			end ]]
			end
		end
	end
end

------------------   -------------------
-- Triggered by the host sending us a new item entry
-------------------------------------------------------
function LootCouncil_Browser.receiveItemEntry(name, itemString)
	if auctionRunning==true and (itemRunning or LootCouncil_awaitingItem) and name and itemString and isInitiator == false then -- Make sure we have an auction running and we're not the initiator
		LootCouncil_Browser.printd("new entry coming in: " .. itemString);
		local psName, psLink, piRarity, piLevel, piMinLevel, psType, psSubType, piStackCount, pthisItemEquipLoc = GetItemInfo(itemString); -- Get better info
		local indexOfPlayer = LootCouncil_Browser.alreadyLinkedItem(name, itemString) -- see if they've already linked an item
		if indexOfPlayer > 0 and LootCouncil_Browser.IsSelected(indexOfPlayer) then -- If they're selected, we have to reselect them (which also means they're already in the table)
			LootCouncil_Browser.SelectEntry(indexOfPlayer)
		end
		if  indexOfPlayer == 0 then -- If we didn't find them in the table
			LootCouncil_Browser.printd("trying to insert");
			if piLevel then
				table.insert(LootCouncil_Browser.Elects, {
					name, -- Player Name
					psLink.." ("..piLevel..")",
					piLevel, -- Item Level of Item they linked
					"-", -- Attendance
					"-", -- Item Density
					"-", -- Last Item
					0, -- Number of Votes For
					0, -- Number of Votes Against
					"None", -- Initialize "No Vote"
					{},
					LootCouncil_Browser.getGuildRank(name),
					1,
					psLink,
					nil,
					"-"
				})
			else
				table.insert(LootCouncil_Browser.Elects, {
					name, -- Player Name
					"Loading..", -- should be this: psLink.." ("..piLevel..")"
					0, -- Item Level of Item they linked
					"-", -- Attendance
					"-", -- Item Density
					"-", -- Last Item
					0, -- Number of Votes For
					0, -- Number of Votes Against
					"None", -- Initialize "No Vote"
					{},
					LootCouncil_Browser.getGuildRank(name),
					1,
					nil, -- should be psLink (item link)
					nil,
					"-"
				})
				
				-- DO SOMETHING to update
				
				--STRUCTURE:
				-- 1 - Name
				-- 2 - the NUMBER (1 or 2)
				-- 3 - the Link to Get
				
				clientEntryWaiting = true;
				table.insert(clientEntryPings, {
							 name,
							 1,
							 itemString
							 });
				sanityCheck = 0;
				MainFrame:SetScript("OnUpdate", MainFrame_OnUpdate);
				
			end
			
			LootCouncil_Browser.Update();
		end
		
	end
end

------------------ receiveSecondEntry -------------------
-- Triggered by the host sending us a new item entry that's flagged as a SECOND entry
-------------------------------------------------------
function LootCouncil_Browser.receiveSecondEntry(name, itemString)
	if auctionRunning==true and (itemRunning or LootCouncil_awaitingItem) and name and itemString and isInitiator == false then -- Make sure we have an auction running
		local psName, psLink, piRarity, piLevel, piMinLevel, psType, psSubType, piStackCount, pthisItemEquipLoc = GetItemInfo(itemString); -- Get better info
		if psName then
			for ci=1, MAX_ENTRIES do -- It's the second item, so they SHOULD be in the table. Start looping
				theEntry = LootCouncil_Browser.Elects[ci]; -- select them out
				if theEntry and theEntry[1]==name then -- if we found them, then start updating
					local notFound = true;
					for ci = 1, #clientEntryPings do
						local theInfo = clientEntryPings[ci];
						if theInfo[1] == name then
							theInfo[4] = itemString;
							notFound = false;
							break;
						end
					end
					if notFound then	
						theEntry[2] = theEntry[2].."\n"..psLink.." ("..piLevel..")";
						theEntry[3] = theEntry[3].." - "..piLevel;
						theEntry[12] = 2;
						theEntry[14] = itemString;
					end
					if LootCouncil_Browser.IsSelected(ci) then
						LootCouncil_Browser.updateVoteSelectionText()
					end
					break;
				end
			end
			LootCouncil_Browser.Update();
		else
			local notFound = true;
			for ci = 1, #clientEntryPings do
				local theInfo = clientEntryPings[ci];
				if theInfo[1] == name then
					theInfo[4] = itemString;
					notFound = false;
				end
			end
			
			if notFound then
				for ci=1, MAX_ENTRIES do -- It's the second item, so they SHOULD be in the table. Start looping
					theEntry = LootCouncil_Browser.Elects[ci]; -- select them out
					if theEntry and theEntry[1]==name then -- if we found them, then start updating
						clientEntryWaiting = true;
						table.insert(clientEntryPings, {
							 name,
							 "-",
							 theEntry[13],
							 itemString
							 });
						sanityCheck = 0;
						MainFrame:SetScript("OnUpdate", MainFrame_OnUpdate);	
						break;
					end
				end
			end
		end
	end
end



-------- NOT USED ---------------------------------------
-- NOT USED!!!! Coming in the Full version of LootCouncil
---------------------------------------------------------
function LootCouncil_Browser.updatePlayerData(other)
	local name, attendance, density, lastItem = strsplit(" ", other, 4)
	theRest = more;
	if LootCouncil_Browser.playerInData(name, attendance, density, lastItem) == false then
		table.insert(LootCouncil_Browser.Data, {
			name,
			"-",
			"-",
			"-"
		})
	end
	LootCouncil_Browser.Update()
end


------------- update--------------------------------
-- Updates all the texts and such in the table frame 
-- Looks more complicated than it is
----------------------------------------------------
function LootCouncil_Browser.Update()
	local totalEntry = 0;
	for ci = 1, MAX_ENTRIES do -- Loop through each row
		
		local entry = LootCouncil_Browser.Elects[ci] -- Pull the entry row
		local frame = _G["EntryFrameEntry"..ci] -- Get the physical row frame
		if entry and frame then -- if we found both of those, GREAT!
			totalEntry = totalEntry + 1;
			if entry[12] == 2 then -- if they have 2 items, we need 2 hover areas
				_G[frame:GetName().."ItemFrame2"]:Show()
			else -- Otherwise, we just need 1 hover area
				_G[frame:GetName().."ItemFrame2"]:Hide()
			end
			
			if isSelfVoting == false and entry[1] == LootCouncil_Browser.getUnitName("player") then -- If you CANT vote for yourself, then prohibit it
				_G[frame:GetName().."AgainstButton"]:Hide() -- Also prohibited at voting level just to make sure no cheating
				_G[frame:GetName().."CancelButton"]:Hide() -- See update votes for that though
				_G[frame:GetName().."ForButton"]:Hide()
			else -- If you can vote for yourself, show the buttons
				_G[frame:GetName().."CancelButton"]:Show()
				_G[frame:GetName().."ForButton"]:Show()
				
				if isSingle == false then -- HOLD IT HERE THOUGH! Against button is hidden if we're on single vote mode, so check for that
					_G[frame:GetName().."AgainstButton"]:Show()
				else
					_G[frame:GetName().."AgainstButton"]:Hide()
				end
			end
			frame:Show() -- Make sure we're showing the frame (since nil entries were hidden)
			_G[frame:GetName().."CharName"]:SetText(entry[1]) -- Start setting data

			local pClass, eClass = UnitClass(entry[1])
			if (pClass ~= nil) then
				local cColor = RAID_CLASS_COLORS[eClass]
				_G[frame:GetName().."CharName"]:SetTextColor(cColor["r"], cColor["g"], cColor["b"]) -- Start setting data
			end

			_G[frame:GetName().."Item"]:SetText(entry[2])
			_G[frame:GetName().."Itemlvl"]:SetText(entry[11])
			_G[frame:GetName().."Spec"]:SetText(entry[15])
			if (isSingle == false) then -- If it's not single, we can simplify the +/- thing that's normally there
				_G[frame:GetName().."VotesTotal"]:SetText("     "..entry[7].." / "..entry[8].."     ( "..(entry[7]-entry[8]).." ) ")
			else
				_G[frame:GetName().."VotesTotal"]:SetText(""..entry[7])
			end
			--getglobal(frame:GetName().."YourVote"):SetText(entry[9])
			--Above is OLD. Using Localization now.
			if entry[9] and entry[9] == "None" then
				_G[frame:GetName().."YourVote"]:SetText(LootCouncilLocalization["NONE"])
			elseif entry[9] and entry[9] == "For" then 
				_G[frame:GetName().."YourVote"]:SetText(LootCouncilLocalization["FOR"])
			elseif entry[9] and entry[9] == "Against" then
				_G[frame:GetName().."YourVote"]:SetText(LootCouncilLocalization["AGAINST"])
			else
				_G[frame:GetName().."YourVote"]:SetText(LootCouncilLocalization["NONE"])
			end
			if entry.isSelected then
				_G[frame:GetName().."BG"]:Show()
			else
				_G[frame:GetName().."BG"]:Hide()
			end
		else -- IF we couldn't find the entry or frame, hide it
			frame:Hide()
		end
	end -- End loop through entries
	
	if awardShow and LootCouncil_Browser.MLI == true and selection and selection.isSelected then
		AwardButton:Show()
	else
		AwardButton:Hide()
	end
	LootCouncil_Browser.controlLootFrameSize(totalEntry)

			
end


------------- selectEntry----------------------------
-- Selects the row so you can see more data at the bottom
----------------------------------------------------
function LootCouncil_Browser.SelectEntry(id)
	if selection then -- Clear out our selection if we have someone selected now
		for ci = 1, MAX_ENTRIES do
			_G["EntryFrameEntry"..ci .."BG"]:Hide()
		end
		selection.isSelected = nil
	end
	selection = LootCouncil_Browser.Elects[id] -- then select it
	selection.isSelected = true; -- If it's selected, mark it so!
	if selection then -- If we found a selection thing (you didn't select an empty row)
		-- Initialize variables
		local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture;
		local sName2, sLink2, iRarity2, iLevel2, iMinLevel2, sType2, sSubType2, iStackCount2, thisItemEquipLoc2, thisItemTexture2;
		if selection[13] then -- if they have the first item link, get its info
			sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(selection[13]);
		end
		if selection[14] then -- if they have 2 item links, then get the second's info
			sName2, sLink2, iRarity2, iLevel2, iMinLevel2, sType2, sSubType2, iStackCount2, thisItemEquipLoc2, thisItemTexture2 = GetItemInfo(selection[14]);
		end
		
		if isInitiator == true then -- If we're the initiator, we have the power to remove, so show the button
			RemoveButton:Show()
		else
			RemoveButton:Hide()
		end
		CurrentSelectionLabel:Show() -- Show the label
		CurrentSelectionName:SetText(selection[1]) -- show who we're selecting
		CurrentSelectionName:Show() -- show the name
		if selection[12] == 1 then -- if they have ONE item

			CurrentSelectionLink:SetText(selection[2])
			CurrentSelectionLink:Show()
			if thisItemTexture then
				CurrentSelectionTexture:SetTexture(thisItemTexture);
			end
	-- LOOK HERE		
			
			ClearSelectionButton:Show()
			
			CurrentSelectionTexture:Show()
			CurrentSelectionHover:Show()
			
			DualItemTexture1:Hide();
			DualItemTexture2:Hide();
			DualItem1:Hide()
			DualItem2:Hide()
			CurrentSelectionHover2:Hide();
		elseif selection[12] == 2 then -- if they have TWO items
			CurrentSelectionLink:Hide()
			DualItemTexture1:SetTexture(thisItemTexture);
			DualItemTexture2:SetTexture(thisItemTexture2);
			DualItemTexture1:Show();
			DualItemTexture2:Show();
			CurrentSelectionHover:Show()
			CurrentSelectionHover2:Show()
			DualItem1:SetText(sLink.." ("..iLevel..")")
			DualItem2:SetText(sLink2.." ("..iLevel2..")")
			DualItem2:Show()
			DualItem1:Show()
			CurrentSelectionTexture:Hide()
		end
			ClearSelectionButton:Show()
		if isPrivate == false then -- If it's NOT private, then we can show the labels
			VotesForLabel:Show()
			VotesFor:Show()
			VotesAgainstLabel:Show()
			VotesAgainst:Show()
			LootCouncil_Browser.updateVoteSelectionText()
		end
		LootCouncil_Browser.Update()
	else
		LootCouncil_Browser.ClearSelection()
	end
end


------------- updateVoteSelectionText----------------------------
-- If you have someone selected, this updates the text at the bottom
-----------------------------------------------------------------
function LootCouncil_Browser.updateVoteSelectionText()
	if isPrivate == false then -- If we're not in private mode, then lets get to work!
		local absoluteVotesFor = ""; -- Initialize the for string
		local absoluteVotesAgainst = ""; -- Initialize the against string
		local forIndex = 1;
		local againstIndex = 1;
		local theVotes
		if selection then -- If we have something selected
			theVotes = selection[10]; -- the votes is this area of our selection
		else -- If we don't have anything selected, then how did we get here??? GET OUT!
			return
		end
		for ci = 1, MAX_VOTERS do -- Loop through all the voters
			local singularVoter = theVotes[ci] -- get the individual vote
			if singularVoter then -- if we found a vote
				if singularVoter[2] == "For" then -- and it's a for vote
					if forIndex > 1 then -- and we have a higher then one Index (so we can add a comma)
						absoluteVotesFor = ""..absoluteVotesFor..", "
					end
					absoluteVotesFor = absoluteVotesFor..""..singularVoter[1]; -- Then add their name
					if singularVoter[3] ~= "No Reason" then -- If there's a reason, then add it in parenthases
						absoluteVotesFor = absoluteVotesFor.." ("..singularVoter[3]..")";
					end
					forIndex = forIndex+1 -- increment the index
				elseif singularVoter[2] == "Against" then -- if it's an against vote, do basically the same thing
					if againstIndex > 1 then
						absoluteVotesAgainst = ""..absoluteVotesAgainst..", "
					end
					absoluteVotesAgainst = absoluteVotesAgainst..""..singularVoter[1];
					if singularVoter[3] ~= "No Reason" then
						absoluteVotesAgainst = absoluteVotesAgainst.." ("..singularVoter[3]..")";
					end
					againstIndex = againstIndex+1
				end
			end
		end
		
		if forIndex > 1 then -- If there was at least 1 for vote, then display it
			VotesFor:SetText(absoluteVotesFor)
		else
			VotesFor:SetText(LootCouncilLocalization["NO_VOTES_FOR"])
		end
		
		if againstIndex > 1 then -- If there was at least 1 against vote, then display it.
			VotesAgainst:SetText(absoluteVotesAgainst)
		else
			VotesAgainst:SetText(LootCouncilLocalization["NO_VOTES_AGAINST"])
		end
	end
end

------------- clearSelection-------------------------------------
-- If you select no one, hide all the stuff at the bottom
-----------------------------------------------------------------
function LootCouncil_Browser.ClearSelection()
	if selection then
		for ci = 1, MAX_ENTRIES do
			_G["EntryFrameEntry"..ci .."BG"]:Hide()
		end
		selection.isSelected = nil
	end
	selection = nil;
	RemoveButton:Hide()
	ClearSelectionButton:Hide()
	CurrentSelectionLink:Hide()
	CurrentSelectionTexture:Hide()
	CurrentSelectionHover:Hide()
	CurrentSelectionLabel:Hide()
	CurrentSelectionName:Hide()
	CurrentSelectionItemLevelLabel:Hide()
	CurrentSelectionItemLevel:Hide()
	VotesForLabel:Hide()
	VotesFor:Hide()
	VotesAgainstLabel:Hide()
	VotesAgainst:Hide()
	DualItemTexture1:Hide();
	DualItemTexture2:Hide();
	DualItem1:Hide()
	DualItem2:Hide()
	LootCouncil_Browser.Update()
end

------------- isSelected ----------------------------------------
-- Tests if they're selected or not.
-----------------------------------------------------------------
function LootCouncil_Browser.IsSelected(id)
	if selection then
		return LootCouncil_Browser.Elects[id] == selection
	else
		return false
	end
end

------------- toolMouseOver ----------------------------------------
-- Fires when you mouse over the first itemlink in the voting window
-----------------------------------------------------------------
function LootCouncil_Browser.toolMouseOver(id)
	local entry = LootCouncil_Browser.Elects[id];
	if entry then
		GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
		if entry[13] then
			GameTooltip:SetHyperlink(entry[13])
		else
			GameTooltip:SetText("Loading...");
		end
		GameTooltip:Show()
	end
end

------------- toolMouseOverDual ----------------------------------------
-- Fires when you mouse over the SECOND itemlink in the voting window
-----------------------------------------------------------------
function LootCouncil_Browser.toolMouseOverDual(id)
	local entry = LootCouncil_Browser.Elects[id];
	if entry then
		if entry[12] == 2 then
			GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
			if entry[14] then
				GameTooltip:SetHyperlink(entry[14])
			else
				GameTooltip:SetText("Loading...");
			end
			GameTooltip:Show()
		end
	end
end

------------- toolMouseOver ----------------------------------------
-- Fires when you leave the itemlinks in the voting window
-----------------------------------------------------------------
function LootCouncil_Browser.toolMouseLeave()
	GameTooltip:Hide()
end

------------- updateVotes ----------------------------------------
-- Basically completely manages votes
-----------------------------------------------------------------
function LootCouncil_Browser.updateVotes(sender, char, vote, reason)
	if isSelfVoting == true or sender ~= char then -- Make sure NO ONE is voting for themselves when it's not allowed
		if isInitiator == false then -- If we are NOT the initiator
			if sender == LootCouncil_Browser.getUnitName("player") then -- Check if we're casting the vote
				-- If we are, send it to the initiator
				SendAddonMessage("L00TCOUNCIL", "vote"..cmdDelim..char..voteDelim..LootCouncil_Browser.getUnitName("player")..voteDelim..vote..voteDelim..reason, "WHISPER", theInitiator);
			end
		elseif LootCouncil_Browser.isValidVoter(sender) == true then -- If we ARE the initiator, make sure this person is ALLOWED to vote
			-- if they are allowed to vote, send it to everyone else
			LootCouncil_Browser.sendGlobalMessage("vote"..cmdDelim..char..voteDelim..sender..voteDelim..vote..voteDelim..reason, sender);
		end
		if LootCouncil_Browser.isValidVoter(sender) == true then -- make sure they're a valid voter
		
			-- There are TWO completley different logic structures here
			-- The first records MULTIPLE votes
			-- The second forces you to keep ONE vote
			
			if isSingle == false then
			
				-- THIS SECTION MANAGES MULTIPLE VOTES
				-- So every officer can cast as many votes as they want
				
				for ci = 1, MAX_ENTRIES do -- Loop through all people on the table
					local theEntry = LootCouncil_Browser.Elects[ci]; -- Pull each row
					if theEntry and theEntry[1] and theEntry[1] == char then -- If the row has data in it and it's the character that was voted for
						if sender == LootCouncil_Browser.getUnitName("player") then -- If it's our vote, then update it on the interface
							theEntry[9] = vote;
						end
						local theVotes = theEntry[10] -- Get the current votes
						local found = false; -- Initialize helper variable
						for ki = 1, MAX_VOTERS do -- Loop through all the potential voters
							if theVotes[ki] then -- If this voter exists
								local singularVoter = theVotes[ki] -- get the individual voter
								if singularVoter and singularVoter[1] == sender then -- check To see if it's the person who cast their vote
									if found > 0 then -- if we've found this person twice, then there's a problem.........
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("HIGHLY LIKELY AN ERROR OCCURED. END CONSIDERATION AND RESTART VOTING")
										print("Please alert Blacksen on Wowinterface or Curse")
									else
										found = ki --Update helper variable
									end
								end
							end
						end
						if found == false then -- if we didn't find anyone, then they're probably not in the table yet (they haven't voted for this person yet)
							table.insert(theEntry[10], { -- So add them
								sender,
								vote,
								reason
							})
						else -- Otherwise, we did find them
							if vote == "None" then -- If they voted none, take them out of the table
								table.remove(theVotes, ki)
							else -- Otherwise, update their vote
								local singularVoter = theVotes[found]
								singularVoter[2] = vote;
								singularVoter[3] = reason;
							end
						end
						
						-- Now we need to count how many people voted for/against so that we can update the table.
						local numFor = 0; -- Count how many are FOR this voter
						local numAgainst = 0; -- Count how many are AGAINST this voter
						for ki = 1, MAX_VOTERS do -- Loop through all the potential voters
							if theVotes[ki] then -- If this voter exists
								local singularVoter = theVotes[ki] -- Get the individual voter
								if singularVoter and singularVoter[2] == "For" then -- Add one if he's for
									numFor = numFor +1;
								elseif singularVoter and singularVoter[2] == "Against" then -- Add one if he's against
									numAgainst = numAgainst + 1;
								end
							end
						end
						theEntry[7] = numFor;
						theEntry[8] = numAgainst;
						if theEntry == selection then -- If this is our current selection
							LootCouncil_Browser.updateVoteSelectionText() -- Then update the text on the table.
						end
					end
				end
			else
			
				-- THIS SECTION MANAGES SINGLE VOTE MODE
				-- So every officer can only vote ONCE
				
				
				if vote == "Against" then -- You can't vote against in single vote mode, so get out of here.
					return
				end
				
				for ci = 1, MAX_ENTRIES do -- Loop through all people on the table
					local theEntry = LootCouncil_Browser.Elects[ci]; -- Pull each row
					if theEntry then -- If we found data in the row
						if sender == LootCouncil_Browser.getUnitName("player") then
							theEntry[9] = "None"
						end
						local theVotes = theEntry[10]; -- pull all the votes
						for ki = 1, MAX_VOTERS do -- loop through all the votes
							if theVotes[ki] then -- if we find a vote
								local singularVoter = theVotes[ki]; -- pull that vote
								if singularVoter and singularVoter[1] == sender then -- if it's the sender
									theVotes[ki] = nil; -- clear their old vote
								end
							end
						end
						
						if vote ~= "None" and theEntry[1] == char then -- If their vote isn't none, then we need to put them into the table here.
							table.insert(theEntry[10], { -- So add them
								sender,
								vote,
								reason
							})
						end
						
						if sender == LootCouncil_Browser.getUnitName("player") and theEntry[1] == char then -- if it's the player's vote, update the text on the table
							theEntry[9] = vote;
						end
							
						
						local numFor = 0; -- Count how many are FOR this voter
						for ki = 1, MAX_VOTERS do -- Loop through all the potential voters
							if theVotes[ki] then -- If this voter exists
								local singularVoter = theVotes[ki] -- Get the individual voter
								if singularVoter and singularVoter[2] == "For" then -- Add one if he's for
									numFor = numFor +1;
								end
							end
						end
						theEntry[7] = numFor;
						theEntry[8] = 0; -- Just to make sure :-D
						if theEntry == selection then -- If this is our current selection
							LootCouncil_Browser.updateVoteSelectionText() -- Then update the text on the table.
						end
					end
				end
			end			
			LootCouncil_Browser.Update()
		end
	end
end

------------- voteToolActivate ----------------------------------
-- Shows the mouseover tooltip for votes.
-----------------------------------------------------------------
function LootCouncil_Browser.voteToolActivate(id)
	if isPrivate == false then -- Make sure we're not in private voting mode
		local entry = LootCouncil_Browser.Elects[id]; -- get this row's data
		local votesFor = {}; -- initialize the votes for
		local votesAgainst = {} -- initialize the votes against
		local forIndex = 1;
		local againstIndex = 1;
		if entry then -- if this row has data in it
			GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR") -- Set the owner of the tooltip
			local theVotes = entry[10];-- pull the votes
			for ci = 1, MAX_VOTERS do -- loop through all the votes
				local singularVoter = theVotes[ci]
				if singularVoter then -- if we find a vote, then update the counts
					if singularVoter[2] == "For" then -- 
						votesFor[forIndex] = ""..singularVoter[1]..": "..singularVoter[3];
						forIndex = forIndex+1
					elseif singularVoter[2] == "Against" then
						votesAgainst[againstIndex] = ""..singularVoter[1]..": "..singularVoter[3];
						againstIndex = againstIndex+1
					end
				end
			end
			if forIndex > 1 then -- If they have for votes, add it to the tooltip
				GameTooltip:AddLine(LootCouncilLocalization["VOTES_FOR"], 1, 1, 1, 1);
				for ci=1,(forIndex-1) do
					GameTooltip:AddLine(votesFor[ci], 1, 1, 1, 1);
				end
				
			end
			
			if againstIndex > 1 then -- if they have against votes, add it to the tooltip
				if forIndex > 1 then -- add a blank line for seperation if they have both for and against votes
					GameTooltip:AddLine(" ", 1, 1, 1, 1);
				end
				GameTooltip:AddLine(LootCouncilLocalization["VOTES_AGAINST"], 1, 1, 1, 1);
				for ci=1,(againstIndex-1) do
					GameTooltip:AddLine(votesAgainst[ci], 1, 1, 1, 1);
				end
			end
			
			if forIndex >1 or againstIndex>1 then -- if they have votes, show it.
				GameTooltip:Show()
			end
		end
	end
end

------------- sendGlobalMessage ---------------------------------
-- sends an addon message to the entire council
-----------------------------------------------------------------
function LootCouncil_Browser.sendGlobalMessage(msg)
	LootCouncil_Browser.printd("Global message: " .. msg);
	for ci = 1, MAX_VOTERS do
		if LootCouncil_Browser.WhisperList[ci] then
			SendAddonMessage("L00TCOUNCIL", msg, "WHISPER", LootCouncil_Browser.WhisperList[ci])
		end
	end
end



-- DO NOT CALL THIS FUNCTION ON YOUR OWN!!! 
-- MAKE SURE YOU UNDERSTAND WHAT IT DOES!!!
------------- sendGlobalMessage ---------------------------------
-- sends an addon message to the entire council
-- EXCEPT FOR THE SENDER
-- it won't send to "sender" because that might result in infinite loopage
-- 
-- sender doesn't need to update their own vote
-----------------------------------------------------------------
function LootCouncil_Browser.sendGlobalMessage(msg, sender)
	LootCouncil_Browser.printd("Global message: " .. msg);
	for ci = 1, MAX_VOTERS do
		if LootCouncil_Browser.WhisperList[ci] and LootCouncil_Browser.WhisperList[ci]~= sender then
			SendAddonMessage("L00TCOUNCIL", msg, "WHISPER", LootCouncil_Browser.WhisperList[ci])
		end
	end
end


------------- translateToSlot ---------------------------------
-- Switches itemEquipLoc to its corresponding slot number
---------------------------------------------------------------
function LootCouncil_Browser.translateToSlot(itemEquipLoc)
	if itemEquipLoc == "" then return 0
	elseif itemEquipLoc == "INVTYPE_AMMO" then return 0
	elseif itemEquipLoc == "INVTYPE_HEAD" then return 1
	elseif itemEquipLoc == "INVTYPE_NECK" then return 2
	elseif itemEquipLoc == "INVTYPE_SHOULDER" then return 3
	elseif itemEquipLoc == "INVTYPE_BODY" then return 4
	elseif itemEquipLoc == "INVTYPE_CHEST" then return 5
	elseif itemEquipLoc == "INVTYPE_ROBE" then return 5
	elseif itemEquipLoc == "INVTYPE_WAIST" then return 6
	elseif itemEquipLoc == "INVTYPE_LEGS" then return 7
	elseif itemEquipLoc == "INVTYPE_FEET" then return 8
	elseif itemEquipLoc == "INVTYPE_WRIST" then return 9
	elseif itemEquipLoc == "INVTYPE_HAND" then return 10
	elseif itemEquipLoc == "INVTYPE_FINGER" then return 11
	elseif itemEquipLoc == "INVTYPE_TRINKET" then return 13
	elseif itemEquipLoc == "INVTYPE_CLOAK" then return 15
	elseif itemEquipLoc == "INVTYPE_WEAPON" then return 16
	elseif itemEquipLoc == "INVTYPE_SHIELD" then return 16
	elseif itemEquipLoc == "INVTYPE_2HWEAPON" then return 16
	elseif itemEquipLoc == "INVTYPE_WEAPONMAINHAND" then return 16
	elseif itemEquipLoc == "INVTYPE_WEAPONOFFHAND" then return 16
	elseif itemEquipLoc == "INVTYPE_HOLDABLE" then return 16
	elseif itemEquipLoc == "INVTYPE_RANGED" then return 18
	elseif itemEquipLoc == "INVTYPE_THROWN" then return 18
	elseif itemEquipLoc == "INVTYPE_RANGEDRIGHT"  then return 18
	elseif itemEquipLoc == "INVTYPE_RELIC" then return 18
	elseif itemEquipLoc == "INVTYPE_TABARD" then return -1
	elseif itemEquipLoc == "INVTYPE_BAG" then return 20
	elseif itemEquipLoc == "INVTYPE_QUIVER" then return 20
	else return -1
	end
end

------------- initiateAbort ---------------------------------
-- Attempt to abort the session
---------------------------------------------------------------
function LootCouncil_Browser.initiateAbort()
	if isInitiator == true then -- if we're the initiator, show a popup message
		LootCouncil_Browser.confirmAbort()
	else
		print("Suggesting to "..theInitiator.." that we abort this loot council session")
		SendAddonMessage("L00TCOUNCIL", "suggestAbort", "WHISPER", theInitiator)
	end
end

------------- Confirm Abort ---------------------------------
-- Triggers confirmation popup
---------------------------------------------------------------
function LootCouncil_Browser.confirmAbort()
	if LootCouncil_Browser.confirmEnd == true and (not (LootCouncil_Browser.itemAwarded)) then
		StaticPopup_Show("LOOT_COUNCIL_CONFIRM_ABORT")
	else
		LootCouncil_Browser.itemAwarded = false;
		LootCouncil_Browser.closeLootCouncilSession()
	end
end

------------- closeLootCouncilSession -----------------------
-- Clears the house cus this loot session is done!
---------------------------------------------------------------
function LootCouncil_Browser.closeLootCouncilSession()
	if isInitiator == true and LootCouncil_debugMode == false then -- if we're the initiator, let people know we're done with this session
		LootCouncil_SendChatMessage("item: "..itemRunning, LootCouncil_Channel);
		currSortIndex = -1
		LootCouncil_Browser.sortTable(6)
		local quickIndex = 1
		for ci=1,MAX_ENTRIES do
			local theEntry = LootCouncil_Browser.Elects[ci];
			local previousEntry = LootCouncil_Browser.Elects[ci-1]
			if theEntry then
				if quickIndex >= 4 then -- If we've already displayed the top 3
					if (previousEntry == nil or ((theEntry[7]-theEntry[8]) < (previousEntry[7]-previousEntry[8]))) then -- Check to see if this person is tied with previous
						break; -- If they aren't tied, then break
					else -- Else they are tied, so show them
						if (theEntry[7]-theEntry[8]) ~= 1 then
							LootCouncil_SendChatMessage("("..quickIndex..") "..theEntry[1]..": "..(theEntry[7]-theEntry[8]).." votes"..LootCouncil_Browser.displayVotes(theEntry), LootCouncil_Channel);
						else
							LootCouncil_SendChatMessage("("..quickIndex..") "..theEntry[1]..": "..(theEntry[7]-theEntry[8]).." vote"..LootCouncil_Browser.displayVotes(theEntry), LootCouncil_Channel);
						end
					end
				else
					if (theEntry[7]-theEntry[8]) ~= 1 then
						LootCouncil_SendChatMessage("("..quickIndex..") "..theEntry[1]..": "..(theEntry[7]-theEntry[8]).." votes"..LootCouncil_Browser.displayVotes(theEntry), LootCouncil_Channel);
					else
						LootCouncil_SendChatMessage("("..quickIndex..") "..theEntry[1]..": "..(theEntry[7]-theEntry[8]).." vote"..LootCouncil_Browser.displayVotes(theEntry), LootCouncil_Channel);
					end
					if quickIndex < 4 then
						quickIndex = quickIndex+1;
					end
				end
			end
		end
				
		LootCouncil_SendChatMessage(LootCouncilLocalization["END_FIRED"], LootCouncil_Channel);
	end
	LootCouncil_Browser.sendGlobalMessage("abort") -- AND TELL EVERYONE WE'RE DONE
	auctionRunning = false; -- we're not running a session anymore
	itemRunning = nil; -- and we have no item running
	isInitiator = false; -- you forefeight your initiator rights
	theInitiator = ""; -- and there is no initiator
	theVote = "";
	voteFor = "";
	suggestedBy = "";
	selection = nil;
	councilList = " ";
	councilList = " ";
	councilNum = 1;
	LootCouncil_Browser.Data = {}
	LootCouncil_Browser.Elects = {}
	LootCouncil_Browser.Votes = {}
	LootCouncil_Browser.WhisperList = {}
	awardShow = false;
	LootCouncil_Browser.resetConsideration()
	LootCouncil_Browser.Update()
	
end

function LootCouncil_Browser.displayVotes(entry)
	if entry then
		local theVotes = entry[10];-- pull the votes
		local votesFor = ""; -- initialize the votes for
		local votesAgainst = ""; -- initialize the votes against
		local printString = " - ";
		local forIndex = 1;
		local againstIndex = 1;
		for ci = 1, MAX_VOTERS do -- loop through all the votes
			local singularVoter = theVotes[ci]
			if singularVoter then -- if we find a vote, then update the counts
				if singularVoter[2] == "For" then -- 
					if forIndex>1 then
						votesFor = votesFor..", "
					end
					votesFor = votesFor..singularVoter[1]
					forIndex = forIndex+1
				elseif singularVoter[2] == "Against" then
					if againstIndex > 1 then
						votesAgainst = votesAgainst..", "
					end
					votesAgainst = votesAgainst..singularVoter[1];
					againstIndex = againstIndex+1
				end
			end
		end
		if forIndex > 1 then -- If they have for votes, add it to the tooltip
			printString = printString..LootCouncilLocalization["VOTES_FOR"].." "..votesFor
		end
		
		if againstIndex > 1 and isSingle == false then -- if they have against votes
			if forIndex > 1 then
				printString = printString.." - ".. LootCouncilLocalization["VOTES_AGAINST"].." "..votesAgainst
			else
				printString = printString..LootCouncilLocalization["VOTES_AGAINST"].." "..votesAgainst
			end
		end
		if printString == " - " then
			return ""
		else
			return printString
		end
	else
		return ""
	end
end

------------- voteDescTooltip -----------------------
-- Simply shows "For", "Against", or "Cancel" tooltip
------------------------------------------------------
function LootCouncil_Browser.voteDescTooltip(voteStr)
	GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
	GameTooltip:SetText(voteStr)
	GameTooltip:Show()
end

------------- isValidVoter -----------------------
-- Checks if they're a valid voter
--------------------------------------------------
function LootCouncil_Browser.isValidVoter(name)
	if name == "player" or name == LootCouncil_Browser.getUnitName("player") or name == theInitiator then -- ourselves are always a valid voter. The initiator is too
		return true
	else
		for ci = 1, MAX_VOTERS do -- else loop through the whisper list
			if LootCouncil_Browser.WhisperList[ci] and LootCouncil_Browser.WhisperList[ci] == name then -- if they're there
				return true -- then return
			end
		end
		GuildRoster();
		for ci = 1, GetNumGuildMembers() do -- otherwise, start looping through the guild list
			--local theName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
			local theName, rank, rankIndex = LootCouncil_Browser.getCharInfo(ci);
			if name == theName then -- if we find them
				if (rankIndex+1) <= (LootCouncil_minRank + 0.1) then -- check if they're above the minimum rank
					return true; -- If they are, return 1
				else
					return false; -- If they aren't, return 0
				end
			end
		end
	end
	LootCouncil_Browser.printd("Error in voting: "..name.." - "..theName)
	return 0 -- They weren't in guild or on the whisper list, so trash um
end

------------- manualAdd -----------------------
-- Manually adds a player through the /lc add command
--------------------------------------------------
function LootCouncil_Browser.manualAdd(thePlayer, theItem) 
	if isInitiator == true and itemRunning then
		LootCouncil_Browser.newEntry(thePlayer, theItem)
	end
	
	if not itemRunning then
		print("There currently is no loot council in session. Start one before adding.");
	elseif isInitiator == false then
		print("You must be the initiator in order to manually add someone");
	end
end

------------- removeSelection -----------------------
-- Triggered by remove button
-- Removes them from the consideration
--------------------------------------------------
function LootCouncil_Browser.RemoveSelection()
	if isInitiator == true then
		LootCouncil_Browser.sendGlobalMessage("remove "..selection[1]);
		LootCouncil_Browser.removePlayer(selection[1]);
		LootCouncil_Browser.ClearSelection()
		LootCouncil_Browser.Update()
	end
end

------------- removePlayer --------------------
-- Actually does the removal
--------------------------------------------------
function LootCouncil_Browser.removePlayer(playerName)
	if selection and selection[1] == playerName then -- If they're our selection, clear the selection
		LootCouncil_Browser.ClearSelection()
	end
	local found = false; -- initialize helper variable
	for ci = 1, (MAX_ENTRIES-1) do -- Loop through all people on the table EXCEPT the last row!
		if found == false then
			local theEntry = LootCouncil_Browser.Elects[ci]; -- Pull each row
			if theEntry[1] == playerName then -- if we find them
				found=true; -- update that we found them
				LootCouncil_Browser.Elects[ci] = LootCouncil_Browser.Elects[ci+1]; -- AND START COPYING UP
			end
		else
			LootCouncil_Browser.Elects[ci] = LootCouncil_Browser.Elects[ci+1]; -- If we HAVE found them, COPY UP
		end
	end
	
	if (found == true) then -- Assuming we've found them by now
		LootCouncil_Browser.Elects[MAX_ENTRIES] = nil; -- clear the last entry (it got pulled down in the for loop)
	else
		local theEntry = LootCouncil_Browser.Elects[MAX_ENTRIES]; -- otherwise, I'm worried we didn't find them
		if theEntry[1] == playerName then -- so check if they're in the final entry
			LootCouncil_Browser.Elects[MAX_ENTRIES] = nil;
		end
	end
	LootCouncil_Browser.Update()
end

------------- getGuildRank --------------------
-- Loop through to pull the guild rank text for the table
--------------------------------------------------
function LootCouncil_Browser.getGuildRank(playerName)
	GuildRoster();
	--print(playerName)
	for ci=1, GetNumGuildMembers(true) do
		local name, rank = LootCouncil_Browser.getCharInfo(ci)
		if name == playerName then
			return rank
		end
	end
	
	return "N/A"
end

------------- getGuildRankNum --------------------
-- Gets the actual rank number for the player
--------------------------------------------------
function LootCouncil_Browser.getGuildRankNum(playerName)
	GuildRoster();
	--print(playerName)
	if playerName then
		for ci=1, GetNumGuildMembers(true) do
			local name, rank, rankIndex = LootCouncil_Browser.getCharInfo(ci)
			if name == playerName then
				return rankIndex
			end
		end
	end
	
	return 11
end

------------- getLowestItemLevel -----------------
-- Used in sorting
-- Returns the lower of 2 item levels
--------------------------------------------------
function LootCouncil_Browser.getLowestItemLevel(entry)
	if entry then
		if entry[12] == 1 then
			local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(entry[13])
			return itemLevel
		elseif entry[12] == 2 then
			local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(entry[13])
			local itemName2, itemLink2, itemRarity2, itemLevel2 = GetItemInfo(entry[14])
			if itemLevel == nil or itemLevel2 == nil then
				print("NIL WARNING!!!")
			end
			if itemLevel >= itemLevel2 then
				return itemLevel2
			else
				return itemLevel
			end
		else
			return -131
		end
	end
	return -131
end
			
------------- sortTable --------------------------
-- Sorts the table when you click on a header
--------------------------------------------------
function LootCouncil_Browser.sortTable(id)
	if currSortIndex == id then -- if we're already sorting this one
		if sortMethod == "asc" then -- then switch the order
			sortMethod = "desc"
		else
			sortMethod = "asc"
		end
	elseif id then -- if we got a valid id
		currSortIndex = id -- then initialize our sort index
		sortMethod = "asc" -- and the order we're sorting in
	end
	
	if (id == 1) then -- Char Name sorting (alphabetically)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				return v1 and v1[1] > v2[1]
			else
				return v1 and v1[1] < v2[1]
			end
		end)
	elseif (id == 3) then -- Guild Rank sorting (numerically)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				return (v1 and LootCouncil_Browser.getGuildRankNum(v1[1]) > LootCouncil_Browser.getGuildRankNum(v2[1]))
			else
				return (v1 and LootCouncil_Browser.getGuildRankNum(v1[1]) < LootCouncil_Browser.getGuildRankNum(v2[1]))
			end
		end)
	elseif (id == 6) then -- Total Votes sorting (numerically)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				return v1 and (v2 == nil or (v1[7]-v1[8]) < (v2[7]-v2[8]))
			else
				return v1 and (v2 == nil or (v1[7]-v1[8]) > (v2[7]-v2[8]))
			end
		end)
	elseif (id == 8) then -- Your Vote sorting (For > None > Against)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				if v1 == nil then
					return false
				end
				if v2 == nil then
					return true
				end
				if v1[9] == v2[9] then
					return false
				end
				if v1[9] == "Against" then
					return true
				end
				if v1[9] == "None" and v2[9]=="For" then
					return true
				end
				return false
			else
				if v1 == nil then
					return false
				end
				if v2 == nil then
					return true
				end
				if v1[9] == v2[9] then
					return false
				end
				if v1[9] == "For" then
					return true
				end
				if v1[9] == "None" and v2[9]=="Against" then
					return true
				end
				return false
			end
		end)
	elseif (id == 2) then -- Item Level Sorting (lowest item level at the top - largest upgrade so to speak)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				return ((v1 ~= nil) and (v2 == nil or ((LootCouncil_Browser.getLowestItemLevel(v1) ~= -131) and (LootCouncil_Browser.getLowestItemLevel(v1) > LootCouncil_Browser.getLowestItemLevel(v2)))))
			else
				return ((v1 ~= nil) and (v2 == nil or ((LootCouncil_Browser.getLowestItemLevel(v1) ~= -131) and (LootCouncil_Browser.getLowestItemLevel(v1) < LootCouncil_Browser.getLowestItemLevel(v2)))))
			end
		end)
	elseif (id == 11) then -- Spec sorting (S > M > O > -)
		table.sort(LootCouncil_Browser.Elects, function(v1, v2)
			if sortMethod == "desc" then
				if v1 == nil then
					return false
				end
				if v2 == nil then
					return true
				end
				if v1[15] == v2[15] then
					return false
				end
				if v1[15] == "-" then
					return true
				end
				if v1[15] == "O" and v2[15]~="-" then
					return true
				end
				if v1[15] == "M" and v2[15]~="O" and v2[15]~="-" then
					return true
				end
				return false;
			else
				if v1 == nil then
					return false
				end
				if v2 == nil then
					return true
				end
				if v1[15] == v2[15] then
					return false
				end
				if v1[15] == "S" then
					return true
				end
				if v1[15] == "M" and v2[15]~="S" then
					return true
				end
				if v1[15] == "O" and v2[15]~="M" and v2[15]~="S" then
					return true
				end
				return false;
			end
		end)
	end
	
	
	LootCouncil_Browser.Update()
end

------------- updateSpec --------------------------
-- updates a player's spec when the initiator tells us too
--------------------------------------------------
function LootCouncil_Browser.updateSpec(player, spec)
	for ci=1, MAX_ENTRIES do --Loop through the entires
		local theEntry = LootCouncil_Browser.Elects[ci]; --Pull the row
		if theEntry and theEntry[1] == player then -- If this entry is the player we care about
			theEntry[15] = spec; -- Then add their spec
			LootCouncil_Browser.Update()
			break;
		end
	end
end

------------- controlLootFrameSize ---------------
-- Controls the size of the loot frame
--------------------------------------------------
function LootCouncil_Browser.controlLootFrameSize(totalEntry)
	local proposed = (totalEntry+2) * 24;
	local move = totalEntry - oldEntry;
	if proposed > MIN_SIZE then
		MainFrame:SetHeight(240+proposed);
		EntryFrame:SetHeight(proposed);
	else
		MainFrame:SetHeight(240+MIN_SIZE);
		EntryFrame:SetHeight(MIN_SIZE);
	end

	oldEntry = totalEntry;
end

function MainFrame_OnUpdate(self, elapsed)
	if (LootCouncil_awaitingItem or entryLinkWaiting or clientEntryWaiting) and (sanityCheck < 100) then -- If we are waiting on an item and we aren't going insane, proceed
		self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed; -- update the time for throttling
		if (self.TimeSinceLastUpdate > .4) then -- if less than .4 seconds
			sanityCheck = sanityCheck + 1; -- increase our insanity
			LootCouncil_Browser.printd("fired"); -- Debug that we're firing OnUpdate
			if LootCouncil_awaitingItem then  -- If a council member is awaiting the MAIN item (the item being considered)
				_G["LootCouncil_Scan"]:ClearLines() -- Clear invisible tooltip
				_G["LootCouncil_Scan"]:SetHyperlink(dataRequest) -- Force server to respond to real data request
				local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(dataRequest); -- Poll for cached info
				if sLink then -- If we got it, start setting information, otherwise we try again!
					itemRunning = sLink;
					LootCouncil_awaitingItem = false; -- Switch the flag
					if thisItemTexture then
						CurrentItemTexture:SetTexture(thisItemTexture); -- Set the texture of the icon box
	
					else
						CurrentItemTexture:SetTexture("Interface\InventoryItems\WoWUnknownItem01");
					end
					CurrentItemTexture:Show(); -- Open up the icon box	
					AbortButton:Show(); -- Show the Abort Button
					
					if iLevel then
						CurrentItemLvl:SetText(iLevel); -- Show the Item Level
					else
						CurrentItemLvl:SetText("...");
					end
					
					if sLink then
						CurrentItemLink:SetText(sLink); -- Set the item link for color and such
					else
						CurrentItemLink:SetText(LootCouncilLocalization["LOADING"]);
					end
				end
			end 
			
			if entryLinkWaiting then -- If the initiator is waiting on the entry
			--	LootCouncil_Browser.printd("entrylinkwaiting");
				if #entryPings == 0 then -- If the size of our queue is 0, then we're done!
					entryLinkWaiting = false;
				else -- Otherwise, stuff is still in our queue
					for ci = 1, #entryPings do -- Start looping
					--	LootCouncil_Browser.printd(ci);
						local theInfo = entryPings[ci]; -- Get the element in our queue
						local actualItemString = theInfo[3]; -- Load the information for the main item
					--	LootCouncil_Browser.printd(actualItemString);
						local actualItemString2 = theInfo[4]; -- Load the information for the secondary item (could be nil)
						_G["LootCouncil_Scan"]:ClearLines() -- Clear invisible tooltip
						_G["LootCouncil_Scan"]:SetHyperlink(actualItemString) -- Force server to respond to real data request
						local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(actualItemString); -- Poll for cached info
						if actualItemString2 then -- If we have a second item, do the same thing
							_G["LootCouncil_Scan"]:ClearLines()
							_G["LootCouncil_Scan"]:SetHyperlink(actualItemString2)
							local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(actualItemString2);
						end
					end
					
					-- AT THIS POINT, we have asked the server for the information. It's either in our cache or it isn't.
					-- However, adding the information would be way too massive for this function, so we pass it off.
					-- addNewEntry2 will dequeue items that now have their information present
					
					local totalNum = #entryPings; -- Get the total number
					
					for ci = 1, #entryPings do -- Backwards loop (no lua decrement -- sadface :( )
						if isInitiator then -- Brief sanity check... How we would get to this point without this firing is beyond me.
							LootCouncil_Browser.addNewEntry2(totalNum - ci + 1)
						else
							
						end
					end
				end
								-- we're clear
			end
			
			if clientEntryWaiting then -- If the council members are waiting entry information
					LootCouncil_Browser.printd("checking client entries");
					if #clientEntryPings == 0 then -- Check our queue. If it's empty, we're done!
						clientEntryWaiting = false;
					else
						local backIndex = #clientEntryPings; -- Start looping BACKWARDS!
						while backIndex > 0 do -- BACKWARDS YES!
							LootCouncil_Browser.printd("entry # " .. backIndex) -- Position in the queue
							local theInfo = clientEntryPings[backIndex]; -- Get this line
							local name = theInfo[1]; -- Get this name
							LootCouncil_Browser.printd("Player name " .. name);
							local actualItemString = theInfo[3]; -- And the item links
							local actualItemString2 = theInfo[4];
							
							-- Poll the server, force item tooltips.
							_G["LootCouncil_Scan"]:ClearLines()
							_G["LootCouncil_Scan"]:SetHyperlink(actualItemString)
							local sName, sLink, iRarity, iLevel, iMinLevel, sType, sSubType, iStackCount, thisItemEquipLoc, thisItemTexture = GetItemInfo(actualItemString);
							local sName2, sLink2, iRarity2, iLevel2, iMinLevel2, sType2, sSubType2, iStackCount2, thisItemEquipLoc2, thisItemTexture2;
							if actualItemString2 then
								_G["LootCouncil_Scan"]:ClearLines()
								_G["LootCouncil_Scan"]:SetHyperlink(actualItemString2)
								sName2, sLink2, iRarity2, iLevel2, iMinLevel2, sType2, sSubType2, iStackCount2, thisItemEquipLoc2, thisItemTexture2 = GetItemInfo(actualItemString2);
							end
							if iLevel then -- If we got it the first item
								if actualItemString2 == nil or iLevel2 then -- If there is a second item or we got the second item information
									LootCouncil_Browser.printd("item obtained from server");
									if iLevel2 then
										LootCouncil_Browser.printd("TWO ITEMS WOAH!");
									end
									for ci = 1, MAX_ENTRIES do --Find the row it already exists in (that we created earlier)
										local entry = LootCouncil_Browser.Elects[ci];
										if entry and entry[1] and entry[1] == name then
											--Now update the info.
											LootCouncil_Browser.printd("found the player!");
											entry[2] = actualItemString.." ("..iLevel..")";
											entry[3] = iLevel
											if iLevel2 then
												entry[12] = 2;
											else
												entry[12] = 1;
											end
											entry[13] = sLink;
											if iLevel2 then
												entry[14] = sLink2;
											else
												entry[14] = nil;
											end
											
											if iLevel2 then
												entry[2] = entry[2].."\n"..sLink2.." ("..iLevel2..")";
												entry[3] = entry[3].." - "..iLevel2;
											end
											LootCouncil_Browser.printd("info updated")
											LootCouncil_Browser.Update()
											break
										end
									end
									table.remove(clientEntryPings, backIndex); -- Remove it.
								end
							end
							

							
							backIndex = backIndex - 1; -- Keep looping backwards
						end
					end
				end
				
			self.TimeSinceLastUpdate = 0;
		end
	else
		LootCouncil_Browser.printd("Removing OnUpdate");
		MainFrame:SetScript("OnUpdate", nil);
	end
end


function LootCouncil_Lite:OnEnable()
	if LootCouncil_Browser.MLI == true then
		MainFrame:RegisterEvent("LOOT_OPENED");
		MainFrame:RegisterEvent("LOOT_CLOSED");
		if XLootMaster then
			self:Hook(XLootMaster,"InjectCustom");
		else
			LootFrame:UnregisterEvent("OPEN_MASTER_LOOT_LIST");
			LootFrame:UnregisterEvent("UPDATE_MASTER_LOOT_LIST");
			if Butsu then
				Butsu:UnregisterEvent("OPEN_MASTER_LOOT_LIST");
				Butsu:UnregisterEvent("UPDATE_MASTER_LOOT_LIST");
			end
			MainFrame:RegisterEvent("OPEN_MASTER_LOOT_LIST");
			MainFrame:RegisterEvent("UPDATE_MASTER_LOOT_LIST");
			
		end
	else
		LootFrame:RegisterEvent("OPEN_MASTER_LOOT_LIST");
		LootFrame:RegisterEvent("UPDATE_MASTER_LOOT_LIST");
	end
end

function LootCouncil_Lite:OnDisable()
	if (not (XLootMaster)) then
		LootFrame:RegisterEvent("OPEN_MASTER_LOOT_LIST");
		LootFrame:RegisterEvent("UPDATE_MASTER_LOOT_LIST");
		MainFrame:RegisterEvent("OPEN_MASTER_LOOT_LIST");
		MainFrame:RegisterEvent("UPDATE_MASTER_LOOT_LIST");
		if Butsu then
			Butsu:UnregisterEvent("OPEN_MASTER_LOOT_LIST");
			Butsu:UnregisterEvent("UPDATE_MASTER_LOOT_LIST");
		end
	end
	if LootCouncil_Browser.MLI == true then
		MainFrame:UnregisterEvent("LOOT_OPENED");
		MainFrame:UnregisterEvent("LOOT_CLOSED");
	end
end

function LootCouncil_Lite:InjectCustom(owner, level, value)
	if level == true then
		XLootMaster.dewdrop:AddSeparator();
		XLootMaster.dewdrop:AddLine(
			'text', "Loot Council",
			'isTitle', true
		);
		
		
		if itemRunning then
			XLootMaster.dewdrop:AddLine(
				'text', "|cffff0099" .. LootCouncilLocalization["LOOTMENU_END"],
				'func', function()
					LootCouncil_Browser.initiateAbort()
				end
			);
			
			if LootFrame.selectedSlot and (itemRunning == GetLootSlotLink(LootFrame.selectedSlot)) and (getn(LootCouncil_Browser.Elects) > 0) then
				XLootMaster.dewdrop:AddLine(
					'text', LootCouncilLocalization["AWARD"],
					'hasArrow', true,
					'value', "elects"
				)
			end
			
			if LootFrame.selectedSlot then
				XLootMaster.dewdrop:AddLine(
					'text', ""..entry[1] .." |cff3388ff("..(entry[7]-entry[8])..")",
					'func', function(val) LootCouncil_Browser.deItem(nil, val); end, 
					'arg1', entry[1]
				);
			end
		else
			XLootMaster.dewdrop:AddLine(
				'text', "|cff00cc66" .. LootCouncilLocalization["LOOTMENU_START"],
				'func', function()
					LootCouncil_Browser.initiateLootCouncil(GetLootSlotLink(LootFrame.selectedSlot));
				end
			);
		
		end
	elseif level == 2 then
		if value == "elects" then
			local table = LootCouncil_Browser.sortLootTable();
			for ci = 1, MAX_ENTRIES do
				local entry = table[ci];
				if entry then
					XLootMaster.dewdrop:AddLine(
						'text', ""..entry[1] .." |cff3388ff("..(entry[7]-entry[8])..")",
						'func', function(val) LootCouncil_Browser.awardItem(nil, val); end, 
						'arg1', entry[1]
					);
				end
			end
		end
	end
		
end

function LootCouncil_Browser.openMasterLootList()
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
	ToggleDropDownMenu(1, nil, GroupLootDropDownLCL, LootFrame.selectedLootButton, 0, 0);
end

function LootCouncil_Browser.updateMasterLootList()
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
end

function GroupLootDropDownLCL_OnLoad(self)
	UIDropDownMenu_Initialize(self, GroupLootDropDownLCL_Initialize, "MENU");
end

function GroupLootDropDown_GiveLoot(self, slot, candidate)
	GiveMasterLoot(slot, candidate);
	ToggleDropDownMenu(1, nil, GroupLootDropDownLCL, LootFrame.selectedLootButton, 0, 0);
end

function GroupLootDropDownLCL_Initialize()

	--LootCouncil_Browser.updateEnchantersList()
	local candidate;
	local info = UIDropDownMenu_CreateInfo();

	if ( UIDROPDOWNMENU_MENU_LEVEL == 2 ) then
		local lastIndex = UIDROPDOWNMENU_MENU_VALUE * 5;		
		if (lastIndex <=40) then			
			for i=1, MAX_RAIDERS do				
				candidate = GetMasterLootCandidate(LootFrame.selectedSlot, i);
				if candidate then
					index=LootCouncil_Browser.searchCharName(candidate);
					if index then
					local name, rank , partyNum = LootCouncil_Browser.getRaidCharInfo(index);
					if partyNum==UIDROPDOWNMENU_MENU_VALUE then
						-- Add candidate button
						local pClass, eClass = UnitClass(candidate)
						local extra = "";
						if (pClass ~= nil) then
							local cColor = RAID_CLASS_COLORS[eClass]
							extra = string.format("|cff%02x%02x%02x", cColor["r"]*255, cColor["g"]*255, cColor["b"]*255)
						end
						
						info.text = extra .. candidate;
						info.fontObject = GameFontNormalLeft;
						info.value = i;
						info.notCheckable = true;
						info.func = GroupLootDropDown_GiveLoot;
						info.arg1 = LootFrame.selectedSlot;
						info.arg2 = i;
						UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL);
					end
					end
				end
			end
		elseif (lastIndex == 100) then
			-- DISENCHANT GROUP
			local index;
			for i=1, MAX_RAIDERS do			
				candidate = GetMasterLootCandidate(LootFrame.selectedSlot, i);				
				if candidate and getn(LootCouncil_Browser.EnchantersList)>0 then
					index=LootCouncil_Browser.inTable(LootCouncil_Browser.EnchantersList, Ambiguate(candidate,"none"))					
					if index then
						-- Add candidate button						
							local pClass, eClass = UnitClass(candidate)
							local extra = "";
							if (pClass ~= nil) then
								local cColor = RAID_CLASS_COLORS[eClass]
								extra = string.format("|cff%02x%02x%02x", cColor["r"]*255, cColor["g"]*255, cColor["b"]*255)
							end
							
							info.text = extra .. candidate;
							info.fontObject = GameFontNormalLeft;
							info.value = i;
							info.notCheckable = true;
							info.func = GroupLootDropDown_GiveLoot;
							info.arg1 = LootFrame.selectedSlot;
							info.arg2 = i;
							UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL);
					end
				else
					break
				end
			end
		else
			local table = LootCouncil_Browser.sortLootTable();
			for ci = 1, MAX_ENTRIES do
				local entry = table[ci];
				if entry then
					local pClass, eClass = UnitClass(entry[1])
					local extra = "";
					if (pClass ~= nil) then
						local cColor = RAID_CLASS_COLORS[eClass]
						extra = string.format("|cff%02x%02x%02x", cColor["r"]*255, cColor["g"]*255, cColor["b"]*255)
					end
					
					info.text = extra .. entry[1] .." |cff3388ff("..(entry[7]-entry[8])..")"
					info.fontObject = GameFontNormalLeft;
					info.value = ci;
					info.notCheckable = true;
					info.func = LootCouncil_Browser.awardItem;
					info.arg1 = entry[1];
					UIDropDownMenu_AddButton(info,UIDROPDOWNMENU_MENU_LEVEL);
				end
			end
		end
		return;
	end
	info.arg1 = nil;
	
	--local inInstance, instanceType = IsInInstance()
	--if (  instanceType == "raid" and inInstance == true ) then
	if (  IsInRaid() ) then
	--if ( GetNumRaidMembers() > 0 ) then
		-- In a raid
		
		info.isTitle = true;
		info.text = "Loot Council Lite";
		info.fontObject = GameFontNormalLeft;
		info.notCheckable = true;
		UIDropDownMenu_AddButton(info);
		if (not (itemRunning)) then
			info.isTitle = nil;
			info.text = "|cff00cc66" .. LootCouncilLocalization["LOOTMENU_START"];
			info.fontObject = GameFontNormalLeft;
			info.notCheckable = nil;
			info.disabled = nil;
			info.value = 1;
			info.func = LootCouncil_Browser.initiateFromLoot
		else
			info.isTitle = nil;
			info.text = "|cffff0099" .. LootCouncilLocalization["LOOTMENU_END"];
			info.fontObject = GameFontNormalLeft;
			info.notCheckable = nil;
			info.disabled = nil;
			info.value = 1;
			info.func = LootCouncil_Browser.abortFromLoot
		end
		UIDropDownMenu_AddButton(info);
		
		info.text = "";
		info.hasArrow = nil;
		info.notCheckable = true;
		info.value = nil;
		info.isTitle = true;
		UIDropDownMenu_AddButton(info);
		
		info.isTitle = nil;
		info.text = "|cff00cc66" .. "Free Roll";
		info.fontObject = GameFontNormalLeft;
		info.notCheckable = nil;
		info.disabled = nil;
		info.value = 1;
		info.func = LootCouncil_Browser.doMasterLootRoll
		UIDropDownMenu_AddButton(info);
	
		info.isTitle = nil;
		info.text = "|cffff0099" .. "Cancel Free Roll";
		info.fontObject = GameFontNormalLeft;
		info.notCheckable = nil;
		info.disabled = nil;
		info.value = 1;
		info.func = LootCouncil_Browser.cancelMasterLootRoll
		UIDropDownMenu_AddButton(info);
		
		if itemRunning and LootFrame.selectedSlot and (itemRunning == GetLootSlotLink(LootFrame.selectedSlot)) and (getn(LootCouncil_Browser.Elects) > 0) then
			info.isTitle = nil;
			info.text = LootCouncilLocalization["AWARD"];
			info.fontObject = GameFontNormalLeft;
			info.hasArrow = true;
			info.notCheckable = true;
			info.value = 105;
			info.func = nil;
			info.disabled = true;
			UIDropDownMenu_AddButton(info);
		end
		
		
		info.text = "";
		info.hasArrow = nil;
		info.notCheckable = true;
		info.value = nil;
		info.isTitle = true;
		UIDropDownMenu_AddButton(info);
		
		info.isTitle = true;
		info.text = GIVE_LOOT;
		info.fontObject = GameFontNormalLeft;
		info.notCheckable = true;
		UIDropDownMenu_AddButton(info);
		
		local partyArray = {false, false, false, false, false, false, false, false}
		local name, subgroup, index

		if LootFrame.selectedSlot then
			for i=1, MAX_RAIDERS do
				candidate = GetMasterLootCandidate(LootFrame.selectedSlot, i);
				if candidate then
					index= LootCouncil_Browser.searchCharName(candidate)
					if index then
						name, _, subgroup, _, _, _, _, _, isDead =LootCouncil_Browser.getRaidCharInfo(index)
						if partyArray[subgroup]== false then
							partyArray[subgroup]=true;
						end
					end
				else 
					break
				end
			end
		end
		for i=1, getn(partyArray) do
			if partyArray[i]==true then 
				info.isTitle = nil;
				info.text = PARTY.." ".. i;
				info.fontObject = GameFontNormalLeft;
				info.hasArrow = true;
				info.notCheckable = true;
				info.value = i;
				info.func = nil;
				UIDropDownMenu_AddButton(info);
			end
		end

		-- Add disenchanters group
		if LootCouncil_Browser.EnchantersList then
			if getn(LootCouncil_Browser.EnchantersList)>0 then
				info.isTitle = nil;
				info.text = "Disenchanters";
				info.fontObject = GameFontNormalLeft;
				info.hasArrow = true;
				info.notCheckable = true;
				info.value = 20;
				info.func = nil;
				UIDropDownMenu_AddButton(info);
			end
		end
		
	else
		LootCouncil_Lite:OnDisable();
		-- In a party
		--for i=1, MAX_PARTY_MEMBERS+1, 1 do
		--	candidate = GetMasterLootCandidate(LootFrame.selectedSlot, i);
		--	if ( candidate ) then
		--		-- Add candidate button
		--		info.text = candidate;
		--		info.fontObject = GameFontNormalLeft;
		--		info.value = i;
		--		info.notCheckable = true;
		--		info.value = i;
		--		info.func = GroupLootDropDown_GiveLoot;
		--		UIDropDownMenu_AddButton(info);
		--	end
		--end
	end
end

function LootCouncil_Browser.initiateFromLoot(...)
	LootCouncil_Browser.initiateLootCouncil(GetLootSlotLink(LootFrame.selectedSlot));
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
end

function LootCouncil_Browser.doMasterLootRoll(...)
	DoMasterLootRoll(LootFrame.selectedSlot);
	
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
end

function LootCouncil_Browser.cancelMasterLootRoll(...)
	CancelMasterLootRoll(LootFrame.selectedSlot);
	
	UIDropDownMenu_Refresh(GroupLootDropDownLCL);
end

function LootCouncil_Browser.abortFromLoot(...)
	if (itemRunning or LootCouncil_awaitingItem) then
		LootCouncil_Browser.initiateAbort();
	end
end

------------- sortLootTable --------------------------
-- Sorts the vote table whenever you pull up from the right click menu
-- Returns "entry" table to use.
--------------------------------------------------
function LootCouncil_Browser.sortLootTable()
	local tempTable = LootCouncil_Browser.Elects;
	table.sort(tempTable, function(v1, v2)
		if sortMethod == "desc" then
			return v1 and (v2 == nil or (v1[7]-v1[8]) < (v2[7]-v2[8]))
		else
			return v1 and (v2 == nil or (v1[7]-v1[8]) > (v2[7]-v2[8]))
		end
	end)
	
	return tempTable;
end

-- Award Item Function
function LootCouncil_Browser.awardItem(owner, name, ...)
	local playerFound = false;
--	name=Ambiguate(name,"none");
--	print(GetMasterLootCandidate(LootFrame.selectedSlot,1))
	for i = 1, 40 do
		if (GetMasterLootCandidate(LootFrame.selectedSlot,i) == Ambiguate(name,"none")) then
			playerFound = true;
			LootCouncil_Browser.candidateNum = i;
			LootCouncil_Browser.slotNum = LootFrame.selectedSlot; 
			StaticPopup_Show("LOOT_COUNCIL_CONFIRM_LOOT_DECISION", ITEM_QUALITY_COLORS[LootFrame.selectedQuality].hex..LootFrame.selectedItemName..FONT_COLOR_CODE_CLOSE, name)			
			break;
		end
	end
	
	if not playerFound then
		print(string.format(LootCouncilLocalization["LOOTMENU_ERROR1"], name));
	end
end

-- Award Item Function
function LootCouncil_Browser.awardItemButtonClick()
	local playerFound = false;	
	if selection and selection[1] then
--		local name = Ambiguate(selection[1],"none");
		local name=selection[1]
--		print(name)
		for i = 1, 40 do
			if (GetMasterLootCandidate(LootFrame.selectedSlot,i) == Ambiguate(name,"none")) then
				playerFound = true;
				LootCouncil_Browser.candidateNum = i;
				LootCouncil_Browser.slotNum = LootFrame.selectedSlot; 
				StaticPopup_Show("LOOT_COUNCIL_CONFIRM_LOOT_DECISION", ITEM_QUALITY_COLORS[LootFrame.selectedQuality].hex..LootFrame.selectedItemName..FONT_COLOR_CODE_CLOSE, name)
				break;
			end
		end
	
		if not playerFound then
			print(string.format(LootCouncilLocalization["LOOTMENU_ERROR1"], name));
		end
	else
		print(LootCouncilLocalization["LOOTMENU_ERROR2"]);
	end
end

function LootCouncil_Browser.giveItemAway()
	if LootCouncil_Browser.candidateNum and LootCouncil_Browser.slotNum then
		LootCouncil_SendChatMessage(""..GetMasterLootCandidate(LootCouncil_Browser.slotNum,LootCouncil_Browser.candidateNum).." awarded "..GetLootSlotLink(LootCouncil_Browser.slotNum), LootCouncil_Channel);
		LootCouncil_SendChatMessage(""..GetMasterLootCandidate(LootCouncil_Browser.slotNum,LootCouncil_Browser.candidateNum).." awarded "..GetLootSlotLink(LootCouncil_Browser.slotNum), "Raid");
		GiveMasterLoot(LootCouncil_Browser.slotNum, LootCouncil_Browser.candidateNum);
		ToggleDropDownMenu(1, nil, GroupLootDropDownLCL, LootFrame.selectedLootButton, 0, 0);
		LootCouncil_Browser.slotNum = nil;
		LootCouncil_Browser.candidateNum = nil;
		LootCouncil_Browser.initiateAbort();
	else
		print(LootCouncilLocalization["LOOTMENU_ERROR3"]);
	end
end

function LootCouncil_Browser.printd(msg)
	if (LootCouncil_Browser.MainDebug == true) then
		print(msg)
	end
end



function LootCouncil_Browser.addNewEntry2(index) 
	local theInfo = entryPings[index];
	
		--Entry Pings Info
		-- 1: Sender
		-- 2: Spec
		-- 3: ItemString1
		-- 4: ItemString2
		local readyToAdd = true;
		local name = theInfo[1];
		local spec = theInfo[2];
		local fullSpec = "special";
		if spec == "M" then
			fullSpec = "MAIN";
		elseif spec == "OFF" then
			fullSpec = "OFFSPEC";
		elseif spec == "2SET" then
			fullSpec = "BONUS SET (2 parts)";
		elseif spec == "4SET" then
			fullSpec = "BONUS SET (4 parts)";
		elseif spec == "XMOG" then
			fullSpec = "TRANSMOG";
		elseif spec =="BIS" then
			fullSpec = "BiS";
		else
			fullSpec = "UNKNOWN";
		end
	
	local actualItemString = theInfo[3];
	local psName, psLink, piRarity, piLevel, piMinLevel, psType, psSubType, piStackCount, pthisItemEquipLoc = GetItemInfo(actualItemString); -- Get better info for item 1
	if psName == nil then
			readyToAdd = false;
		end
		
		
	local actualItemString2;
		local psName2, psLink2, piRarity2, piLevel2, piMinLevel2, psType2, psSubType2, piStackCount2, pthisItemEquipLoc2; -- Initialize scoping for second variable.
		if theInfo[4] then
			LootCouncil_Browser.printd("Trying to add second item entry");
			actualItemString2 = theInfo[4];
			psName2, psLink2, piRarity2, piLevel2, piMinLevel2, psType2, psSubType2, piStackCount2, pthisItemEquipLoc2 = GetItemInfo(actualItemString2); --Initialize those variables
			if psName2 == nil then
				readyToAdd = false;
			end
		end
	
	if readyToAdd then
			table.remove(entryPings, index);
			if true or((thisItemEquipLoc == "") or (LootCouncil_Browser.translateToSlot(pthisItemEquipLoc) == LootCouncil_Browser.translateToSlot(thisItemEquipLoc)) and ((not pthisItemEquipLoc2) or (LootCouncil_Browser.translateToSlot(pthisItemEquipLoc2) == LootCouncil_Browser.translateToSlot(thisItemEquipLoc)))) then 
				local indexOfPlayer = LootCouncil_Browser.alreadyLinkedItem(name, psLink); -- Checks if they've linked an item
				if indexOfPlayer > 0 then -- If they have
					theEntry = LootCouncil_Browser.Elects[indexOfPlayer]; -- then get their row
					theEntry[15] = spec; -- and update their spec
					if pthisItemEquipLoc2 then -- If they have already linked an item, we already updated the first item, so we need to update the second
						theEntry[2] = theEntry[2].."\n"..psLink2.." ("..piLevel2..")"; -- append the second item link onto the string
						theEntry[3] = piLevel.." - "..piLevel2 -- Get the itemlevels set
						theEntry[12] = 2; -- switch the flag for two items
						theEntry[14] = psLink2; -- hold the second link
						if LootCouncil_debugMode == false then -- If we're displaying messages
							-- Send the player a message saying we got the update
							if spec == "-" then
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED"], itemRunning), "WHISPER", nil, name);
							else
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED_SPEC"], fullSpec, itemRunning), "WHISPER", nil, name);
							end
							LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK2"]..theEntry[13].." - "..theEntry[14], "WHISPER", nil, name);
						end
						-- Update the clients
						LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString) -- Send out info to other council
						LootCouncil_Browser.sendGlobalMessage("secondEntry "..name.." "..actualItemString2)
						LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
					else -- Else they only have 1 item, so we don't need to do as much
						if LootCouncil_debugMode == false then -- If we're displaying messages
							-- Send the player a message saying we got the update
							if spec == "-" then
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED"], itemRunning), "WHISPER", nil, name);
								LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
							else
								LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["UPDATE_PROCESSED_SPEC"], fullSpec, itemRunning), "WHISPER", nil, name);
								LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
							end
						end
						-- and Update the clients!
						LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString)
						LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
					end
					LootCouncil_Browser.Update(); -- Update the main graphs
					if indexOfPlayer > 0 and LootCouncil_Browser.IsSelected(indexOfPlayer) then -- if they had them selected, update that too
						LootCouncil_Browser.SelectEntry(indexOfPlayer)
					end
				else -- They haven't already linked an item, so we need to put them in the table.
					if LootCouncil_debugMode == false then -- If we're sending messages
						-- then let them know we got the message
						if spec == "-" then 
							LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["NEW_ENTRY"], itemRunning), "WHISPER", nil, name); -- Whisper them about their consideration
						else
							if spec == "M" then
								fullSpec = "MAIN SPEC";
							elseif spec == "OFF" then
								fullSpec = "OFF SPEC";
							elseif spec == "2SET" then
								fullSpec = "BONUS SET (2 parts)";
							elseif spec == "4SET" then
								fullSpec = "BONUS SET (4 parts)";
							elseif spec == "XMOG" then
								fullSpec = "TRANSMOG";
							elseif spec =="BIS" then
								fullSpec = "BiS";
							else
								fullSpec = "UNKNOWN";
							end
							LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["NEW_ENTRY_SPEC"], itemRunning, fullSpec), "WHISPER", nil, name);
						end
					end
					--Update the clients that we have a new item entry.
					LootCouncil_Browser.sendGlobalMessage("itemEntry "..name.." "..actualItemString) -- Send out a global 
					if psLink2 and (specialSlot == true) then -- If this is a 2-item slot and they linked 2 items
						if LootCouncil_debugMode == false then -- Send them a message about the items we got
							LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK2"]..psLink.." - "..psLink2, "WHISPER", nil, name); -- Send them about BOTH items
						end
						LootCouncil_Browser.sendGlobalMessage("secondEntry "..name.." "..actualItemString2) -- Alert other councilmen about the second item that we got
						table.insert(LootCouncil_Browser.Elects, { -- put them in the table
							name, -- Player Name
							psLink.." ("..piLevel..")\n"..psLink2.." ("..piLevel2..")", -- String on the table
							piLevel.." - "..piLevel2, -- Item Level of Item they linked
							"-", -- Attendance
							"-", -- Item Density
							"-", -- Last Item
							0, -- Number of Votes For
							0, -- Number of Votes Against
							"None", -- Initialize "No Vote"
							{}, -- No one has voted for this person, so initialize that 
							LootCouncil_Browser.getGuildRank(name), -- Get their guild rank name
							2, -- They linked 2 items
							psLink, -- first item link
							psLink2, -- second item link
							spec -- and their spec
						})
						LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
					else -- Else they only linked 1 item or this isn't a special slot
						if LootCouncil_debugMode == false then -- send them a message saying we got the item
							LootCouncil_SendChatMessage(LootCouncilLocalization["UPDATE_PROCESSED_FEEDBACK1"]..psLink, "WHISPER", nil, name);
						end
						table.insert(LootCouncil_Browser.Elects, {
							name, -- Player Name
							psLink.." ("..piLevel..")", -- String on the table
							piLevel, -- Item Level of Item they linked
							"-", -- Attendance
							"-", -- Item Density
							"-", -- Last Item
							0, -- Number of Votes For
							0, -- Number of Votes Against
							"None", -- Initialize "No Vote"
							{}, -- No one has voted for this person yet, so initialize that
							LootCouncil_Browser.getGuildRank(name), -- get their guild rank name
							1, -- they linked 1 item
							psLink, -- first item
							nil, -- no second item, so hold nil
							spec -- and their spec
						})
						LootCouncil_Browser.sendGlobalMessage("spec "..name.." "..spec)
					end
	
	
					LootCouncil_Browser.Update(); -- AND WE'RE DONE! UPDATE THE FRAME!
				end
			else -- They didn't send items that fit the slots we were considering
				if LootCouncil_debugMode == false then
					LootCouncil_SendChatMessage(string.format(LootCouncilLocalization["BAD_SLOT"], itemRunning), "WHISPER", nil, name);
				end
			end
		end
end



-- ORIGINAL FUNCTION
--function LootCouncil_Browser.parseSpec(msg, actualItemString, actualItemString2) 
--	--NOTE TO SELF:
--	 -- If someone ever complains about an item that has both "main" or "OFFSPEC" or "special" AFTER a dash, we're in big trouble...
--	 -- or if something ever has both a colon AND a dash
--	 
--	 -- CHANGES ON 9/24/2010
--	 ---- Made it so we look for |h[ and ]|h instead of the name (for localization purposes).
--	local _, afterNameRaw  = string.find(msg, "%]\124h")
--	if psName2 then
--		if afterNameRaw == nil then
--			afterNameRaw = 0;
--		end
--			_, afterNameRaw  = string.find(msg, "%]\124h", afterNameRaw+2);
--	end
--	
--	-- OKAY! We've now found the START and the END of the itemlinks
--	if afterNameRaw and afterNameRaw ~= nil and afterNameRaw > 0 then 
--		local cutStringAfter = string.lower(string.sub(msg, afterNameRaw)); -- get everything to lower case and cut out the after string
--		local cutStringBefore = string.lower(string.sub(msg, 0, startLoc)); -- get everything to lower case and cut out the before string
--		local after = string.find(cutStringAfter, "main") -- search for main
--		local before = string.find(cutStringBefore, "main") -- search for main
--		if before or after then -- if we found main, set the spec
--			spec = "M"
--			fullSpec = "MAIN"
--		else -- otherwise, go look for off
--			after = string.find(cutStringAfter, "OFFSPEC")
--			before = string.find(cutStringBefore, "OFFSPEC")
--			if before or after then -- if we found off, set the spec
--				spec = "O"
--				fullSpec = "OFFSPEC"
--			else -- otherwise, go look for special
--				after = string.find(cutStringAfter, "special")
--				before = string.find(cutStringBefore, "special")
--				if before or after then -- if we found special, set it
--					spec = "S"
--					fullSpec = "SPECIAL"
--				else -- otherwise, it's dash (this is a redundant step intentionally. DO NOT CHANGE).
--					spec = "-"
--				end
--			end
--		end
--	else
--		spec = "-";
--	end
--	
--	return spec;
--end

function LootCouncil_Browser.parseSpec(msg, actualItemString, actualItemString2) 
	--NOTE TO SELF:
	 -- If someone ever complains about an item that has both "main" or "OFFSPEC" or "special" AFTER a dash, we're in big trouble...
	 -- or if something ever has both a colon AND a dash
	 
	 -- CHANGES ON 3/24/2013
	 ---- Made it so we look for |h[ and ]|h instead of the name (for localization purposes).
	local _,endLoc  = string.find(msg, "%]\124h");
	local _,startLoc = string.find(msg,"\124[%da-z]*\124");

	
	local cutStringAfter = nil;
	if endLoc then
		if endLoc+3 < string.len(msg) then
			cutStringAfter = string.lower(string.sub(msg, endLoc+3)); -- get everything to lower case and cut out the after string
		else
			cutStringAfter=nil;
		end
	end

	local cutStringBefore = nil;
	if startLoc then
		if startLoc > 12 then
			cutStringBefore = string.lower(string.sub(msg, 0,startLoc-1)); -- get everything to lower case and cut out the  before string
		end

	end
	
	--if psName2 then
	--	if afterNameRaw == nil then
	--		afterNameRaw = 0;
	--	end
	--		_, afterNameRaw  = string.find(msg, "%]\124h", afterNameRaw+2);
	--end
	
	local spec = "M";
	local fullSpec = "";
	local keywords;
--
--							if spec == "M" then
--								fullSpec = "MAIN";
--							elseif spec == "OFF" then
--								fullSpec = "OFFSPEC";
--							elseif spec == "2SET" then
--								fullSpec = "BONUS SET (2 parts)";
--							elseif spec == "4SET" then
--								fullSpec = "BONUS SET (4 parts)";
--							elseif spec == "XMOG" then
--								fullSpec = "TRANSMOG";
--							elseif spec =="BIS" then
--								fullSpec = "BiS";
--							else
--								fullSpec = "UNKNOWN";
--							end


	-- OKAY! We've now found the START and the END of the itemlinks
	if cutStringAfter or cutStringBefore then 
		local string_to_search=nil;
		if cutStringAfter and cutStringBefore then
			string_to_search= cutStringBefore .. "   " .. cutStringAfter  ;
		elseif cutStringAfter then
			string_to_search= cutStringAfter;
		elseif cutStringBefore then
			string_to_search= cutStringBefore;
		end

--		-- SEARCH FOR MAIN SPEC RELATED KEYWORDS (not needed since its default)
--		local keywords= { "main"};
--		for i,v in ipairs(keywords) do
--			if string.find(string_to_search, keywords[i]) then
--				spec = "M"
--				fullSpec = "MAIN"
--				return spec
--			end
--
--		end
		
		-- SEARCH FOR OFF SPEC RELATED KEYWORDS
		keywords= { "offspec", "off","os"};
		for i,v in ipairs(keywords) do
			if string.find(string_to_search, keywords[i]) then
				spec = "OFF"
				fullSpec = "OFFSPEC"
				return spec
			end
		end

		-- SEARCH FOR XMOG RELATED KEYWORDS
		keywords= { "xmog","transmog"};
		for i,v in ipairs(keywords) do
			if string.find(string_to_search, keywords[i]) then
				spec = "XMOG"
				fullSpec = "TRANSMOG"
				return spec
			end
		end
		
		-- SEARCH FOR 2BONUS RELATED KEYWORDS
		local keywords= {"2part","2st","2set","2set bonus"};
		for i,v in ipairs(keywords) do
			if string.find(string_to_search, keywords[i]) then
				spec = "2SET"
				fullSpec = "BONUS SET (2 parts)"
				return spec
			end
		end

		-- SEARCH FOR 2BONUS RELATED KEYWORDS
		local keywords= {"4part","4st","4set","4set bonus"};
		for i,v in ipairs(keywords) do
			if string.find(string_to_search, keywords[i]) then
				spec = "4SET"
				fullSpec = "BONUS SET (4 parts)"
				return spec
			end
		end

		-- SEARCH FOR BONUS RELATED KEYWORDS
		local keywords= {"bis"};
		for i,v in ipairs(keywords) do
			if string.find(string_to_search, keywords[i]) then
				spec = "BIS"
				fullSpec = "BiS"
				return spec
			end
		end
	end
	
	return spec;
end

------------- getCharInfo -----------------------
-- Get information about character (updated for patch 5.4.2)
------------------------------------------------------

function LootCouncil_Browser.getCharInfo(index)
	local name, rank, rankIndex, level, class, zone, note,officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(index);
	--NewName = Ambiguate(name,"none")
	local NewName = name;
	--print(NewName)
	return NewName, rank, rankIndex, level, class, zone, note,officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile
end

------------- getUnitName -----------------------
-- Get Unit Name with Realm (updated for patch 5.4.7)
------------------------------------------------------

function LootCouncil_Browser.getUnitName(unit)
	local name, realm = UnitName(unit,TRUE);
	if type(realm) == "nil" then
		realm = GetRealmName():gsub("%s+", "");
	end
	local FullName = name .. "-" .. realm;
	--return Ambiguate(FullName,"none");
	return FullName
end

------------- getCharInfo -----------------------
-- Get information about character in raid (updated for patch 5.4.2)
------------------------------------------------------

function LootCouncil_Browser.getRaidCharInfo(index)
	local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(index);
	--NewName = Ambiguate(name,"none")
	local NewName = name;
	--print(NewName)
	return NewName, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML
end

function LootCouncil_Browser.deItem(owner, name, ...)

end

------------- updateEnchantersList -----------------------
-- Update information about enchanters in raid 
----------------------------------------------------------

function LootCouncil_Browser.updateEnchantersList()
	
	LootCouncil_Browser.printd("Updating list of enchanters out of "..GetNumGroupMembers())
	EnchantersList = " "; -- List of enchanters in the group
	EnchantersNum = 0; -- Number of enchanters in the group

			for i=1, GetNumGroupMembers() do
				local name, rank , partyNum = LootCouncil_Browser.getRaidCharInfo(i);
				local unit=name;
				--local unit="raid"..i;
				--local unit="party"..i;
				
				local ring0Link = GetInventoryItemLink(unit,GetInventorySlotInfo("Finger0Slot"));
				if ring0Link then
					_, enchant0Id, _, _, _, _ = ring0Link:match("item:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)");
				end				
				local ring1Link = GetInventoryItemLink(unit,GetInventorySlotInfo("Finger1Slot"));
				if ring1Link then 
					_, enchant1Id, _, _, _, _ = ring1Link:match("item:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)");
				end
				if enchant0Id or  enchant1Id then
					LootCouncil_Browser.printd("Adding " .. name .. " to the enchanters list")
					EnchantersList = EnchantersList..", "..name
					--EnchantersNum = EnchantersNum + 1
				end
				enchant0Id=nil
				enchant1Id=nil
			end
end

------------- searchCharName -----------------------
-- Search by the name of a character in the MasterLootCandidates
----------------------------------------------------------

function LootCouncil_Browser.searchCharName(candidate)
	if candidate then
		-- Needs better support for party/raid
		local raidIndex = UnitInRaid(Ambiguate(candidate,"none"));
	end
	return raidIndex
end

------------- Array Lookup -----------------------
-- Checking if an array contains a given value
----------------------------------------------------------
function LootCouncil_Browser.inTable(tbl, item)
	for key, value in pairs(tbl) do	
		if value == item then return key end
	end
	return false
end

------------- searchSameRaid -----------------------
-- Search if a player is in the same raid as initiator
----------------------------------------------------------

function LootCouncil_Browser.searchSameRaid(candidate)
	if candidate then
		-- Needs better support for party/raid
		local raidIndex = UnitInRaid(Ambiguate(candidate,"none"));
		if raidIndex then
			return true
		end
	end
	return false
end

------------- changeChannel -----------------------
-- Change the default channel of communications
----------------------------------------------------------

function LootCouncil_Browser.changeChannel(arg)

	if arg ~= nil then
		-- Support "default" to revert back to "OFFICER"
		if arg=="default" then
			LootCouncil_Channel="OFFICER"
			LootCouncil_Browser.Channel="OFFICER"
		else
			local index = GetChannelName(arg)
			-- Detect if channel exists
			if index > 0 then
				-- Change channel
				LootCouncil_Channel=arg
				LootCouncil_Browser.Channel=LootCouncil_Channel
			else
				print(LootCouncilLocalization["CHANNEL_NOT_JOINED"])
				return
			end
		end
	end
	print(LootCouncilLocalization["MAIN_CHANNEL"] .. ": " .. LootCouncil_Browser.Channel)
end