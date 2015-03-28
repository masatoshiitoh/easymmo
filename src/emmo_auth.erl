%%
%% emmo_auth.erl
%%
%% Easymmo authentication server

-module(emmo_auth).
% -include_lib("amqp_client.hrl").

-include("emmo.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([add/2]). %% argument 1 : uid, 2 : pass
-export([del/2]). %% uid and pass
-export([login/2]).
-export([logout/2]).
-export([test1/0]).
-export([test/0]).

-define(AuthBucket, <<"auth">>).

%%
%% APIs
%%
test1() ->
	make_auth("ichiro", "1111" ).

test() ->
	%%C1 = #auth{uid = "ichiro", pass = "1111", token = ""},

	add("ichiro", "1111"),
	%% del("ichiro", "1111"),

	A1 = login("ichiro", "1111").

add(Uid, Pass) ->
	Reply = gen_server:call(?MODULE, {add, make_auth(Uid, Pass) }).

del(Uid, Pass) ->
	Reply = gen_server:call(?MODULE, {del, make_auth(Uid, Pass) }).

login(Uid, Pass) ->
	Reply = gen_server:call(?MODULE, {login, Uid, Pass}).

logout(Uid, Token) ->
	Reply = gen_server:call(?MODULE, {logout, Uid, Token}).

make_auth(Uid, Pass) ->
	#auth{uid = Uid, pass = Pass}.
	

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

	%%Obj1 = riakc_obj:new(?AuthBucket, BinK, V),

handle_call({add, V}, From, State) when is_record(V, auth) ->
	Pid = State,

	NamedId = rutil:new_named_id("uid"),
	BinId = erlang:list_to_binary(NamedId),

	Obj1 = riakc_obj:new(?AuthBucket, BinId, V),
	io:format("adding auth: ~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("adding auth: ~p~n", [MetaData]),

	Uid = V#auth.uid,
	MD1 = riakc_obj:set_secondary_index(MetaData, [{{binary_index, "uid"}, list_to_binary(Uid)}]),
	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),

	{reply, ok, State};





handle_call({del, V}, From, State) when is_record(V, auth) ->
	Pid = State,
	Uid = V#auth.uid,
	BinPKey = impl_lookup_with_binary(Pid, "uid", list_to_binary(Uid)),
	io:format("deleting auth: ~p~n", [BinPKey]),
	Data = impl_lookup(Pid, BinPKey),
	io:format("deleting auth: ~p~n", [Data]),
	case Data#auth.pass =:= V#auth.pass of
		true -> riakc_pb_socket:delete(Pid, ?AuthBucket, BinPKey)
	end,
	{reply, ok, State};






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
	{ok, Fetched1} = riakc_pb_socket:get(Pid, ?AuthBucket, BinId),
	Val = binary_to_term(riakc_obj:get_value(Fetched1)).

impl_lookup_with_integer(Pid, Attr, Key) ->
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, ?AuthBucket,{integer_index, Attr}, Key),
	L.

impl_lookup_with_binary(Pid, Attr, Key) when is_binary(Key) ->
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, ?AuthBucket,{binary_index, Attr}, Key),
	L.


