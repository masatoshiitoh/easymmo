-module(token_srv).

-include("emmo.hrl").

-define(UTokenBucket, <<"tokens">>).
-define(BYTES_OF_TOKEN, 4).
-define(DEFAULT_TOKEN_LIFE, 86400).

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

	T1 = add("0123"),		%% use default expiration limit.
	ok = check("0123", T1),
	ng = check("0124", T1),

	T2 = add("0123", -1),	%% set expiration limit (-1 means "already expired".).
	ng = check("0123", T2),
	ng = check("0124", T2),

	ok = remove("0123", T1),
	ok = remove("0123", T1),
	ok = remove("0124", T1),
	ok = remove("0123", T2),

	ok.

add(Id) ->
	Reply = gen_server:call(?MODULE, {add, Id}),
	{ok, V} = Reply,
	V.

add(Id, ExpireUnixtime) ->
	Reply = gen_server:call(?MODULE, {add, Id, ExpireUnixtime}),
	{ok, V} = Reply,
	V.

remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

check(Id, Token) ->
	{ok, V} = gen_server:call(?MODULE, {check, Id, Token}),
	V.

%% remove/2 return ok everytime.
remove(Id, Token) ->
	gen_server:call(?MODULE, {remove, Id, Token}).

%%
%% Utilities
%%

gen_token() ->
	gen_token(get_default_expire_unixtime()).

gen_token(ExpireUnixtime) ->
	integer_to_list(binary:decode_unsigned(crypto:rand_bytes(?BYTES_OF_TOKEN), big)).

get_unixtime() ->
	get_unixtime(now()).

get_unixtime( {Mega, Sec, _Msec} ) ->
	Mega * 1000000 + Sec.

get_default_expire_unixtime() ->
	get_unixtime() + ?DEFAULT_TOKEN_LIFE.

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

handle_call({add, Id}, From, State) ->
	handle_call({add, Id, get_default_expire_unixtime()}, From, State);

handle_call({add, Id, ExpireUnixtime}, From, State) ->
	RiakPid = State,
	V = impl_new_token(RiakPid, Id, ExpireUnixtime),
	{reply, {ok, V}, State};

handle_call({remove_all}, From, State) ->
	Pid = State,
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, ?UTokenBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, ?UTokenBucket, X)
		end,
	BinKeys),
	{reply, Result, Pid};

handle_call({check, Id, Token}, From, State) ->
	Pid = State,
	Val1 = impl_check_token(Pid, Id, Token),
	{reply, {ok, Val1}, State};

handle_call({remove, Id, Token}, From, State) ->
	Pid = State,
	BinKey = term_to_binary({Id, Token}),
	riakc_pb_socket:delete(Pid, ?UTokenBucket, BinKey),
	{reply, ok, State}.

%%
%% Implements: read/write tokens
%%
%% Bucket: ?UTokenBucket
%% Key: {Uid, Token}
%% 	Uid = string
%% 	Token = string of random number
%% Value: Expiration Unixtime
%% Secondary index: Value (=Expiration Unixtime)
%%

impl_new_token(RiakPid, Id, ExpireUnixtime)->
	V = gen_token(ExpireUnixtime),
	BinKey = term_to_binary({Id, V}),
	BinValue = integer_to_binary(ExpireUnixtime),
	impl_write(RiakPid, ?UTokenBucket, BinKey, BinValue, [{{integer_index, "expire_unixtime"}, [ExpireUnixtime]} ]),
	V.

impl_write(RiakPid, BinBucket, BinKey, BinValue, IndexList)->
	Pid = RiakPid,
	Obj1 = riakc_obj:new(BinBucket, BinKey, BinValue),
	MD = riakc_obj:get_update_metadata(Obj1),
	MD1 = riakc_obj:set_secondary_index(MD, IndexList),
	Obj2 = riakc_obj:update_metadata(Obj1, MD1),
	riakc_pb_socket:put(Pid, Obj2).

impl_check_token(RiakPid, Id, Token) ->
	BinKey = term_to_binary({Id, Token}),
	case riakc_pb_socket:get(RiakPid, ?UTokenBucket, BinKey) of
		{ok, RiakObj} ->
			IntVal1 = binary_to_integer(riakc_obj:get_value(RiakObj)),
			case IntVal1 > get_unixtime() of
				true -> ok;
				false -> ng
			end;
		{error, _Reason} ->
			ng
	end.

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


