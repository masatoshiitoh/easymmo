%%
%% npc_pool.erl
%%
%%

-module(npc_pool).

-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([reset/0]).
-export([list_all/0]).
-export([remove_all/0]).
-export([add/0]).
-export([remove/1]).
-export([online/1]).
-export([offline/1]).
-export([is_on/1]).
-export([lookup/1]).
-export([run/0]).
-export([run/1]).

-define(MyBucket, <<"characters">>).

%%
%% APIs
%%

reset() ->
	npc_pool:remove_all(),
	emmo_map:remove_all(),
	npc_pool:run().


remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

list_all() ->
	Reply = gen_server:call(?MODULE, {list_all}).

add() ->
	Reply = gen_server:call(?MODULE, {add, auto_increment}).

remove(NamedId) ->
	Reply = gen_server:call(?MODULE, {remove, NamedId}).

online(NamedId) ->
	Reply = gen_server:call(?MODULE, {online, NamedId}).

offline(NamedId) ->
	Reply = gen_server:call(?MODULE, {offline, NamedId}).

is_on(NamedId) ->
	Reply = gen_server:call(?MODULE, {is_on, NamedId}).

lookup(NamedId) ->
	Reply = gen_server:call(?MODULE, {lookup, NamedId}).

run() ->
	Reply = gen_server:call(?MODULE, {run, 1000}).

run(IntervalMSec) ->
	Reply = gen_server:call(?MODULE, {run, IntervalMSec}).

%%
%% Utlities
%%

get_new_npc() ->
	{ok, V} = emmo_char:new("npc"),
	V.

get_new_location() ->
	{ok, V} = emmo_map:npc_new_location(),
	V.

lookup_impl(Pid, NamedId) when is_list(NamedId)->
	BinId = erlang:list_to_binary(NamedId),
	lookup_impl(Pid, BinId);

lookup_impl(Pid, BinId) when is_binary(BinId) ->
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)).

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

handle_call({add, auto_increment}, From, State) ->
	{Pid, Npcs} = State,
	NamedId = rutil:named_id("npc", rutil:auto_increment("npc")),
	BinId = erlang:list_to_binary(NamedId),
	NewNpc = get_new_npc(),
	NewNpc2 = NewNpc#character{name  = "goba" ++ integer_to_list( random:uniform(10000))},
	Obj1 = riakc_obj:new(?MyBucket, BinId, NewNpc2),
	riakc_pb_socket:put(Pid, Obj1),
	NewState = {Pid, [NamedId | Npcs]},

	NewLoc = get_new_location(), 
	emmo_map:add(NamedId, NewLoc),

	{reply, {ok, NamedId}, NewState};

handle_call({list_all}, From, State) ->
	{Pid, Npcs} = State,
	Result = riakc_pb_socket:list_keys(Pid, ?MyBucket),
	{reply, Result, State};

handle_call({remove_all}, From, State) ->
	{Pid, Npcs} = State,
	io:format("remove_all called -> Npcs = ~p~n", [Npcs]),
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, ?MyBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, ?MyBucket, X),
		emmo_map:remove(X)
		end,
	BinKeys),
	{reply, Result, {Pid, []}};

handle_call({remove, BinId}, From, State) when is_binary(BinId)->
	{Pid, Npcs} = State,
	NamedId = erlang:binary_to_list(BinId),
	NewState = {Pid, lists:delete(NamedId , Npcs)},
	riakc_pb_socket:delete(Pid, ?MyBucket, BinId),
	emmo_map:remove(NamedId),
	{reply, {ok, NamedId}, NewState};

handle_call({remove, NamedId}, From, State) ->
	{Pid, Npcs} = State,
	NewState = {Pid, lists:delete(NamedId , Npcs)},
	BinId = erlang:list_to_binary(NamedId),
	riakc_pb_socket:delete(Pid, ?MyBucket, BinId),
	emmo_map:remove(NamedId),
	{reply, {ok, NamedId}, NewState};

handle_call({online, NamedId}, From, State) ->
	{Pid, Npcs} = State,
	BinId = erlang:list_to_binary(NamedId),
	{ok, _} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),	%% check if key existing "BinId"
	NewState = {Pid, [NamedId | Npcs]},
	{reply, ok, NewState};

handle_call({offline, NamedId}, From, State) ->
	{Pid, Npcs} = State,
	NewState = {Pid, lists:delete(NamedId , Npcs)},
	{reply, {ok, NamedId}, NewState};

handle_call({is_on, NamedId}, From, State) ->
	{_, Npcs} = State,
	{reply, {ok, lists:member(NamedId , Npcs)}, State};

handle_call({lookup, NamedId}, From, State) ->
	{Pid, Npcs} = State,
	Val1 = lookup_impl(Pid, NamedId),
	{reply, {ok, Val1}, State};

handle_call({run, IntervalMSec}, From, State) ->
	{Pid, Npcs} = State,
	Val1 = lists:map(
		fun(X) ->
			BinId = erlang:list_to_binary(X),
			{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
			Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),

			% Get current NPC data.
			CurrentNpcData = lookup_impl(Pid, X),
			%% io:format("CurrentNpc : ~p~n", [CurrentNpcData]),

			% Get sensor data ( = now, this is get from map )
			{ok, NearObjects} = emmo_map:get_near_objects(X),
			%% io:format("NearObjects : ~p~n", [NearObjects]),

			{ok, CurrentLocation} = emmo_map:lookup(X),

			Step = npc_script:step(Val1 , CurrentLocation, CurrentNpcData, NearObjects),
			case Step of
				{ok, nop} -> nop;
				{ok, {say_hello, NewId}} ->
					NewComer = lookup_impl(Pid, NewId),
					io:format("[~p] hello, ~p~n", [CurrentNpcData#character.name, NewComer#character.name]),
					Msg = io_lib:format("hello, ~p", [NewComer#character.name]),
					chat_srv:broadcast(X, Msg);
				{ok, {say_goodbye, LeftId}} ->
					%%NewComer = lookup_impl(Pid, LeftId),
					io:format("[~p] bye~n", [CurrentNpcData#character.name]),
					Msg = io_lib:format("bye ~p", [binary_to_list(LeftId)]),
					chat_srv:broadcast(X, Msg);
				{ok, {move, {rel, DeltaX, DeltaY}}} ->
					NewX = CurrentLocation#loc.x + DeltaX,
					NewY = CurrentLocation#loc.y + DeltaY,
					NewLoc = CurrentLocation#loc{x = NewX, y = NewY},
					emmo_map:move(X, NewLoc),
					io:format("[~p] move rel ~p~n", [ CurrentNpcData#character.name, {DeltaX, DeltaY}]),
					move_srv:move_rel(X, DeltaX, DeltaY);
				_ -> io:format("unknown : [~p] ~p~n", [X, Step])
			end,

			%% Store latest NearObjects to CurrentNpcData
			Memoried1 = Val1#character{near_objects = NearObjects, bye = []},
			Updated1 = riakc_obj:update_value(Fetched1, Memoried1),
			riakc_pb_socket:put(Pid, Updated1, [return_body])
		end,
		Npcs),
	notifier:add(IntervalMSec, {mfa, npc_pool, run, [IntervalMSec]}),
	{reply, {ok, Val1}, State}.


