%%
%% emmo_map.erl
%%
%% Easymmo map manager (all objects must be place to the map)

-module(emmo_map).
% -include_lib("amqp_client.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([remove/1]).
-export([move/2]).
-export([lookup/1]).
-export([lookup_by_map/1]).
-export([test/0]).

-record(loc, {map_id = 0, x = 0, y = 0}).

%%
%% APIs
%%
test() ->
	L1 = #loc{map_id = 1, x= 99,y= 88},
	L2 = #loc{map_id = 2, x=99, y=88},
	add("i1", L1),
	add("i2", L1),
	add("i3", L2),
	lookup_by_map(1).

add(K, L) when is_record(L, loc) ->
	Reply = gen_server:call(?MODULE, {add, K, L}).

remove(K) ->
	Reply = gen_server:call(?MODULE, {remove, K}).

move(K, NewL) when is_record(NewL, loc) ->
	Reply = gen_server:call(?MODULE, {move, K, NewL}).

lookup(K) ->
	Reply = gen_server:call(?MODULE, {lookup, K}).

lookup_by_map(K) ->
	Reply = gen_server:call(?MODULE, {lookup_by, "map_id", K}).

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

handle_call({add, K, V}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinK = erlang:list_to_binary(K),
	Obj1 = riakc_obj:new(MyBucket, BinK, V),
	io:format("~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("~p~n", [MetaData]),

	MD1 = riakc_obj:set_secondary_index(
		MetaData,
			[{
				{integer_index, "map_id"},
				[V#loc.map_id]
			}]
		),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),
	{reply, ok, State};

handle_call({remove, K}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinK = erlang:list_to_binary(K),
	riakc_pb_socket:delete(Pid, MyBucket, BinK),
	{reply, ok, State};

handle_call({move, K, NewV}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	UpdatedObj1 = riakc_obj:update_value(Fetched1, NewV),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, UpdatedObj1, [return_body]),
	%% check returned value
	NewV = binary_to_term(riakc_obj:get_value(NewestObj1)),
	{reply, ok, State};

handle_call({lookup, K}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State};

handle_call({lookup_by, Attr, K}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	V = riakc_pb_socket:get_index_eq(Pid, MyBucket,{integer_index, Attr}, K),
	{reply, {ok, V}, State}.


