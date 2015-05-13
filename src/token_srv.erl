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
test() -> ng.

add(Id) ->
	Reply = gen_server:call(?MODULE, {add, Id}).

remove_all() ->
	Reply = gen_server:call(?MODULE, {remove_all}).

remove(Id, Token) ->
	Reply = gen_server:call(?MODULE, {remove, Id, Token}).

check(Id, Token) ->
	Reply = gen_server:call(?MODULE, {check, Id, Token}).

%%
%% Utilities
%%

gen_token() -> crypto:rand_bytes(?BYTES_OF_TOKEN).


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

handle_call({add, Key}, From, State) when is_list(Key) ->
	Pid = State,
	BinId = erlang:list_to_binary(Id),
	Obj1 = riakc_obj:new(?UTokenBucket, BinId, V),
	io:format("~p~n", [Obj1]),

	MetaData = riakc_obj:get_update_metadata(Obj1),
	io:format("~p~n", [MetaData]),

	MD1 = riakc_obj:set_secondary_index(MetaData, [{{integer_index, "map_id"}, [V#loc.map_id]}]),

	Obj2 = riakc_obj:update_metadata(Obj1, MD1),

	riakc_pb_socket:put(Pid, Obj2),
	{reply, ok, State};

handle_call({remove_all}, From, State) ->
	Pid = State,
	MyBucket = <<"map">>,
	{ok, BinKeys} = riakc_pb_socket:list_keys(Pid, MyBucket),
	Result = lists:foreach(fun(X) ->
		riakc_pb_socket:delete(Pid, MyBucket, X)
		end,
	BinKeys),
	{reply, Result, Pid};

handle_call({remove, BinId}, From, State) when is_binary(BinId) ->
	Pid = State,
	MyBucket = <<"map">>,
	riakc_pb_socket:delete(Pid, MyBucket, BinId),
	{reply, ok, State};

handle_call({remove, Id}, From, State) when is_list(Id) ->
	Pid = State,
	MyBucket = <<"map">>,
	BinId = erlang:list_to_binary(Id),
	riakc_pb_socket:delete(Pid, MyBucket, BinId),
	{reply, ok, State};

handle_call({lookup, Id}, From, State) when is_list(Id) ->
	Pid = State,
	Val1 = impl_lookup(Pid, Id),
	{reply, {ok, Val1}, State};

handle_call({lookup_with_integer, Attr, K}, From, State) ->
	Pid = State,
	V = impl_lookup_with_integer(Pid, Attr, K),
	TextVal = binary_to_list(V),
	{reply, {ok, TextVal}, State};

impl_lookup(Pid, Id) when is_list(Id) ->
	BinId = erlang:list_to_binary(Id),
	impl_lookup(Pid, BinId);

impl_lookup(Pid, BinId) when is_binary(BinId)->
	MyBucket = <<"map">>,
	{ok, Fetched1} = riakc_pb_socket:get(Pid, MyBucket, BinId),
	Val = binary_to_term(riakc_obj:get_value(Fetched1)).

impl_lookup_with_integer(Pid, Attr, Key) ->
	MyBucket = <<"map">>,
	{ok, {index_results_v1, L, _,_}} = riakc_pb_socket:get_index_eq(Pid, MyBucket,{integer_index, Attr}, Key),
	L.



