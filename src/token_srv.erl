-module(token_srv).

-include("emmo.hrl").

-define(UTokenBucket, <<"tokens">>).
-define(BYTES_OF_TOKEN, 8).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([test/0]).
-export([add/1]).
-export([remove_all/0]).
-export([remove/2]).
-export([check/2]).


%%
%% APIs
%%
test() ->
	remove_all(),

	T1 = add("0123"),
	ok = check("0123", T1),
	ng = check("0124", T1),

	T2 = add("0123", -1),
	ng = check("0123", T2),
	ng = check("0124", T2),

	ok.

add(Id) ->
	Reply = gen_server:call(?MODULE, {add, Id}).
	{ok, V} = Reply,
	V.

add(Id, ExpireUnixtime) ->
	Reply = gen_server:call(?MODULE, {add, Id, ExpireUnixtime}),
	{ok, V} = Reply,
	V.

remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

remove(Id, Token) ->
	Reply = gen_server:call(?MODULE, {remove, Id, Token}).

check(Id, Token) ->
	Reply = gen_server:call(?MODULE, {check, Id, Token}).

%%
%% Utilities
%%

gen_token() ->
	#token{token = crypto:rand_bytes(?BYTES_OF_TOKEN),
		expire_unixtime = 0}.

gen_token(ExpireUnixtime) ->
	#token{token = crypto:rand_bytes(?BYTES_OF_TOKEN),
		expire_unixtime = ExpireUnixtime}.

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

handle_call({add, Id}, From, State) when is_list(Id) ->
	Pid = State,
	BinId = erlang:list_to_binary(Id),
	V = gen_token(),
	Obj1 = riakc_obj:new(?UTokenBucket, BinId, V),
	io:format("~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("~p~n", [MetaData]),

	MD1 = riakc_obj:set_secondary_index(MetaData, [{{integer_index, "expire_unixtime"}, [V#token.expire_unixtime]}]),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),
	{reply, {ok, V}, State};

handle_call({add, Id, ExpireUnixtime}, From, State) when is_list(Id) ->
	Pid = State,
	BinId = erlang:list_to_binary(Id),

	V = gen_token(ExpireUnixtime),

	Obj1 = riakc_obj:new(?UTokenBucket, BinId, V),
	io:format("~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("~p~n", [MetaData]),

	MD1 = riakc_obj:set_secondary_index(MetaData, [{{integer_index, "expire_unixtime"}, [V#token.expire_unixtime]}]),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),
	{reply, {ok, V}, State};


handle_call({remove_all}, From, State) ->
	Pid = State,
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, ?UTokenBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, ?UTokenBucket, X)
		end,
	BinKeys),
	{reply, Result, Pid};

handle_call({remove, BinId}, From, State) when is_binary(BinId) ->
	Pid = State,
	riakc_pb_socket:delete(Pid, ?UTokenBucket, BinId),
	{reply, ok, State};

handle_call({remove, Id}, From, State) when is_list(Id) ->
	Pid = State,
	BinId = erlang:list_to_binary(Id),
	riakc_pb_socket:delete(Pid, ?UTokenBucket, BinId),
	{reply, ok, State};

handle_call({lookup, Id}, From, State) when is_list(Id) ->
	Pid = State,
	Val1 = impl_lookup(Pid, Id),
	{reply, {ok, Val1}, State};

handle_call({lookup_with_integer, Attr, K}, From, State) ->
	Pid = State,
	V = impl_lookup_with_integer(Pid, Attr, K),
	TextVal = binary_to_list(V),
	{reply, {ok, TextVal}, State}.

impl_lookup(Pid, Id) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_lookup(Pid, BinId);

impl_lookup(Pid, BinId) when is_binary(BinId)->
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?UTokenBucket, BinId),
	Val = binary_to_term(riakc_obj:get_value(Fetched1)).

impl_lookup_with_integer(Pid, Attr, Key) ->
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, ?UTokenBucket,{integer_index, Attr}, Key),
	L.

impl_check_is_online(Pid, Id, Token) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_check_is_online(Pid, BinId, Token);

impl_check_is_online(Pid, BinId, Token) when is_binary(BinId) ->
	case riakc_pb_socket:get(Pid, ?UTokenBucket, BinId) of
		{ok, Fetched1} -> true;
		{error, notfound} -> false
	end.

impl_online(Pid, Id, Token) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_online(Pid, BinId, Token);

impl_online(Pid, BinId, Token) when is_binary(BinId) ->
	case impl_check_is_online(Pid, BinId, Token) of
	true ->
		Token = gen_token(),
		Obj1 = riakc_obj:new(?UTokenBucket, BinId, Token),
		riakc_pb_socket:put(Pid, Obj1),
		ok;
	false ->
		0
	end.


impl_offline(Pid, Id, Token) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_offline(Pid, BinId, Token);

impl_offline(Pid, BinId, Token) when is_binary(BinId) ->
	0.


