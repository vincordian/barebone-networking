--Services--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")


--Modules--

local Types = require(script.Parent.Types)


--Module--

local Callbacks = {}


--Public Functions--

--Creates a callback
function Callbacks.CreateCallback(NetworkInfo: Types.NetworkInfo)


	local Folder = ReplicatedStorage:FindFirstChild("NetworkRemotes")

	if not Folder then
		if RunService:IsClient() then
			Folder = ReplicatedStorage:WaitForChild("NetworkRemotes", 5)
			assert(Folder, "No folder for network found.")
		else
			Folder = Instance.new("Folder")
			Folder.Name = "NetworkRemotes"
			Folder.Parent = ReplicatedStorage
		end
	end

	local Remote = Folder:FindFirstChild(NetworkInfo.Name)

	if not Remote then
		if RunService:IsClient() then
			Remote = Folder:WaitForChild(NetworkInfo.Name, 5)
			assert(Remote, "No remote for network found.")
		else
			Remote = Instance.new("RemoteEvent")
			Remote.Name = NetworkInfo.Name
			Remote.Parent = Folder
		end
	end

	NetworkInfo.Remote = Remote

	if RunService:IsServer() then
		NetworkInfo.Remote.OnServerEvent:Connect(function(...)

			if NetworkInfo.ServerFunctionCalledOnReturn then
				NetworkInfo.ServerFunction(...)
			end

			local Arguments = {...}
			if table.find(Arguments, "__return") then return end

			NetworkInfo.ServerFunction(...)

			for _, Player in ipairs(NetworkInfo.Target) do
				NetworkInfo.Remote:FireClient(Player, NetworkInfo.ReturnToClient(...), "__return")
			end

			for _, func in NetworkInfo.Threads.Server do
				func(...)
			end
		end)
	end

	if RunService:IsClient() then
		NetworkInfo.Remote.OnClientEvent:Connect(function(...)

			if NetworkInfo.ClientFunctionCalledOnReturn then
				NetworkInfo.ClientFunction(...)
			end

			local Arguments = {...}
			if table.find(Arguments, "__return") then return end

			NetworkInfo.ClientFunction(...)

			Remote:FireServer(NetworkInfo.ReturnToServer(...), "__return")

			for _, func in NetworkInfo.Threads.Client do
				func(...)
			end
		end)
	end

	return Remote
end


--Clears the remote
function Callbacks.ClearRemote(Remote)
	Remote:Destroy()
end


return Callbacks
