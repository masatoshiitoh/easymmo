%%
%% auth_srv.erl
%%
%%

-module(auth_srv).
-include_lib("amqp_client.hrl").

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).

-export([ctest/0]).

ctest() ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = "192.168.56.21"}),
	Pid = amqp_rpc_client:start_link(Connection, <<"authrpc">>),
	amqp_rpc_client:call(Pid, "ctest calls!"),
	amqp_rpc_client:stop(Pid),
	ok.
	

%%
%% Behaviors
%%
start_link(ServerIp, AuthQueue) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, AuthQueue], []).

init(Args) ->
	[ServerIp, AuthQueue] = Args,
	%% make connection
	%% make queue
	%% start amqp_rpc_server with start_link/3

    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
    Pid = amqp_rpc_server:start_link(Connection, AuthQueue, fun(X) -> io:format("received rpc request with ~p~n", [X]) end),

	State = [Pid],
	{ok, State}.

terminate(_Reason, State) ->
	[Pid] = State,
	amqp_rpc_server:stop(Pid),
	ok.


