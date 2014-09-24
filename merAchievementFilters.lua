local myNAME = "merAchievementFilters"


local function df(fmt, ...)
    --d(zo_strformat(fmt, ...))
end


local function isAchievementPartiallyCompleted(id)
    local name, _, _, _, completed = GetAchievementInfo(id)
    while completed do
        id = GetNextAchievementInLine(id)
        if id == 0 then
            -- either this wasn't a line, or everything in it was completed
            return false
        end
        name, _, _, _, completed = GetAchievementInfo(id)
    end
    local totalCompleted = 0
    local totalRequired = 0
    local numCriteria = GetAchievementNumCriteria(id)
    for crit = 1, numCriteria do
        local _, numCompleted, numRequired = GetAchievementCriterion(id, crit)
        totalCompleted = totalCompleted + numCompleted
        totalRequired = totalRequired + numRequired
    end
    df("|caaaaaa<<1>>: <<2>> (<<3>>/<<4>>)", id, name, totalCompleted, totalRequired)
    return totalCompleted > 0 and totalCompleted < totalRequired
end


local function orgMethodInvoker(obj, name)
    local original = rawget(obj, name)
    if original then
        return original
    end
    local function super(self, ...)
        local index = getmetatable(self).__index
        return index[name](self, ...)
    end
    return super
end


local function sift(sieve, ...)
    if select("#", ...) > 0 then
        local grain = select(1, ...)
        if sieve(grain) then
            return grain, sift(sieve, select(2, ...))
        else
            return sift(sieve, select(2, ...))
        end
    end
end


local function onAddOnLoaded(eventCode, addOnName)
    if addOnName ~= myNAME then return end
    EVENT_MANAGER:UnregisterForEvent(myNAME, EVENT_ADD_ON_LOADED)

    local function filterChanged(comboBox, entryText, entry)
        ACHIEVEMENTS.categoryFilter.filterType = entry.filterType
        ACHIEVEMENTS.categoryFilter.merFilterName = entry.name
        ACHIEVEMENTS.categoryFilter.merCustomFilter = entry.merCustomFilter
        ACHIEVEMENTS:RefreshVisibleCategoryFilter()
    end

    local comboBox = ZO_ComboBox_ObjectFromContainer(ACHIEVEMENTS.categoryFilter)
    local underwayEntryIndex = nil

    for index, entry in ipairs(comboBox:GetItems()) do
        if entry.filterType == SI_ACHIEVEMENT_FILTER_SHOW_UNEARNED then
            -- remember index for insertion of UNDERWAY before UNEARNED
            underwayEntryIndex = index
        end
        -- replace callback with one also updating custom filter
        entry.callback = filterChanged
    end

    if underwayEntryIndex then
        local underwayEntry =
        {
            name = GetString(merSI_ACHIEVEMENT_FILTER_SHOW_UNDERWAY),
            filterType = SI_ACHIEVEMENT_FILTER_SHOW_ALL, -- bypass ShouldAddAchievement
            callback = filterChanged,
            merCustomFilter = isAchievementPartiallyCompleted,
        }
        table.insert(comboBox:GetItems(), underwayEntryIndex, underwayEntry)
        comboBox:UpdateItems()
    end

    local zorgLayoutAchievements = orgMethodInvoker(ACHIEVEMENTS, "LayoutAchievements")

    function ACHIEVEMENTS:LayoutAchievements(...)
        if self.categoryFilter.merCustomFilter then
            df("|c7fff7f<<1>>: <<2>>", self.categoryLabel:GetText(), self.categoryFilter.merFilterName)
            return zorgLayoutAchievements(self, sift(self.categoryFilter.merCustomFilter, ...))
        else
            return zorgLayoutAchievements(self, ...)
        end
    end
end


EVENT_MANAGER:RegisterForEvent(myNAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)

