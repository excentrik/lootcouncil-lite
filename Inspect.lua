-- Inspection and iLvl related functions

function LootCouncil_Lite:GetPurge() return self.purge; end
function LootCouncil_Lite:GetAge() return self.age; end

function LootCouncil_Lite:AutoPurge(silent)
	if self:GetPurge() > 0 then
		local count = self:PurgeCache(self:GetPurge());
		
--		if not silent then
--			self:Print(format(L.core.purgeNotification, count));
--		end
		
		return count;
	else
--		if not silent then
--			self:Print(L.core.purgeNotificationFalse);
--		end
		
		return false;
	end
end

function LootCouncil_Lite:PurgeCache(hours)
	if tonumber(hours) then
		local maxAge = time() - (tonumber(hours) * 3600);
		local count = 0;
		
		for guid,info in pairs(LootCouncil_Lite_CacheGUID) do
			if type(info.time) == "number" and info.time < maxAge then
				LootCouncil_Lite_CacheGUID[guid] = nil;
				count = 1 + count;
                
--                self:RunHooks('purge', guid);
			end
		end
		
		return count;
	else
		return false;
	end
end

function LootCouncil_Lite:GearSum(items,level)
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
function LootCouncil_Lite:GetPlayerIlvl(playerName)

	if playerName then
		local target="raid" .. tostring(LootCouncil_searchCharName(playerName))
	
		
		local canInspect,cached,refresh=LootCouncil_Lite.inspect:RequestItems(target)
		if (LootCouncil_Browser_MainDebug==true) then
			print("Player: "..target.."; CanInspect: ".. tostring(canInspect)) 
		end

		if not canInspect then
			return "NA";
		end
		
		guid=LootCouncil_Lite:AddPlayer(target);
		if guid then
			local score, age, items, startScore = LootCouncil_Lite:GetScore(LootCouncil_Lite:GetGUID(target), true, target)
			if score then
				return tostring(round(score));
			end
		end
		return "NA";
--		LootCouncil_Lite.inspect:AddCharacter(target);
--		NotifyInspect(target);
--
--		-- Get items and sum
--		local items=LootCouncil_Lite.inspect:GetItems(target);
--		local totalScore, totalItems = LootCouncil_Lite:GearSum(items, UnitLevel(target));
--	
--		if totalItems and totalItems > 0 then
--			local score = totalScore / totalItems;
--			return tostring(round(score));
--		else
--			return "NA";
--		end
	end
end

--function LootCouncil_Lite:Autoscan(toggle)
--	if toggle then
--		self:RegisterEvent("UNIT_INVENTORY_CHANGED");
--	else 
--		self:UnregisterEvent("UNIT_INVENTORY_CHANGED");
--	end
--	
--	self.db.global.autoscan = toggle;
--end

function LootCouncil_Lite:GUIDtoName(guid)
	if guid and self:IsGUID(guid, 'Player') and self:Cache(guid) then
		return self:Cache(guid, 'name'), self:Cache(guid, 'realm');
	else
		return false;
	end
end

function LootCouncil_Lite:NameToGUID(name, realm)
	if not name then return false end
	
	-- Try and get the realm from the name-realm
	if not realm then
		name, realm = strsplit('-', name, 2);
	end
	
	-- If no realm then set it to current realm
	if not realm or realm == '' then
		realm = GetRealmName();
	end
	
	if name then
		name = strlower(name);
		local likely = false;
        
		for guid,info in pairs(LootCouncil_Lite_CacheGUID) do
			if strlower(info.name) == name and info.realm == realm then
				return guid;
            elseif strlower(info.name) == name then
                likely = guid;
            end
		end
        
        if likely then
            return likely;
        end
	end
	
	return false;
end

-- Get a GUID from just about anything
function LootCouncil_Lite:GetGUID(target)
    if target then
        if tonumber(target) then
            return target;
        elseif UnitGUID(target) then
            return UnitGUID(target);
        else
            return LootCouncil_Lite:NameToGUID(target);
        end
    else
        return false;
    end
end

-- Clear score
function LootCouncil_Lite:ClearScore(target)
	local guid = self:GetGUID(target);
	
	if LootCouncil_Lite_CacheGUID[guid] then
		LootCouncil_Lite_CacheGUID[guid].score = false;
		LootCouncil_Lite_CacheGUID[guid].items = false;
		LootCouncil_Lite_CacheGUID[guid].time = false;
		
        --self:RunHooks('purge', guid);
        
		return true;
	else
		return false;
	end
end;

-- Get someones score
function LootCouncil_Lite:GetScore(guid, attemptUpdate, target, callback)
    if not self:IsGUID(guid, 'Player') then return false; end
    
	if self:Cache(guid) and self:Cache(guid, 'score') then
		local score = self:Cache(guid, 'score');
		local age = self:Cache(guid, 'age') or time();
		local items = self:Cache(guid, 'items');
		local startScore = nil;
        
        -- If a target was passed and we are over age
        if target and (attemptUpdate or self:GetAge() < age) then
            startScore = self:StartScore(target, callback);
        end
        
		return score, age, items, startScore;
	else
        
        -- If a target was passed
        if target then
            self:StartScore(target);
        end
        
        return false;
	end
end

-- Wrapers for get score, more specialized code may come
function LootCouncil_Lite:GetScoreName(name, realm)
    local guid = self:NameToGUID(name, realm);
    return self:GetScore(guid);
end

function LootCouncil_Lite:GetScoreGUID(guid)
    return self:GetScore(guid);
end

-- Request items to update a score
function LootCouncil_Lite:StartScore(target, callback)
    if InCombatLockdown() or not CanInspect(target) then 
        if callback then callback(false, target); end
        return false;
    end
    
    self.autoscan = time();
    local guid = self:AddPlayer(target);
    
    if not self.lastScan[target] or self.lastScan[target] ~= time() then
        if guid then
            --self.action[guid] = callback;
            self.lastScan[target] = time();
            
            local canInspect = self.inspect:RequestItems(target, true);
            
            if not canInspect and callback then
                callback(false, target);
            else
                return true;
            end
        end
    end
    
    if callback then callback(false, target); end
    return false;
end

function LootCouncil_Lite:ProcessInspect(guid, data, age)
-- self is LootCouncil_Lite.inspect
    if guid and self:Cache(guid) and type(data) == 'table' and type(data.items) == 'table' then
        
	--LootCouncil_Lite:AddPlayer(target)
        local totalScore, totalItems = self:GearSum(data.items, self:Cache(guid, 'level'));
        
        if totalItems and 0 < totalItems then
            
	    --print("PROCESSING "..LootCouncil_Lite:GUIDtoName(guid) )
            -- Update the DB
            local score = LootCouncil_round(totalScore / totalItems);
            self:SetScore(guid, score, totalItems, age) -- Updates LootCouncil_Lite_CacheGUID with only the score info 

            -- Run Hooks
            --self:RunHooks('inspect', guid, score, totalItems, age, data.items);
            
--            -- Run any callbacks for this event
--            if self.action[guid] then
--                self.action[guid](guid, score, totalItems, age, data.items, self:Cache(guid, 'target'));
--                self.action[guid] = false;
--            end
            
            -- Update the ilvl

	    name,realm= LootCouncil_Lite:GUIDtoName(guid)	
	    if (LootCouncil_Browser_MainDebug==true) then
			print("PROCESSING "..name.."-"..realm)
		end
            LootCouncil_Browser.updateIlvl(name.."-"..realm, score)
            
            return true;
        end
    end
end

-- /run for i=1,25 do t='raid'..i; if UnitExists(t) then print(i, UnitName(t), CanInspect(t), LootCouncil_Lite:RoughScore(t)); end end
function LootCouncil_Lite:RoughScore(target)
    if not target then return false; end
    if not CanInspect(target) then return false; end
    
    -- Get stuff in order
    local guid = self:AddPlayer(target)
    self.inspect:AddCharacter(target);
    NotifyInspect(target);
    
    -- Get items and sum
    local items = self.inspect:GetItems(target);
    local totalScore, totalItems = self:GearSum(items, UnitLevel(target));
    
    if totalItems and totalItems > 0 then
        local score = totalScore / totalItems;
        -- self:Debug('SIL:RoughScore', UnitName(target), score, totalItems);
        
        -- Set a score even tho its crap
        if guid and self:Cache(guid) and (not self:Cache(guid, 'score') or self:Cache(guid, 'items') < totalItems) then
            self:SetScore(guid, score, 1, self:GetAge() + 1);
        end
        
        return score, 1, self:GetAge() + 1;
    else
        return false;
    end
end

-- Start or update the DB for a player
function LootCouncil_Lite:AddPlayer(target)  
    local guid = UnitGUID(target);
    
    if guid then
        local name, realm = UnitName(target);
        local className, class = UnitClass(target);
        local level = UnitLevel(target);
        
        if not realm then
            realm = GetRealmName();
        end
        
        if name and realm and class and level then
            
            -- Start a table for them
            if not LootCouncil_Lite_CacheGUID[guid] then
                LootCouncil_Lite_CacheGUID[guid] = {};
            end
            
            LootCouncil_Lite_CacheGUID[guid].name = name;
            LootCouncil_Lite_CacheGUID[guid].realm = realm;
            LootCouncil_Lite_CacheGUID[guid].class = class;
            LootCouncil_Lite_CacheGUID[guid].level = level;
            LootCouncil_Lite_CacheGUID[guid].target = target;
            
            if not LootCouncil_Lite_CacheGUID[guid].score or LootCouncil_Lite_CacheGUID[guid].score == 0 then
                LootCouncil_Lite_CacheGUID[guid].score = false;
                LootCouncil_Lite_CacheGUID[guid].items = false;
                LootCouncil_Lite_CacheGUID[guid].time = false;
            end
            
            return guid;
        else
            return false;
        end
    else
        return false;
    end
end

function LootCouncil_Lite:SetScore(guid, score, items, age)
    local t = age;
    
    if age and type(age) == 'number' and age < 86400 then
        t = time() - age; 
    end
    
    LootCouncil_Lite_CacheGUID[guid].score = score;
    LootCouncil_Lite_CacheGUID[guid].items = items;
    LootCouncil_Lite_CacheGUID[guid].time = t;
    --self:Debug("SetScore", self:GUIDtoName(guid), self:FormatScore(score, items), items, age)
end

function LootCouncil_Lite:Cache(guid, what)
    if not guid and not self:IsGUID(guid, 'Player') then return false end
    
    if LootCouncil_Lite_CacheGUID[guid] and what then
        if what == 'age' then
            if LootCouncil_Lite_CacheGUID[guid].time then
                return time() - LootCouncil_Lite_CacheGUID[guid].time;
            else
                return nil;
            end
        else
            return LootCouncil_Lite_CacheGUID[guid][what];
        end
    elseif LootCouncil_Lite_CacheGUID[guid] then
        return true;
    else
        return false;
    end
end

function LootCouncil_Lite:UpdateGroup()
    --self.group = {};
    
    local playerGUID = self:AddPlayer('player');
    --table.insert(self.group, playerGUID);
    
    if UnitInBattleground('player') or UnitInRaid('player') then
        for i=1,MAX_RAID_MEMBERS do
            local target = 'raid'..i;
            local guid = self:AddPlayer(target);

            if guid and guid ~= playerGUID then
                --table.insert(self.group, guid);
                
                if not self:Cache(guid, 'score') then
                    self:RoughScore(target);
                end
            end
        end
    elseif GetNumSubgroupMembers() > 0 then
        for i=1,MAX_PARTY_MEMBERS do
            local target = 'party'..i;
            local guid = self:AddPlayer(target);
            
            if guid then
                --table.insert(self.group, guid);
                
                if not self:Cache(guid, 'score') then
                    self:RoughScore(target);
                end
            end
        end
    end
end

function LootCouncil_Lite:IsGUID(guid, type)
    if not guid then return false end
    if not type then type = 'player' end

    local gType, gGuid = strsplit('-', guid, 2);

    if strlower(type) == strlower(gType) then 
        return true
    else 
        return false
    end
end