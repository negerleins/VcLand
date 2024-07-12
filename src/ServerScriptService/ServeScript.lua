--/ Types: ServerScript
type template = {
    Data: {
        Coins: number;
    };
    SessionId: boolean;
};

type leaderService = {
    FailSave: {
        Retry: number;
        Delay: number;
    };

    Template: template;
};

type leaderServiceMeta<T> = {
    getCache: (self: leaderServiceMeta<T...>) -> { [any]: any };
    sessionCheck: (self: leaderServiceMeta<T...>) -> boolean;
    createCache: (self: leaderServiceMeta<T...>) -> { [any]: any };
    saveCache: (self: leaderServiceMeta<T...>) -> boolean;
    updateStats: (self: leaderServiceMeta<T...>) -> boolean;
} & template & typeof(setmetatable)

type shared = {
    Cache: { [number]: leaderService };
    Leaderboard: Folder;
};

type serverService = {
    Sessions: { [number]: serverService };
    Shared: shared,

    New: (self: serverService, player: Player) -> leaderServiceMeta<shared>;
    Get: (self: serverService, player: Player) -> leaderServiceMeta<shared>;
};

--/ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local DataStoreService = game:GetService("DataStoreService");
local DataStore = DataStoreService:GetDataStore("PlayeData");
local Players = game.Players;

--/ Remotes
local Remotes: Folder = ReplicatedStorage.Remotes;
local ShopEvent: RemoteEvent = Remotes:FindFirstChild "ShopEvent";

--/ Requires
local ShopList = require(game.ReplicatedStorage.ShopList);

--/ Variables
local leaderService: leaderService = {
    FailSave = {
        Retry = 5,
        Delay = 1;
    };

    Template = {
        Data = {
            Coins = 0;
        }, 
        SessionId = false
    };
};

--/ Index's the leaderService table
leaderService.__index = leaderService;

--/ Get a player's leaderService object
function leaderService:getCache(): { [any]: any }
    local exists = rawget(self.Cache, self.userId);

    if not exists then
        local success, data = pcall(DataStore.GetAsync, DataStore, self.userId);

        if success and data then
            return rawset(self.Cache, self.userId, data);
        else
            warn("Failed to get data:", data);
        end;
    else
        return rawget(self.Cache, self.userId);
    end;
end;

--/ Check if a player's session is valid
function leaderService:sessionCheck(): boolean
    local success, data = pcall(DataStore.GetAsync, DataStore, self.userId);

    if success then
        if data then
            if data.SessionId == game.JobId or not data.SessionId then
                return true;
            else
                warn("Session ID does not match:", self.userId);
            end;
        else
            warn("Data does not exist:", self.userId);

            return true;
        end;
    else
        warn("Failed to get data:", data);
    end;

    return false;
end;

--/ Create a player's leaderService object
function leaderService:createCache(): { [any]: any }
    assert(self.player and self.player:IsA("Player"), "Player must be a player object or exist.");

    local playerCache = table.clone(self.Template);
    playerCache.SessionId = game.JobId;

    self.Cache[self.userId] = playerCache;
    return rawget(self.Cache, self.userId);
end;

--/ Save a player's leaderService object
function leaderService:saveCache(): boolean
    local userName = Players:GetNameFromUserIdAsync(self.userId);

    -- Gets the player's cache
    local playerCache = self:getCache();

    if playerCache then
        local success, response = pcall(DataStore.SetAsync, DataStore, self.userId, playerCache);

        if not success then
            warn("Failed to save data:", response); -- Logs if the data failed to save
        else
            return success;
        end;
    else
        warn("Failed to save data: Cache does not exist:", userName); -- Logs if the cache does not exist
    end;

    return false;
end;

--/ Update a player's leaderService object
function leaderService:updateStats(): boolean
    local Leaderboard: Folder = self.Leaderboard;
    local playerCache = self:getCache();
    
    if playerCache then
        for _, object: NumberValue | StringValue in Leaderboard:GetChildren() do
            local data = rawget(playerCache.Data, object.Name);

            if data then
                object.Value = data;
                return true;
            else
                warn("Failed to update stat:", object.Name, "Data does not exist.");
            end;
        end
    else
        warn("Failed to update stats: Cache does not exist.");
    end;

    return false;
end

--/ serverService object
local serverService: serverService = {
    Sessions = {},
    Shared = {
        Cache = {},
        Leaderboard = nil
    };
};

--/ New serverService object
function serverService:New(player: Player): leaderServiceMeta<shared>
    local newSession = setmetatable(self.Shared, leaderService)

    return rawset(self.Sessions, player.UserId, newSession);
end

--/ Get a player's serverService object
function serverService:Get(player: Player): leaderServiceMeta<shared>
    return rawget(self.Sessions, player.UserId);
end

--/ RemoteEvent OnServerEvent
local Events = {
    ['PurchaseItem'] = function(player: Player, event: string, item: string)
        local playerSession = serverService:Get(player);
        local playerCache = playerSession and playerSession:getCache();
        local validSession = playerSession and playerSession:sessionCheck();

        if playerCache and validSession then
            local itemObject= rawget(ShopList.Tools, item);

            if itemObject then
                if playerCache.Data.Coins >= itemObject.Price then
                    playerCache.Data.Coins = playerCache.Data.Coins - itemObject.Price;
                    playerSession:saveCache();

                    warn("Purchased item:", item, player.UserId);

                    return true;
                else
                    warn("Failed to purchase item: Not enough coins.", player.UserId);
                end;
            else
                warn("Failed to purchase item: Item does not exist.", player.UserId);
            end;
        else
            warn("Failed to get player cache:", player.UserId, 'evemt:', event);
        end;

        return false;
    end;
};

--/ ShopEvent OnServerEvent
ShopEvent.OnServerEvent:Connect(function(invoker: Player, event: string, item: string)
    local event = rawget(Events, event); --/ Gets the event from the Events table

    if not event then
        warn("Event does not exist:", event, "Invoker:", invoker.UserId);
        return;
    end;

    --/ Executes the event
    local success, response = pcall(event, invoker, event, item);

    if not success then
        warn("Failed to invoke event:", response, invoker.UserId);
    end;
end);

--/ PlayerAdded and PlayerRemoving
Players.PlayerAdded:Connect(function(player: Player)
    local newSession = serverService:New(player);
    local validSession = newSession:sessionCheck();

    if validSession then
        local leaderstats = Instance.new("Folder");
        leaderstats.Name = "leaderstats";
        leaderstats.Parent = player;

        newSession.Leaderboard = leaderstats;

        --/ Creates the player's cache
        local playerCache = newSession:getCache();

        if not playerCache then
            newSession:createCache(); --/ Creates the player's cache
        end;
        
        --/ Session ID
        newSession.SessionId = game.JobId;

        --/ Saves the player's cache
        newSession:saveCache();
    else
        player:Kick("Failed to create session.");
    end;
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local getSession = serverService:Get(player);

    if getSession then
        local getCache = getSession:getCache();

        --/ Checks if the session ID matches the game's JobId
        if getCache.sessionId == game.JobId then
            getSession.sessionId = false;
            getSession:saveCache(); --/ Saves the player's cache
        else
            warn("Session ID does not match:", player.UserId);
        end;
    end;
end);