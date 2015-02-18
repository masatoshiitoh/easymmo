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
	rutil(),
	path_finder(),
	emmo_map(),
	emmo_char(),
	notifier(),
	npc_pool(),
	npc_script(),
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

notifier() ->
	notifier_one().

notifier_one() ->
	ID = notifier,
	StartFunc = {notifier, start_link, []},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [notifier],
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

npc_script() ->
	npc_script_one("192.168.56.11", 8087).

npc_script_one(RiakIp, RiakPort) ->
	ID = npc_script,
	StartFunc = {npc_script, start_link, [RiakIp, RiakPort]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [npc_script],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

emmo_map() ->
	emmo_map_one("192.168.56.11", 8087).

emmo_map_one(RiakIp, RiakPort) ->
	ID = emmo_map,
	StartFunc = {emmo_map, start_link, [RiakIp, RiakPort]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [emmo_map],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.


emmo_char() ->
	emmo_char_one("192.168.56.11", 8087).

emmo_char_one(RiakIp, RiakPort) ->
	ID = emmo_char,
	StartFunc = {emmo_char, start_link, [RiakIp, RiakPort]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [emmo_char],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

rutil() ->
	rutil_one("192.168.56.11", 8087).

rutil_one(RiakIp, RiakPort) ->
	ID = rutil,
	StartFunc = {rutil, start_link, [RiakIp, RiakPort]},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [rutil],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.



path_finder() ->
	path_finder_one().

path_finder_one() ->
	ID = path_finder,
	StartFunc = {path_finder, start_link, []},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [path_finder],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.



