local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")
local Enemies = workspace:WaitForChild("Enemies")
local Characters = workspace:WaitForChild("Characters")

_G.FastAttack = _G.FastAttack ~= false
_G.FastAttackDelay = _G.FastAttackDelay or 0.02
_G.AutoShoot = _G.AutoShoot ~= false
_G.GunRange = _G.GunRange or 500
_G.MeleeRange = _G.MeleeRange or 60

local remote, idremote
local function scanRemote(n)
    if n:IsA("RemoteEvent") and n:GetAttribute("Id") then
        remote, idremote = n, n:GetAttribute("Id")
    end
end
for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
    for _, n in next, v:GetChildren() do
        scanRemote(n)
    end
    v.ChildAdded:Connect(scanRemote)
end

local function IsAlive(character)
    return character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0
end

local function ProcessEnemies(OthersEnemies, Folder)
    for _, Enemy in Folder:GetChildren() do
        if Enemy == Player.Character then continue end
        local Head = Enemy:FindFirstChild("Head")
        if Head and IsAlive(Enemy) and Player:DistanceFromCharacter(Head.Position) < _G.GunRange then
            table.insert(OthersEnemies, { Enemy, Head })
        end
    end
end

local function GetGunTarget()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local nearest, dist = nil, _G.GunRange

    for _, folder in ipairs({Enemies, Characters}) do
        for _, mob in ipairs(folder:GetChildren()) do
            if mob == char then continue end
            local hrp = mob:FindFirstChild("HumanoidRootPart")
            if hrp and IsAlive(mob) then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = hrp
                end
            end
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and IsAlive(p.Character) then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = hrp
                end
            end
        end
    end

    return nearest
end

local function findNetRemote(name)
    local r = Net:FindFirstChild(name)
    if r then return r end
    for _, v in ipairs(Net:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == name then return v end
    end
end

local function UltraShootGun(targetHRP)
    if not targetHRP then return end
    local char = Player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WeaponType") ~= "Gun" then return end

    local RE_ShootGunEvent = findNetRemote("RE/ShootGunEvent")
    if RE_ShootGunEvent then
        pcall(function()
            RE_ShootGunEvent:FireServer(targetHRP.Position, {targetHRP})
        end)
    end

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

task.spawn(function()
    while task.wait(_G.FastAttackDelay) do
        if not _G.FastAttack then continue end

        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then continue end

        local WType = tool:GetAttribute("WeaponType")

        if WType == "Gun" then
            if _G.AutoShoot then
                local targetHRP = GetGunTarget()
                if targetHRP then
                    UltraShootGun(targetHRP)
                end
            end
            continue
        end

        local OthersEnemies = {}
        ProcessEnemies(OthersEnemies, Enemies)
        ProcessEnemies(OthersEnemies, Characters)

        if WType == "Melee" or WType == "Sword" then
            local parts = {}
            for _, enemyData in ipairs(OthersEnemies) do
                local enemy = enemyData[1]
                local ehrp = enemy:FindFirstChild("HumanoidRootPart")
                if not ehrp then continue end
                if (ehrp.Position - root.Position).Magnitude > _G.MeleeRange then continue end
                for _, bp in ipairs(enemy:GetChildren()) do
                    if bp:IsA("BasePart") then
                        table.insert(parts, {enemy, bp})
                    end
                end
            end

            if #parts > 0 and remote and idremote then
                pcall(function()
                    require(Modules.Net):RemoteEvent("RegisterHit", true)

                    local registerAttack = findNetRemote("RE/RegisterAttack")
                    if registerAttack then registerAttack:FireServer() end

                    local head = parts[1][1]:FindFirstChild("Head")
                    if not head then return end

                    local registerHit = findNetRemote("RE/RegisterHit")
                    if registerHit then
                        registerHit:FireServer(head, parts, {}, tostring(Player.UserId):sub(2,4)..tostring(coroutine.running()):sub(11,15))
                    end

                    local seed = 0
                    if Net:FindFirstChild("seed") then
                        seed = Net.seed:InvokeServer()
                    end

                    cloneref(remote):FireServer(
                        string.gsub("RE/RegisterHit", ".", function(c)
                            return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow() / 10 % 10) + 1))
                        end),
                        bit32.bxor(idremote + 909090, seed * 2),
                        head,
                        parts
                    )
                end)
            end
        end
    end
end)