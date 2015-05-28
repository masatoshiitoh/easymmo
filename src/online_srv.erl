%%
%% online_srv.erl
%%
%% this module keep online players information. Key = Uid, Value = fsm pid.
%%

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

init(Args) ->
    [] = Args,
	{ok, []}.

terminate(_Reason, State) ->
	%% TODO: kill all FSMs.
	ok.

handle_call({add, Uid, Pid}, From, State) ->
	{reply, ok, State};

handle_call({del, Uid}, From, State) ->
	{reply, ok, State};

handle_call({lookup, Uid}, From, State) ->
	Pid = ng,
	{reply, {ok, Pid}, State}.



