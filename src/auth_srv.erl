%%
%% auth_srv.erl
%%
%% This use Riak db to hold authentication data.
%% This does NOT talk AMQP, internal service.
%%

-module(auth_srv).
-include_lib("amqp_client.hrl").
-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).

-export([test/0]).
-export([test1/0]).

-export([handle_call/3]).

-export([add/2]). %% argument 1 : uid, 2 : pass
-export([lookup/2]).
-export([record_logout/2]).

-define(AuthBucket, <<"accounts">>).

%%
%% Behaviors
%%

%%
%% APIs
%%
test1() ->
	make_auth("ichiro", "1111" ).

test() ->
	Reply = gen_server:call(?MODULE, {remove_all}),

	io:format("add ichiro with 2222 = ~p~n", [ add("ichiro", "2222") ]),
	io:format("del ichiro with 2222 = ~p~n", [ del("ichiro", "2222") ]),
	io:format("login ichiro 2222 = ~p~n", [login("ichiro", "2222")]),

	io:format("add ichiro with 1111 = ~p~n", [ add("ichiro", "1111") ]),

	io:format("login ichiro 1111 = ~p~n", [login("ichiro", "1111")]),
	io:format("login ichiro 2222 = ~p~n", [login("ichiro", "2222")]),
	ok.

add(LoginId, Password) ->
	Reply = gen_server:call(?MODULE, {add, make_auth(LoginId, Password) }).

del(LoginId, Password) ->
	Reply = gen_server:call(?MODULE, {del, make_auth(LoginId, Password) }).

login(LoginId, Password) ->
	Reply = gen_server:call(?MODULE, {login, LoginId, Password}).

logout(Uid, Token) ->
	Reply = gen_server:call(?MODULE, {logout, Uid, Token}).

lookup(LoginId, Token) ->
	%% call RPC
	{auth, ng, uid}.

record_logout(LoginId, Pass) ->
	%% call RPC
	{auth, ng}.

make_auth(LoginId, Password) ->
	#account{login_id = LoginId, password = Password}.
	

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

handle_call({add, V}, From, State) when is_record(V, account) ->
	Pid = State,

	BinId = rutil:new_named_bin_id("uid"),
	Obj1 = riakc_obj:new(?AuthBucket, BinId, V),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	Uid = V#account.login_id,
	MD1 = riakc_obj:set_secondary_index(MetaData, [{{binary_index, "login_id"}, [list_to_binary(Uid)]}]),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),

	PKey = binary_to_list(BinId),
	{reply, {ok, PKey}, State};


handle_call({del, V}, From, State) when is_record(V, account) ->
	Pid = State,
	Uid = V#account.login_id,
	BinPKey = impl_lookup_with_binary(Pid, "login_id", list_to_binary(Uid)),
	Data = impl_fetch(Pid, BinPKey),
	case Data#account.password =:= V#account.password of
		true -> riakc_pb_socket:delete(Pid, ?AuthBucket, BinPKey)
	end,
	{reply, ok, State};


handle_call({login, LoginId, Pass}, From, State) ->
	Pid = State,
	case impl_lookup_with_binary(Pid, "login_id", list_to_binary(LoginId)) of
		[] -> {reply, error, State};
		[BinPKey |_] ->
			io:format("login : ~p~n", [BinPKey]),
			Data = impl_fetch(Pid, BinPKey),
			io:format("login lookup: ~p~n", [Data]),
			Cid = binary_to_list(BinPKey),
			{ok, Cid, Token} = pc_pool:token_new_impl(Pid, Cid),
			case Data#account.password =:= Pass of
				true -> {reply, {ok, Cid, Token }, State};
				_ -> {reply, error, State}
			end
	end;


handle_call({logout, PKey, Token}, From, State) ->
	Pid = State,
	Data = impl_fetch(Pid, PKey),
	{reply, {ok, PKey, Token }, State};

handle_call({remove_all}, From, State) ->
	Pid = State,
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, ?AuthBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, ?AuthBucket, X)
		end,
	BinKeys),
	{reply, Result, Pid};


handle_call({update, Id, NewV}, From, State) when is_list(Id) ->
	Pid = State,
	BinId = erlang:list_to_binary(Id),
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?AuthBucket, BinId),
	UpdatedObj1 = riakc_obj:update_value(Fetched1, NewV),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, UpdatedObj1, [return_body]),
	%% check returned value
	NewV = binary_to_term(riakc_obj:get_value(NewestObj1)),
	{reply, ok, State};



handle_call({lookup, Id}, From, State) when is_list(Id) ->
	Pid = State,
	Val1 = impl_fetch(Pid, Id),
	{reply, {ok, Val1}, State};

handle_call({lookup_with_integer, Attr, K}, From, State) ->
	Pid = State,
	V = impl_lookup_with_integer(Pid, Attr, K),
	TextVal = binary_to_list(V),
	{reply, {ok, TextVal}, State}.


impl_fetch(Pid, Id) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_fetch(Pid, BinId);

impl_fetch(Pid, BinId) when is_binary(BinId)->
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?AuthBucket, BinId),
	Val = binary_to_term(riakc_obj:get_value(Fetched1)).

impl_lookup_with_integer(Pid, Attr, Key) ->
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, ?AuthBucket,{integer_index, Attr}, Key),
	L.

impl_lookup_with_binary(Pid, Attr, Key) when is_binary(Key) ->
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, ?AuthBucket,{binary_index, Attr}, Key),
	L.



