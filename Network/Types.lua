export type NetworkInfo = {
	NetworkingDirection: "ClientToServer"|"ServerToClient"|"any", --Great if you don't want any accidents to happen

	Name: string, --Name of the remote

	ServerFunction: (any) -> (any),
	ClientFunction: (any) -> (any),

	ReturnToServer: (any) -> (any), --Fires when server fires the remote, the client fires to server back with data
	ReturnToClient: (any) -> (any), --Fires when client fires the remote, the server fires to client back with data

	Target: {Player}|nil --Will fire all clients if nil
}

export type Threads = {
	Server: {() -> ()},
	Client: {() -> ()}
}

return {}
