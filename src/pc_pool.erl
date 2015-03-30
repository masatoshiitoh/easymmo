%%
%% pc_pool.erl
%%
%%

-module(pc_pool).

-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([test/0]).
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

test() ->
	reset(),
	add(),
	add(),
	add(),
	add(),
	add().

reset() ->
	pc_pool:remove_all(),
	emmo_map:remove_all(),
	pc_pool:run().


remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

list_all() ->
	Reply = gen_server:call(?MODULE, {list_all}).

add() ->
	Reply = gen_server:call(?MODULE, {add, auto_increment}).

remove(NamedId) when is_list(NamedId) ->
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

get_new_pc() ->
	{ok, V} = emmo_char:new("pc"),
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

remove_impl(Pid, NamedId, Pcs) when is_list(NamedId) ->
	NewPcs = lists:delete(NamedId , Pcs),
	BinId = list_to_binary(NamedId),
	riakc_pb_socket:delete(Pid, ?MyBucket, BinId),
	emmo_map:remove(NamedId),
	object_srv:del(NamedId),
	{ok, NewPcs}.


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
	{Pid, Pcs} = State,
	NamedId = rutil:named_id("pc", rutil:auto_increment("pc")),
	BinId = erlang:list_to_binary(NamedId),
	NewPc = get_new_pc(),
	NewPc2 = NewPc#character{name  = "pc" ++ integer_to_list( random:uniform(10000))},
	Obj1 = riakc_obj:new(?MyBucket, BinId, NewPc2),
	riakc_pb_socket:put(Pid, Obj1),
	NewState = {Pid, [NamedId | Pcs]},

	NewLoc = get_new_location(), 
	emmo_map:add(NamedId, NewLoc),

	object_srv:add(NamedId),

	{reply, {ok, NamedId}, NewState};

handle_call({list_all}, From, State) ->
	{Pid, Pcs} = State,
	Result = riakc_pb_socket:list_keys(Pid, ?MyBucket),
	TextResult = rutil:keys_to_lists(Result),
	{reply, TextResult, State};

handle_call({remove_all}, From, State) ->
	{Pid, Pcs} = State,
	io:format("remove_all called -> Pcs = ~p~n", [Pcs]),
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, ?MyBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, ?MyBucket, X),
		emmo_map:remove(X)
		end,
	BinKeys),
	{reply, Result, {Pid, []}};

handle_call({remove, NamedId}, From, State) when is_list(NamedId) ->
	{Pid, Pcs} = State,
	{ok, NewPcs} = remove_impl(Pid, NamedId, Pcs),
	NewState = {Pid, NewPcs},
	{reply, {ok, NamedId}, NewState};

handle_call({online, NamedId}, From, State) when is_list(NamedId) ->
	{Pid, Pcs} = State,
	BinId = erlang:list_to_binary(NamedId),
	{ok, _} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),	%% check if key existing "BinId"
	NewState = {Pid, [NamedId | Pcs]},
	{reply, ok, NewState};

handle_call({offline, NamedId}, From, State) when is_list(NamedId) ->
	{Pid, Pcs} = State,
	NewState = {Pid, lists:delete(NamedId , Pcs)},
	{reply, {ok, NamedId}, NewState};

handle_call({is_on, NamedId}, From, State) when is_list(NamedId) ->
	{_, Pcs} = State,
	{reply, {ok, lists:member(NamedId , Pcs)}, State};

handle_call({lookup, NamedId}, From, State) when is_list(NamedId) ->
	{Pid, Pcs} = State,
	Val1 = lookup_impl(Pid, NamedId),
	{reply, {ok, Val1}, State};

handle_call({run, IntervalMSec}, From, State) ->
	{Pid, Pcs} = State,
	%% io:format("run Pcs : ~p~n", [Pcs]),
	Val1 = lists:map(
		fun(X) ->
			BinId = erlang:list_to_binary(X),
			{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
			Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),

			% Get current NPC data.
			CurrentPcData = lookup_impl(Pid, X),
			%%io:format("CurrentPc : ~p~n", [CurrentPcData]),

			% Get sensor data ( = now, this is get from map )
			{ok, NearObjects} = emmo_map:get_near_objects(X),
			%%io:format("NearObjects : ~p~n", [NearObjects]),

			{ok, CurrentLocation} = emmo_map:lookup(X),

			Step = {ok, nop},		%% TODO: set command handler here
			case Step of
				{ok, nop} -> nop;
				_ -> io:format("unknown : [~p] ~p~n", [X, Step])
			end,

			%% Store latest NearObjects to CurrentPcData
			Memoried1 = Val1#character{near_objects = NearObjects, bye = []},
			Updated1 = riakc_obj:update_value(Fetched1, Memoried1),
			riakc_pb_socket:put(Pid, Updated1, [return_body])
		end,
		Pcs),
	notifier:add(IntervalMSec, {mfa, pc_pool, run, [IntervalMSec]}),
	{reply, {ok, Val1}, State}.


