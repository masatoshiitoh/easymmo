%%
%% emmo_char.erl
%%
%% Easymmo character manager (all character(PC and NPC) handled with this module)

-module(emmo_char).
% -include_lib("amqp_client.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]).
-export([remove/1]).
-export([move/2]).
-export([lookup/1]).
-export([test/0]).

-record(character, {hp = 0, mp = 0, speed = 0}).

%%
%% APIs
%%
test() ->
	C1 = #character{hp = 1, mp = 99, speed = 88},
	C2 = #character{hp = 2, mp = 99, speed = 88},
	C3 = #character{hp = 99, mp = 0, speed = 88},
	add("i1", C1),
	add("i2", C2),
	add("i3", C3),
	io:format("char 1 : ~p~n", [lookup("i1")]),
	io:format("char 2 : ~p~n", [lookup("i2")]),
	io:format("char 3 : ~p~n", [lookup("i3")]).

add(K, L) when is_record(L, character) ->
	Reply = gen_server:call(?MODULE, {add, K, L}).

remove(K) ->
	Reply = gen_server:call(?MODULE, {remove, K}).

move(K, NewL) when is_record(NewL, character) ->
	Reply = gen_server:call(?MODULE, {move, K, NewL}).

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
	NewState = Pid,
	{ok, NewState}.

terminate(_Reason, State) ->
	ok.

handle_call({add, K, V}, From, State) ->
	Pid = State,
	MyBucket = <<"character">>,
	BinK = erlang:list_to_binary(K),
	Obj1 = riakc_obj:new(MyBucket, BinK, V),
	riakc_pb_socket:put(Pid, Obj1),
	{reply, ok, State};

handle_call({remove, K}, From, State) ->
	Pid = State,
	MyBucket = <<"character">>,
	BinK = erlang:list_to_binary(K),
	riakc_pb_socket:delete(Pid, MyBucket, BinK),
	{reply, ok, State};

handle_call({move, K, NewV}, From, State) ->
	Pid = State,
	MyBucket = <<"character">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	UpdatedObj1 = riakc_obj:update_value(Fetched1, NewV),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, UpdatedObj1, [return_body]),
	%% check returned value
	NewV = binary_to_term(riakc_obj:get_value(NewestObj1)),
	{reply, ok, State};

handle_call({lookup, K}, From, State) ->
	Pid = State,
	MyBucket = <<"character">>,
	BinK = erlang:list_to_binary(K),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinK),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State}.


