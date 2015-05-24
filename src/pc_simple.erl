-module(pc_simple).
-behaviour(gen_fsm).

-export([start_link/1, stop/0]).
-export([button/1, get_state/0]).
-export([init/1, locked/2, open/2]).
-export([handle_event/3, terminate/3]).
-export([handle_sync_event/4, handle_info/3, code_change/4]).

start_link(HP) -> gen_fsm:start_link({local, pc_simple}, pc_simple, HP, []).

stop() -> gen_fsm:send_all_state_event(pc_simple, stop).

button(String) -> gen_fsm:send_event(pc_simple, {button, String}).

get_state() -> gen_fsm:sync_send_all_state_event(pc_simple, get_state).

init(Code) -> {ok, locked, {[], Code}}.

locked({button, String}, {SoFar, Code}) ->
    case SoFar ++ String of
        Code ->
            io:fwrite("open!!~n"),
            {next_state, open, {[], Code}, 3000};
        Incomplete when length(Incomplete)<length(Code) ->
            {next_state, locked, {Incomplete, Code}};
        _Wrong ->
            {next_state, locked, {[], Code}}
    end.

open(timeout, StateData) ->
    io:fwrite("close!!~n"),
    {next_state, locked, StateData}.

handle_event(stop, _StateName, StateData) -> {stop, normal, StateData}.
terminate(normal, _StateName, _StateData) -> ok.

handle_sync_event(get_state, _From, StateName, StateData) ->
    {reply, StateName, StateName, StateData}.

handle_info(_Info, StateName, StateData) -> {next_state, StateName, StateData}.
code_change(_OldVsn, StateName, StateData, _Extra) -> {ok, StateName, StateData}.
