%%
%% npc_script.erl
%%
%%

-module(npc_script).

-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([step/4]).

-define(MyBucket, <<"characters">>).

%%
%% APIs
%%

step(NamedId , CurrentLocation, CurrentNpcData, NearObjects) ->
	Reply = gen_server:call(?MODULE, {step, NamedId , CurrentLocation, CurrentNpcData, NearObjects}).

%%
%% Utlities
%%


choose_action(CurrentLocation, NpcData, NearObjects) -> 
	MemoryNearObjects = NpcData#character.near_objects,
	NewComers = lists:subtract(NearObjects , MemoryNearObjects),
	Lefts = lists:subtract(MemoryNearObjects, NearObjects),

	case length(NearObjects) > 3 of
		true ->
			move_random_rel(CurrentLocation);
			%%nop_abs -> move_random_abs(CurrentLocation)

		_ ->
			choose_greeting(NewComers, Lefts)
	end.

move_random_rel(_CurrentLocation) -> {move, {rel, -2 + random:uniform(5), -2 + random:uniform(5)}}.
move_random_abs(CurrentLocation) -> {move, CurrentLocation#loc{x= 10001, y = 10002}}.

choose_greeting(NewComers, Lefts) ->
	NumNewComer = length(NewComers),
	case NumNewComer of
		1 -> [H|T] = NewComers,
			{say_hello, H};
		_ -> 
			NumLeft = length(Lefts),
			case NumLeft of
				1 -> [H|T] = Lefts,
					{say_goodbye, H};
				_ -> nop
			end
	end.

%%
%% Behaviors
%%
start_link(RiakIp, RiakPort) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [RiakIp, RiakPort], []).

init(Args) ->
    [RiakIp, RiakPort] = Args,
	{ok, Pid} = riakc_pb_socket:start(RiakIp, RiakPort),
	NewState = {Pid, []},
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.

handle_call({step, NamedId, CurrentLocation, CurrentNpcData, NearObjects}, From, State) ->
	{Pid, Npcs} = State,

	NextAction = choose_action(CurrentLocation, CurrentNpcData, NearObjects),

	{reply, {ok, NextAction}, State}.

