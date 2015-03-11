%%
%% emmo_map.erl
%%
%% Easymmo map manager (all objects must be place to the map)

-module(emmo_map).
% -include_lib("amqp_client.hrl").
-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([remove_all/0]).
-export([remove/1]).
-export([move/2]).
-export([lookup/1]).
-export([npc_new_location/0]).
-export([lookup_by_map/1]).
-export([get_near_objects/1]).
-export([get_near_objects/2]).
-export([test/0]).


%%
%% APIs
%%
test() ->
	L1 = #loc{map_id = 1, x=99, y=88},
	L2 = #loc{map_id = 2, x=99, y=88},
	L3 = #loc{map_id = 2, x=98, y=89},
	add("i1", L1),
	add("i2", L2),
	add("i3", L3),
	io:format("lookup(i1) : ~p~n", [lookup("i1")]),
	io:format("id 1 : ~p~n", [lookup_by_map(1)]),
	io:format("map 1 : ~p~n", [lookup_by_map(1)]),
	io:format("map 2 : ~p~n", [lookup_by_map(2)]),
	io:format("map 1 is only i1 : ~p~n", [get_near_objects("i1")]),
	io:format("map 2 have i2 and i3: ~p~n", [get_near_objects("i2")]).

add(Id, L) when is_record(L, loc) ->
	Reply = gen_server:call(?MODULE, {add, Id, L}).

remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

remove(Id) ->
	Reply = gen_server:call(?MODULE, {remove, Id}).

move(Id, NewL) when is_record(NewL, loc) ->
	Reply = gen_server:call(?MODULE, {move, Id, NewL}).

lookup(Id) ->
	Reply = gen_server:call(?MODULE, {lookup, Id}).

npc_new_location() ->
	Reply = gen_server:call(?MODULE, {new_location, "npc"}).

lookup_by_map(MapId) when is_integer(MapId) ->
	Reply = gen_server:call(?MODULE, {lookup_with_integer, "map_id", MapId}).

get_near_objects(Id) ->
	Reply = gen_server:call(?MODULE, {get_near_objects, Id, 10}).

get_near_objects(Id, Distance) ->
	Reply = gen_server:call(?MODULE, {get_near_objects, Id, Distance}).

%%
%% Utilities
%%

distance(X1, Y1, X2, Y2) ->
	Dx = X1 - X2,
	Dy = Y1 - Y2,
	math:sqrt(Dx * Dx + Dy * Dy).


%%
%% Behaviors
%%
start_link(RiakIp, RiakPort) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [RiakIp, RiakPort], []).

init(Args) ->
    [RiakIp, RiakPort] = Args,
	{ok, Pid} = riakc_pb_socket:start(RiakIp, RiakPort),
	NewState = Pid,
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.

handle_call({add, Id, V}, From, State) when is_list(Id) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinId = erlang:list_to_binary(Id),
	Obj1 = riakc_obj:new(MyBucket, BinId, V),
	io:format("~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("~p~n", [MetaData]),

	MD1 = riakc_obj:set_secondary_index(MetaData, [{{integer_index, "map_id"}, [V#loc.map_id]}]),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),
	{reply, ok, State};

handle_call({remove_all}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, MyBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, MyBucket, X)
		end,
	BinKeys),
	{reply, Result, Pid};

handle_call({remove, BinId}, From, State) when is_binary(BinId) ->
	Pid = State,
	MyBucket = <<"map">>,
	riakc_pb_socket:delete(Pid, MyBucket, BinId),
	{reply, ok, State};

handle_call({remove, Id}, From, State) when is_list(Id) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinId = erlang:list_to_binary(Id),
	riakc_pb_socket:delete(Pid, MyBucket, BinId),
	{reply, ok, State};

handle_call({move, Id, NewV}, From, State) when is_list(Id) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinId = erlang:list_to_binary(Id),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinId),
	UpdatedObj1 = riakc_obj:update_value(Fetched1, NewV),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, UpdatedObj1, [return_body]),
	%% check returned value
	NewV = binary_to_term(riakc_obj:get_value(NewestObj1)),
	{reply, ok, State};

handle_call({lookup, Id}, From, State) when is_list(Id) ->
	Pid = State,
	Val1 = impl_lookup(Pid, Id),
	{reply, {ok, Val1}, State};

handle_call({lookup_with_integer, Attr, K}, From, State) ->
	Pid = State,
	V = impl_lookup_with_integer(Pid, Attr, K),
	TextVal = binary_to_list(V),
	{reply, {ok, TextVal}, State};

handle_call({new_location, "npc"}, From, State) ->
	Pid = State,
	L1 = #loc{map_id = 1, x=99 + random:uniform(10), y=88 + random:uniform(10)},
	{reply, {ok, L1}, State};

handle_call({get_near_objects, Id, Distance}, From, State) when is_list(Id) ->
	Pid = State,
	#loc{map_id = MapId, x = X, y = Y} = impl_lookup(Pid, Id),
	IdsOnSameMap = impl_lookup_with_integer(Pid, "map_id", MapId),
	NearObjects = lists:filtermap(fun(Elem)->
		io:format("filtermap calls with ~p~n", [Elem]),
		#loc{x = OX, y = OY} = impl_lookup(Pid, Elem),
		D = distance(X, Y, OX, OY),
		case D =< Distance of
			true -> {true, Elem};
			false -> false
		end 
	end, IdsOnSameMap),
	TextNearObjects = rutil:keys_to_lists(NearObjects),
	{reply, {ok, TextNearObjects}, State}.

impl_lookup(Pid, Id) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_lookup(Pid, BinId);

impl_lookup(Pid, BinId) when is_binary(BinId)->
	MyBucket = <<"map">>,
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinId),
	Val = binary_to_term(riakc_obj:get_value(Fetched1)).

impl_lookup_with_integer(Pid, Attr, Key) ->
	MyBucket = <<"map">>,
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, MyBucket,{integer_index, Attr}, Key),
	L.



