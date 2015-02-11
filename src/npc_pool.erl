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

handle_call({new, Type}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	Id = rutil:auto_increment("npc"),
	BinK = erlang:term_to_binary(Id),
	Obj1 = riakc_obj:new(MyBucket, BinK, "hoge"),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, {ok, Id}, State};

handle_call({add, Id, V}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	BinId = erlang:term_to_binary(Id),
	Obj1 = riakc_obj:new(MyBucket, BinId, V),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, ok, State};

handle_call({lookup, Id}, From, State) ->
	{Pid, Npcs} = State,
	MyBucket = <<"npc">>,
	BinId = erlang:term_to_binary(Id),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinId),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State}.


