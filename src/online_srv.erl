%%
%% online_srv.erl
%%
%% this module keep online players information. Key = Uid, Value = fsm pid.
%% gen_server's State = dictionary()

-module(online_srv).

-export([start_link/0]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([del/1]).
-export([lookup/1]).

%%
%% APIs
%%

add(Uid, Pid) ->
	Reply = gen_server:call(?MODULE, {add, Uid, Pid}).

del(Uid) ->
	Reply = gen_server:call(?MODULE, {del, Uid}).

lookup(Uid) ->
	Reply = gen_server:call(?MODULE, {lookup, Uid}).

%%
%% Behaviors
%%
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, dict:new()}.

terminate(_Reason, State) ->
	%%
	%% TODO: kill all FSMs.
	%%

	ok.

%%
%% TODO: announce "remove existing FSM PID" to system.
%%
handle_call({add, Uid, Pid}, From, State) ->
	Dict = State,
	Dict2 = case dict:find(Uid, Dict) of
		{ok, Pid} -> dict:store(Uid, Pid, dict:erase(Uid, Dict));
		error -> dict:store(Uid, Pid, Dict);
		_ -> Dict
	end,
	{reply, ok, Dict2};

handle_call({del, Uid}, From, State) ->
	Dict = State,
	Dict2 = dict:erase(Uid, Dict),
	{reply, ok, Dict2};

handle_call({lookup, Uid}, From, State) ->
	Dict = State,
	Result = dict:find(Uid, Dict),
	{reply, {ok, Result}, State}.



