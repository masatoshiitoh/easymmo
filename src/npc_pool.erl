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

%%
%% APIs
%%

add(ServerIp, Exchange) ->
	Reply = gen_server:call(?MODULE, {add, ServerIp, Exchange}).


%%
%% Behaviors
%%
start_link(RiakIp, RiakPort) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [RiakIp, RiakPort], []).

init(Args) ->
    [RiakIp, RiakPort] = Args,
	{ok, Hoge} = riak_pb_socket:start(RiakIp, RiakPort),
	{ok, Hoge}.

terminate(_Reason, State) ->
	ok.

handle_call(add, From, State) ->
	{ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs} = State,
	{reply, ok, State}.


