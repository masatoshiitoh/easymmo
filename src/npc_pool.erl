%%
%% npc_pool.erl
%%
%%

-module(npc_pool).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/0]).
-export([remove/1]).
-export([online/1]).
-export([offline/1]).
-export([is_on/1]).
-export([lookup/1]).
-export([run/0]).
-export([run/1]).

-define(MyBucket, <<"npc">>).

%%
%% APIs
%%

add() ->
	Reply = gen_server:call(?MODULE, {add, auto_increment}).

remove(Id) ->
	Reply = gen_server:call(?MODULE, {remove, Id}).

online(Id) ->
	Reply = gen_server:call(?MODULE, {online, Id}).

offline(Id) ->
	Reply = gen_server:call(?MODULE, {offline, Id}).

is_on(Id) ->
	Reply = gen_server:call(?MODULE, {is_on, Id}).

lookup(Id) ->
	Reply = gen_server:call(?MODULE, {lookup, Id}).

run() ->
	Reply = gen_server:call(?MODULE, {run, 1000}).

run(IntervalMSec) ->
	Reply = gen_server:call(?MODULE, {run, IntervalMSec}).

%%
%% Utlities
%%

get_new_npc() ->
	{ok, V} = emmo_character:new("npc"),
	V.

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
	Id = rutil:auto_increment("npc"),
	BinId = erlang:term_to_binary(Id),
	NewNpc = get_new_npc(),
	Obj1 = riakc_obj:new(MyBucket, BinId, NewNpc),
	riakc_pb_socket:put(Pid, Obj1),
	NewState = {Pid, [Id | Npcs]},
	{reply, {ok, Id}, NewState};

handle_call({remove, Id}, From, State) ->
	{Pid, Npcs} = State,
	NewState = {Pid, lists:delete(Id , Npcs)},
	MyBucket = <<"npc">>,
	BinId = erlang:term_to_binary(Id),
	riakc_pb_socket:delete(Pid, MyBucket, BinId),
	{reply, {ok, Id}, NewState};

handle_call({online, Id}, From, State) ->
	{Pid, Npcs} = State,
	BinId = erlang:term_to_binary(Id),
	{ok, Fetched} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),	%% check if key existing "BinId"
	NewState = {Pid, [Id | Npcs]},
	{reply, ok, NewState};

handle_call({offline, Id}, From, State) ->
	{Pid, Npcs} = State,
	NewState = {Pid, lists:delete(Id , Npcs)},
	{reply, {ok, Id}, NewState};

handle_call({is_on, Id}, From, State) ->
	{Pid, Npcs} = State,
	{reply, {ok, lists:member(Id , Npcs)}, State};

handle_call({lookup, Id}, From, State) ->
	{Pid, Npcs} = State,
	BinId = erlang:term_to_binary(Id),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State};

handle_call({run, IntervalMSec}, From, State) ->
	{Pid, Npcs} = State,
	Val1 = lists:map(
		fun(X) ->
			BinId = erlang:term_to_binary(1),
			{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
			Val1 = binary_to_term(riakc_obj:get_value(Fetched1))
		end,
		Npcs),
	{reply, {ok, Val1}, State}.


