%%
%% rutil.erl
%%
%%

-module(rutil).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).

-export([new_named_bin_id/1]).
-export([new_named_id/1]).
-export([named_id/2]).
-export([auto_increment/0]).
-export([auto_increment/1]).
-export([ai/0]).
-export([ai/1]).
-export([keys_to_lists/1]).

-define(CounterBucket, <<"rutil_counter">>).
-define(DefaultCounter, <<"default">>).

%%
%% APIs
%%

new_named_bin_id(Name) when is_list(Name) ->
	list_to_binary(new_named_id(Name)).

new_named_id(Name) when is_list(Name) ->
	named_id(Name, auto_increment(Name)).

%
% named_id generates id like "npc921".
%
named_id(Name, Id) when is_list(Name), is_integer(Id) ->
	lists:append(Name, integer_to_list(Id)).

keys_to_lists(BinArray) ->
	lists:map(fun(X) -> binary_to_list(X) end, BinArray).

%
% auto increment functions.
%
ai(Name) -> auto_increment(Name).  
ai() -> auto_increment().

auto_increment() ->
	auto_increment(?DefaultCounter).

auto_increment(Name) ->
	{ok, Id} = gen_server:call(?MODULE, {auto_increment, Name}),
	Id.

%%
%% Utilities
%%

get_counter_value(Pid, BinCounterName) ->
	{cv,
	 riakc_pb_socket:get(Pid, ?CounterBucket, BinCounterName),
	 BinCounterName}.

make_next_value({cv, {error,notfound}, BinCounterName}) ->
	Obj = riakc_obj:new(?CounterBucket, BinCounterName, 1),
	{rc, 1, Obj};

make_next_value({cv, {ok,Fetched}, _}) ->
	Val = binary_to_term(riakc_obj:get_value(Fetched)),
	Newval = Val + 1,
	UpdatedObj = riakc_obj:update_value(Fetched, Newval),
	{rc, Newval, UpdatedObj}.

get_next_id(Pid, BinCounterName) when is_binary(BinCounterName) ->
	{rc, Count, Obj} = make_next_value(get_counter_value(Pid, BinCounterName)),
	{ok, NewestObj1} = riakc_pb_socket:put(Pid, Obj, [return_body]),
	Count;

get_next_id(Pid, CounterName) when is_list(CounterName) ->
	get_next_id(Pid, list_to_binary(CounterName));

get_next_id(Pid, CounterId) when is_integer(CounterId) ->
	get_next_id(Pid, list_to_binary(integer_to_list(CounterId))).

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

handle_call({auto_increment, CounterName}, From, State) ->
	{Pid, Npcs} = State,
	Id = get_next_id(Pid, CounterName),
	{reply, {ok, Id}, State}.



