%%
%% npc_pool.erl
%%
%%

-module(npc_pool).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([new/0]).
-export([new/1]).
-export([add/2]).
-export([lookup/1]).
-export([reset/0]).

%%
%% APIs
%%

new() ->
	Reply = gen_server:call(?MODULE, {new, 0}).

new(Type) ->
	Reply = gen_server:call(?MODULE, {new, Type}).

add(K, V) ->
	Reply = gen_server:call(?MODULE, {add, K, V}).

lookup(K) ->
	Reply = gen_server:call(?MODULE, {lookup, K}).

reset() ->
	Reply = gen_server:call(?MODULE, {set_counter, 0}).

%%
%% Utilities
%%

get_counter_value(Pid) ->
	MyBucket = <<"counter">>,
	BinK = erlang:list_to_binary("npc"),
	riakc_pb_socket:get(Pid, MyBucket, BinK).

make_next_value({error,notfound}) ->
	MyBucket = <<"counter">>,
	BinK = erlang:list_to_binary("npc"),
	Obj = riakc_obj:new(MyBucket, BinK, 1),
	{rc, 1, Obj};

make_next_value({ok,Fetched}) ->
	Val = binary_to_term(riakc_obj:get_value(Fetched)),
	Newval = Val + 1,
	UpdatedObj = riakc_obj:update_value(Fetched, Newval),
	{rc, Newval, UpdatedObj}.

get_next_id(Pid) ->
	{rc, Count, Obj} = make_next_value(get_counter_value(Pid)),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, Obj, [return_body]),
	Count.


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

handle_call({set_counter, V}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"counter">>,
	BinK = erlang:list_to_binary("npc"),
	Obj = riakc_obj:new(MyBucket, BinK, V),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, Obj, [return_body]),
	Val2 = binary_to_term(riakc_obj:get_value(NewestObj1)),
	{reply, {ok, Val2}, State};

handle_call({new, Type}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	Id = get_next_id(Pid),
	BinK = erlang:term_to_binary(Id),
	Obj1 = riakc_obj:new(MyBucket, BinK, "hoge"),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, {ok, Id}, State};

handle_call({add, K, V}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	BinK = erlang:list_to_binary(K),
	Obj1 = riakc_obj:new(MyBucket, BinK, V),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, ok, State};

handle_call({lookup, K}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State}.


