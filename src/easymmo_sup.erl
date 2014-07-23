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
	ChildSpec = [time_feeder()],
    {ok, { {one_for_one, 5, 10}, ChildSpec} }.

time_feeder() ->
	ID = time_feeder,
	StartFunc = {time_feeder, start_link, []},
	Restart = permanent,
	Shutdown = brutal_kill,
	Type = worker,
	Modules = [time_feeder],
	_ChildSpec = {ID, StartFunc, Restart, Shutdown, Type, Modules}.

