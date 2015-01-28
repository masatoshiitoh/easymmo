-module(easymmo_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
	ChildSpec = [
	%%npc_pool(),
	time_feeder(), 
	chat_srv(),
	move_srv()
	],
    {ok, { {one_for_one, 5, 10}, ChildSpec} }.

time_feeder() ->
	time_feeder_one("192.168.56.21", <<"time">> ).

time_feeder_one(IpAddr, ToClientEx) ->
	ID = time_feeder,
	StartFunc = {time_feeder, start_link, [IpAddr, ToClientEx]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [time_feeder],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.


chat_srv() ->
	chat_srv_one("192.168.56.21", <<"xout">>, <<"xin">> ).

chat_srv_one(ServerIp, ToClientEx, FromClientEx) ->
	ID = chat_srv,
	StartFunc = {chat_srv, start_link, [ServerIp, ToClientEx, FromClientEx]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [chat_srv],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

move_srv() ->
	move_srv_one("192.168.56.21", <<"xout">>, <<"xin">> ).

move_srv_one(ServerIp, ToClientEx, FromClientEx) ->
	ID = move_srv,
	StartFunc = {move_srv, start_link, [ServerIp, ToClientEx, FromClientEx]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [move_srv],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

npc_pool() ->
	npc_pool_one("192.168.56.11", 8087).

npc_pool_one(RiakIp, RiakPort) ->
	ID = npc_pool,
	StartFunc = {npc_pool, start_link, [RiakIp, RiakPort]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [npc_pool],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

