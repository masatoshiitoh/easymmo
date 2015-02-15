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
	Obj1 = riakc_obj:new(?MyBucket, BinId, NewNpc),
	riakc_pb_socket:put(Pid, Obj1),
	NewState = {Pid, [NamedId | Npcs]},
	{reply, {ok, NamedId}, NewState};

handle_call({remove, NamedId}, From, State) ->
	{Pid, Npcs} = State,
	NewState = {Pid, lists:delete(NamedId , Npcs)},
	BinId = erlang:list_to_binary(NamedId),
	riakc_pb_socket:delete(Pid, ?MyBucket, BinId),
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
	BinId = erlang:list_to_binary(NamedId),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
	Val1 = binary_to_term(riakc_obj:get_value(Fetched1)),
	{reply, {ok, Val1}, State};

handle_call({run, IntervalMSec}, From, State) ->
	{Pid, Npcs} = State,
	Val1 = lists:map(
		fun(X) ->
			BinId = erlang:list_to_binary(X),
			{ok, Fetched1} = riakc_pb_socket:get(Pid, ?MyBucket, BinId),
			Val1 = binary_to_term(riakc_obj:get_value(Fetched1))
		end,
		Npcs),
	{reply, {ok, Val1}, State}.


