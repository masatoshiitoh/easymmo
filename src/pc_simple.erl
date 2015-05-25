-module(pc_simple).
-behaviour(gen_fsm).

-export([start_link/1, stop/0]).
-export([attack/1, get_state/0]).
-export([init/1, good/2, dead/2]).
-export([handle_event/3, terminate/3]).
-export([handle_sync_event/4, handle_info/3, code_change/4]).

start_link(Hp) -> gen_fsm:start_link({local, pc_simple}, pc_simple, Hp, []).

stop() -> gen_fsm:send_all_state_event(pc_simple, stop).

attack(Damage) -> gen_fsm:send_event(pc_simple, {attack, Damage}).

get_state() -> gen_fsm:sync_send_all_state_event(pc_simple, get_state).

init(StartHp) -> {ok, good, {stat, StartHp}}.

good({attack, Damage}, {stat, Hp}) ->
	NewHp = Hp - Damage,
	if
		NewHp < 1  ->
			io:fwrite("uncon!!~n"),
            {next_state, dead, {stat, NewHp}, 3000};

        true ->
            {next_state, good, {stat, NewHp}}
    end.

dead(timeout, StateData) ->
    io:fwrite("respawn!!~n"),
    {next_state, good, {stat, 1}}.

handle_event(stop, _StateName, StateData) -> {stop, normal, StateData}.
terminate(normal, _StateName, _StateData) -> ok.

handle_sync_event(get_state, _From, StateName, StateData) ->
    {reply, StateName, StateName, StateData}.

handle_info(_Info, StateName, StateData) -> {next_state, StateName, StateData}.
code_change(_OldVsn, StateName, StateData, _Extra) -> {ok, StateName, StateData}.
