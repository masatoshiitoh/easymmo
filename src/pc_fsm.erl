%%
%% pc_fsm.erl
%%
%% Easymmo one character fsm
%%
%% Start -> waiting -> Exit.
%%            | |
%%        oing action
%%

-module(pc_fsm).

-behavior(gen_fsm).

-include("emmo.hrl").

%% public API
-export([start_link/1]).
-export([start/1]).

%% gen_fsm callbacks
-export([init/1]).
-export([handle_event/3]).
-export([handle_sync_event/4]).
-export([handle_info/3]).
-export([terminate/3]).
-export([code_change/4]).

%% custom state names
-export([idle/2]).

%%
%% APIs
%%

%%
%% Behaviors
%%
start_link(Name) ->
	gen_server:start_link(?MODULE, [Name], []).

start(Name) ->
	gen_server:start(?MODULE, [Name], []).

init(Args) ->
    [Name] = Args,
	NewState = Name,
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.


idle(Event, _From, Data) ->
	{next_state, idle, Data}.



