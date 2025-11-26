--Services--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")


--Modules--

local Types = require(script.Parent.Types)


--Module--

local Callbacks = {}


--Public Functions--

--Creates a callback
function Callbacks.CreateCallback(NetworkInfo: Types.NetworkInfo, Threads: Types.Threads)
	local Folder = ReplicatedStorage:FindFirstChild("NetworkRemotes")

	if not Folder then
		Folder = Instance.new("Folder")
		Folder.Name = "NetworkRemotes"
		Folder.Parent = ReplicatedStorage
	end
	
	local Remote = Folder:FindFirstChild(NetworkInfo.Name)

	if not Remote then
		Remote = Instance.new("RemoteEvent")
		Remote.Name = NetworkInfo.Name
		Remote.Parent = Folder
	end

	if RunService:IsServer() then
		Remote.OnServerEvent:Connect(function(...)

			local Arguments = {...}

			if table.find(Arguments, "__return") then return end

			for _, Player in ipairs(NetworkInfo.Target) do
				Remote:FireClient(Player, NetworkInfo.ReturnToClient(...), "__return")
			end

			for _, func in Threads.Server do
				func(...)
			end

			NetworkInfo.ServerFunction(...)
		end)
	end

	if RunService:IsClient() then
		Remote.OnClientEvent:Connect(function(...)
			local Arguments = {...}

			if table.find(Arguments, "__return") then return end

			Remote:FireServer(NetworkInfo.ReturnToServer(...), "__return")

			for _, func in Threads.Client do
				func(...)
			end

			NetworkInfo.ClientFunction(...)
		end)
	end
	
	
	return Remote
end


return Callbacks
