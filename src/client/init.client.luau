--[[

local ReplicatedStorage = game:GetService('ReplicatedStorage');
local Roact = require(ReplicatedStorage.Shared.roact);

-- Create our virtual tree describing a full-screen text label.
local tree = Roact.createElement("ScreenGui", {}, {
	MainFrame = Roact.createElement("Frame", {
        Size = UDim2.new(0.15, 0, 0.1, 0),
        Position = UDim2.new(0.05, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, .5),
        BackgroundTransparency = 0.65
	}, {
        Constraint = Roact.createElement("UIAspectRatioConstraint", {
            AspectRatio = 3.827,
            AspectType = Enum.AspectType.FitWithinMaxSize,
            DominantAxis = Enum.DominantAxis.Width
        }),

        Layout = Roact.createElement("UIListLayout", {
            Wraps = true,
            FillDirection = Enum.FillDirection.Horizontal
        }),
        
        Image = Roact.createElement("ImageLabel", {
            Image = "rbxassetid://18510113479",
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = 1
        });

        NewLabel = Roact.createElement("TextLabel", {
            Text = "0",
            Size = UDim2.new(0.5, 0, 1, 0),
            TextScaled = true,
            BackgroundTransparency = 1,
            TextColor3 = Color3.new(1, 1, 1),
            LayoutOrder = 2
        });
    });
})

-- Turn our virtual tree into real instances and put them in PlayerGui
Roact.mount(tree, game.Players.LocalPlayer.PlayerGui, "CoinGui")
]] -- Roact

local Players = game:GetService('Players');
local ReplicatedStorage = game:GetService('ReplicatedStorage');

local ShopList = require(ReplicatedStorage.Shared.ShopList);

local LocalPlayer = Players.LocalPlayer;
local PlayerGUi = LocalPlayer.PlayerGui;

local ShopGui = PlayerGUi:WaitForChild('ShopGui');
local Frame = ShopGui:WaitForChild('Frame');
local ScrollingFrame = Frame:WaitForChild('ScrollingFrame');

local oTemplate, cTemplate = ScrollingFrame:WaitForChild('Template'), nil;
cTemplate = oTemplate:Clone();
oTemplate:Destroy();

for name, data: {
    [string]: {
        Price: number,
        Description: string,
        Image: string
    };
} in pairs(ShopList) do
    local newItem = cTemplate:Clone();
    newItem.Price.Text = string.format('[%s] Coins', data.Price);
    newItem.ItemIcon.Image = data.Image;

    newItem.Btn.MouseButton1Click:Connect(function()
        print('Buying', name)
    end);

    newItem.Name = name;
    newItem.Parent = ScrollingFrame;
end;