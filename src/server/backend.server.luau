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
local HttpService = game:GetService('HttpService');
local RunService = game:GetService('RunService');
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local DataStoreService = game:GetService("DataStoreService");
local DataStore = DataStoreService:GetDataStore("PlayeData");
local Players = game.Players;

--/ Remotes
local Shared: Folder = ReplicatedStorage:FindFirstChild "Shared";
local ShopEvent: RemoteEvent = Shared:FindFirstChild("ShopEvent", true) or Instance.new('RemoteEvent', Shared);
if ShopEvent.Name == 'RemoteEvent' then
    ShopEvent.Name = 'RemoteEvent';
end

--/ Get Modules
local moduleShopList = Shared:FindFirstChild "ShopList";

--/ Requires
local ShopList = require(moduleShopList);

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
        SessionId = ""
    };
};

--/ Index's the leaderService table
leaderService.__index = leaderService;

--/ Get a player's leaderService object
function leaderService:getCache(): { [any]: any } | boolean
    local exists = rawget(self.Cache, self.userId);

    if not exists then
        local success, response = pcall(DataStore.GetAsync, DataStore, self.userId);

        if success and response then
            self.Cache[self.userId] = response;
            return self:getCache();
        else
            print("Failed to get data:", response);
        end;
    else
        return rawget(self.Cache, self.userId);
    end;
    
    return false;
end;

--/ Check if a player's session is valid
function leaderService:sessionCheck(): boolean
    local success, response = pcall(DataStore.GetAsync, DataStore, self.userId);

    if success then
        if response then
            if typeof(response.SessionId) == 'string' and #response.SessionId == 0 then
                print("User has no active session:", self.userId, response.SessionId);
                return true;
            elseif response.SessionId ~= game.JobId then
                print("Session ID does not match:", self.userId, response.SessionId);
                return false;
            else
                print("Data does not exist:", self.userId);
                return true;
            end;
        else
            print("Data does not exist:", self.userId);

            return true;
        end;
    else
        print("Failed to get data:", response);
    end;

    return true;
end;

--/ Create a player's leaderService object
function leaderService:createCache(): template
    assert(self.player and self.player:IsA("Player"), "Player must be a player object or exist.");

    local playerCache = table.clone(self.Template);

    self.Cache[self.userId] = playerCache;
    return rawget(self.Cache, self.userId);
end;

--/ Save a player's leaderService object
function leaderService:saveCache(): boolean
    local userName = Players:GetNameFromUserIdAsync(self.userId);

    -- Gets the player's cache
    local playerCache = self:getCache();

    if playerCache then
        local success, response = pcall(DataStore.UpdateAsync, DataStore, self.userId, function()
            return playerCache;
        end);

        if not success then
            print("Failed to save data:", response); -- Logs if the data failed to save
        else
            return success;
        end;
    else
        print("Failed to save data: Cache does not exist:", userName); -- Logs if the cache does not exist
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
                print("Failed to update stat:", object.Name, "Data does not exist.");
            end;
        end
    else
        print("Failed to update stats: Cache does not exist.");
    end;

    return false;
end;

--/ Create's the player's leaderStat value oobject(s)
function leaderService:createStats(): boolean
    local Leaderboard: Folder = self.Leaderboard;
    local playerCache = self:getCache();
    
    if playerCache then
        for name, value in playerCache.Data do
            local newValue = Instance.new("StringValue", Leaderboard);
            newValue.Name = name;
            newValue.Value = value;
        end
    else
        print("Failed to update stats: Cache does not exist.");
    end;

    return false;
end

--/ serverService object
local serverService: serverService = {
    Sessions = {},
    Shared = {
        Cache = {},
        Leaderboard = nil,
        userId = nil,
        player = nil
    };
};

--/ New serverService object
function serverService:New(player: Player): leaderServiceMeta<shared>
    local newSession = setmetatable(self.Shared, leaderService);
    newSession.player = player;
    newSession.userId = player.UserId;

    self.Sessions[player.UserId] = newSession;

    return newSession
end;

--/ Get a player's serverService object
function serverService:Get(player: Player): leaderServiceMeta<shared>
    return rawget(self.Sessions, player.UserId);
end;

--/ RemoteEvent OnServerEvent
local Events = {
    ['PurchaseItem'] = function(player: Player, event: string, item: string)
        local playerSession = serverService:Get(player);
        local playerCache = playerSession and playerSession:getCache();
        local validSession = playerSession and playerSession:sessionCheck();

        if playerCache and validSession then
            local itemObject= rawget(ShopList, item);

            if itemObject then
                if playerCache.Data.Coins >= itemObject.Price then
                    playerCache.Data.Coins = playerCache.Data.Coins - itemObject.Price;
                    playerSession:saveCache();

                    print("Purchased item:", item, player.UserId);

                    return true;
                else
                    print("Failed to purchase item: Not enough coins.", player.UserId);
                end;
            else
                print("Failed to purchase item: Item does not exist.", player.UserId);
            end;
        else
            print("Failed to get player cache:", player.UserId, 'evemt:', event);
        end;

        return false;
    end;
};

--/ ShopEvent OnServerEvent
ShopEvent.OnServerEvent:Connect(function(invoker: Player, event: string, item: string)
    local event = rawget(Events, event); --/ Gets the event from the Events table

    if not event then
        print("Event does not exist:", event, "Invoker:", invoker.UserId);
        return;
    end;

    --/ Executes the event
    local success, response = pcall(event, invoker, event, item);

    if not success then
        print("Failed to invoke event:", response, invoker.UserId);
    end;
end);

--/ PlayerAdded and PlayerRemoving
Players.PlayerAdded:Connect(function(player: Player)
    print("Creating session for player:", player.Name)

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
        if RunService:IsStudio() then
            playerCache.SessionId = HttpService:GenerateGUID(false);
        else
            playerCache.SessionId = game.JobId;
        end;

        --/ Saves the player's cache
        newSession:saveCache();
        newSession:createStats();

        print('Succesfully created session for player:', player.Name)
    else
        player:Kick("Failed to create session.");
    end;
end)

local function saveData(player)
    print("Ending session for player:", player.Name)

    local getSession = serverService:Get(player);

    if getSession then
        local getCache = getSession:getCache();

        if getCache then
            --/ Checks if the session ID matches the game's JobId
            if getCache.SessionId == game.JobId then
                getSession.SessionId = "";
                getSession:saveCache(); --/ Saves the player's cache

                print('Saved session data for:' , player.Name)
            else
                print("Session ID does not match:", player.UserId);
            end;
        end;
    end;

    task.wait(1);
end;

game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        coroutine.wrap(saveData)(player);
        task.wait(2);
    end;
end);

Players.PlayerRemoving:Connect(saveData);