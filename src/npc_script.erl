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

-export([step/3]).

-define(MyBucket, <<"characters">>).

%%
%% APIs
%%

step(NamedId , CurrentNpcData, NearObjects) ->
	Reply = gen_server:call(?MODULE, {step, NamedId , CurrentNpcData, NearObjects}).

%%
%% Utlities
%%

choose_action(NpcData, NearObjects) -> 

	MemoryNearObjects = NpcData#character.near_objects,
	NewComers = lists:subtract(NearObjects , MemoryNearObjects),
	Lefts = lists:subtract(MemoryNearObjects, NearObjects),

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

handle_call({step, NamedId, CurrentNpcData, NearObjects}, From, State) ->
	{Pid, Npcs} = State,

	NextAction = choose_action(CurrentNpcData, NearObjects),

	{reply, {ok, NextAction}, State}.

