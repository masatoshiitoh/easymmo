%%
%% npc_script.erl
%%
%%

-module(npc_script).

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

choose_action(NpcData, {ok, NearObjects}) -> 
	NumObjects = length(NearObjects),
	%% in many characters
	case NumObjects > 4 of
		true -> {say, "crowd!"};
		_ -> {say, "ok"}
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

	% Select next action
	NextAction = choose_action(CurrentNpcData, NearObjects),

	io:format("NextAction : ~p~n", [NextAction]),

	{reply, {ok, NextAction}, State}.

