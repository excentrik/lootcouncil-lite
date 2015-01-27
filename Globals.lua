﻿-- Author      : Matthew Enthoven (Alias: Blacksen)
-- Create Date : 1/04/2010 12:24:31 PM

LootCouncil_debugMode = false; --NOTE: This is a variable for DEACTIVATING all messages through guild chat or whispers. When you enable it, the addon won't send people messages
-- 1 = debug on (no messages sent)
-- 0 = debug off (messages sent as normal)

--local LibStub:GetLibrary("LibInspect"):AddHook('LootCouncil_Lite', 'items', function(...) LootCouncil_GetPlayerIlvl(...); end);
local LootCouncil_Lite_inspect = LibStub:GetLibrary("LibInspect"); 

------------- isBlank ---------------------------------
-- Checks if a string is blank
-------------------------------------------------------
function LootCouncil_isBlank(x)
  return not not tostring(x):find("^%s*$")
end

------------- logical2string ---------------------------------
-- Converts a logical to a number string
-------------------------------------------------------
function LootCouncil_logical2string(x)
	if x then
		return "1"
	else
		return "0"
	end
end

------------- convertStringList -----------------------
-- Converts a string to a list
-------------------------------------------------------
function LootCouncil_convertStringList(str)
	-- STILL NEEDS ERROR PROTECTION
	if not LootCouncil_isBlank(str) then
		if (LootCouncil_debugMode==true) then
			print("Converting string to list:"..str)
		end
		local div='[^%a%såÅäÄöÖÖáàãâæçéèêëüÜíìîïñóòõôøœßúùû]' -- NEED TO CHECK BETTER UTF-8 SUPPORT
		--local div='[^[%z%s\65-\90\97-\122\194-\244][\128-\191]*]'
		local pos,arr = 0,{}
		local tmp_str
		for st,sp in function() return string.find(str,div,pos,false) end do
			tmp_str=strtrim(string.sub(str,pos,st-1))
			if not LootCouncil_isBlank(tmp_str) then
				if (LootCouncil_debugMode==true) then
					print("Adding string ("..tmp_str..") to list")
				end
				table.insert(arr,tmp_str)
			end
			pos = sp + 1
		end
		tmp_str=strtrim(string.sub(str,pos))
		if not LootCouncil_isBlank(tmp_str) then
			table.insert(arr,tmp_str)
		end
		if (LootCouncil_debugMode==true) then
			print("Adding string ("..tmp_str..") to list")
		end

		return arr
	else
		return nil
	end
end

function LootCouncil_GearSum(items,level)
    if items and type(items) == 'table' then
        local totalItems = 0;
        local totalScore = 0;

        for i,itemLink in pairs(items) do
            if itemLink and not ( i == INVSLOT_BODY or i == INVSLOT_RANGED or i == INVSLOT_TABARD ) then
                local name, link, itemRarity , itemLevel = GetItemInfo(itemLink);
               -- local itemLevel = self.itemUpgrade:GetUpgradedItemLevel(itemLink); -- TO BE IMPLEMENTED

                if itemLevel then

                    -- Fix for heirlooms
--                    if itemRarity == 7 then
--                        itemLevel = self:Heirloom(level, itemLink);
--                   end

                    totalItems = totalItems + 1;
                    totalScore = totalScore + itemLevel;
                end
            end
        end

        return totalScore, totalItems;
    else
        return nil;
    end
end


----------- LootCouncil_GetPlayerIlvl -----------------------
-- Retrieve the latest information about the ilvl of a player
------------------------------------------------------------
function LootCouncil_GetPlayerIlvl(playerIndex)

	if playerIndex then 
		local target="raid" .. tostring(playerIndex)

		local canInspect,cached,refresh=LootCouncil_Lite_inspect:RequestItems(target)
		if (LootCouncil_debugMode==true) then
			print("Player: "..target.."; CanInspect: ".. tostring(canInspect)) 
		end

		if not canInspect then
			return "NA";
		end

		LootCouncil_Lite_inspect:AddCharacter(target);
		NotifyInspect(target);

		-- Get items and sum
		local items = LootCouncil_Lite_inspect:GetItems(target);
		local totalScore, totalItems = LootCouncil_GearSum(items, UnitLevel(target));

		if totalItems and totalItems > 0 then
			local score = totalScore / totalItems;
			return tostring(round(score));
		else
			return "NA";
		end
	end
end


function LootCouncil_SendChatMessage(msg ,chatType ,language ,channel)

if string.lower(chatType) == "officer" or string.lower(chatType) == "raid" or string.lower(chatType) == "whisper" or string.lower(chatType) == "raid_warning" or string.lower(chatType) == "guild" then
	-- Send message
	SendChatMessage(msg ,chatType ,nil ,channel);
else
	-- Find channel number
	local index
	if channel then
		index = GetChannelName(channel)
	else
		index,channel = GetChannelName(chatType)
	end

	-- Send message
	if index >0 then
		SendChatMessage(msg ,"CHANNEL" ,nil ,index);
	else
		print("You have not joined channel ".. LootCouncil_Channel ..". Using officer channel for communication.")
		print(chatType)
		SendChatMessage(msg ,"OFFICER");
	end
end

end

LootCouncil_TheCouncil = {};
LootCouncil_Browser = {}
LootCouncil_Browser.Data = {}
LootCouncil_Browser.Elects = {}
LootCouncil_Browser.Votes = {}
LootCouncil_Browser.WhisperList = {}
LootCouncil_PlayerData = {}
LootCouncil_minRank = 0;
LootCouncil_sawFirstMessage = false;
LootCouncil_privateVoting = false;
LootCouncil_singleVote = false;
LootCouncil_displaySpec = false;
LootCouncil_selfVoting = false;
LootCouncil_scale = 1;
LootCouncil_confirmEnding = false;
LootCouncil_masterLootIntegration = true;
LootCouncil_Enchanters = "";
LootCouncil_SplitRaids = false;

LootCouncil_awaitingItem = false;

LootCouncil_Browser.private = LootCouncil_privateVoting;
LootCouncil_Browser.single = LootCouncil_singleVote;
LootCouncil_Browser.spec = LootCouncil_displaySpec;
LootCouncil_Browser.self = LootCouncil_selfVoting;
LootCouncil_Browser.confirmEnd = LootCouncil_confirmEnding;
LootCouncil_Browser.EnchantersList = LootCouncil_convertStringList(LootCouncil_Enchanters);
LootCouncil_Browser.MLI = LootCouncil_masterLootIntegration;
LootCouncil_Browser.SplitRaids=LootCouncil_SplitRaids;

LootCouncil_LinkWhisper = true;
LootCouncil_LinkOfficer = true;
LootCouncil_LinkRaid = false;
LootCouncil_LinkGuild = false;
LootCouncil_Version="2.7"

LootCouncil_Channel="OFFICER"

LootCouncil_Lite_inspect:AddHook('LootCouncil_Lite', 'items', function(...) LootCouncil_ProcessInspect(...); end);

RegisterAddonMessagePrefix("L00TCOUNCIL");


do
	----------- Slash Command Manager -----------
	---------------------------------------------
	SLASH_LOOT_COUNCIL1 = "/ltc";
	SLASH_LOOT_COUNCIL2 = "/lootcouncil";
	SLASH_LOOT_COUNCIL3 = "/lc";
	SlashCmdList["LOOT_COUNCIL"] = function(msg)
		local cmd, arg = string.split(" ", msg,2); -- Separates the command from the rest
		cmd = cmd:lower(); -- Lower case command
		if cmd == "show" then -- show the main frame
			LootCouncil_Browser.showMainFrame();
		elseif cmd == "hide" then -- hide the main frame
			LootCouncil_Browser.hideMainFrame();
		elseif cmd == "start" then -- try to start a new Loot Council Session
			LootCouncil_Browser.printd("slash start cmd");
			LootCouncil_Browser.initiateLootCouncil(msg:match("^start%s+(.+)"));
		elseif cmd == "end" then
			LootCouncil_Browser.initiateAbort();
		elseif cmd == "add" then
			if arg then
				local thePlayer, item = string.split(" ", arg);
				if item then
					local startLoc = string.find(msg, "Hitem:")
					if startLoc ~= nil then
						LootCouncil_Browser.manualAdd(thePlayer, arg);
					else
						print(LootCouncilLocalization["BAD_MANUAL_ADD"])
					end
				else
					print(LootCouncilLocalization["BAD_MANUAL_ADD"])
				end
			else
				print(LootCouncilLocalization["BAD_MANUAL_ADD"])
			end
		elseif cmd == "rank" then
			RankFrame:Show()
			LCOptionsFrame:Hide()
		elseif cmd == "config" then
			LootCouncil_Browser.ShowOptions()
			RankFrame:Hide()
			LCTestFrame:Hide()
		elseif cmd == "test" then
			LCTestFrame:Show()
			LootCouncil_Browser.RunTests()
			RankFrame:Hide();
			LCOptionsFrame:Hide()
		elseif cmd == "reset" then
			LootCouncil_Browser.resetMainFrame()
		elseif cmd == "channel" then
			LootCouncil_Browser.changeChannel(arg)
		elseif cmd == "" then
			print(LootCouncilLocalization["CMD_MAIN"]);
			print(LootCouncilLocalization["CMD_PREFIX"]);
			print(LootCouncilLocalization["CMD_SHOW"])
			print(LootCouncilLocalization["CMD_HIDE"])
			print(LootCouncilLocalization["CMD_START"]);
			print(LootCouncilLocalization["CMD_END"]);
			print(LootCouncilLocalization["CMD_ADD"])
			print(LootCouncilLocalization["CMD_RANK"]);
			print(LootCouncilLocalization["CMD_CONFIG"]);
			print(LootCouncilLocalization["CMD_TEST"]);
			print(LootCouncilLocalization["CMD_RESET"]);
			print(LootCouncilLocalization["CMD_CHANNEL"]);
		else
			print(string.format(LootCouncilLocalization["BAD_CMD"], msg));
		end
	end
end

