%%
%% npc_pool.erl
%%
%%

-module(npc_pool).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([lookup/1]).

%%
%% APIs
%%

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
	{ok, Pid} = riak_pb_socket:start(RiakIp, RiakPort),
	NewState = Pid,
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.

handle_call({add, K, V}, From, State) ->
	Pid = State,
	MyBucket = <<"test">>,
	BinK = erlang:list_to_binary(K),
	Obj1 = riakc_obj:new(MyBucket, BinK, V),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, ok, State};

handle_call({lookup, K}, From, State) ->
	Pid = State,
	MyBucket = <<"test">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State}.


