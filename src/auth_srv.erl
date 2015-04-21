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
	io:format("connection ok~n",[]),
	Pid = amqp_rpc_client:start(Connection, <<"authrpc">>),
	io:format("start link ok, ~p~n",[Pid]),
	io:format("call return ~p~n",[ amqp_rpc_client:call(Pid, <<"ctest calls!">>) ]),
	amqp_rpc_client:stop(Pid),
	ok.
	
%%
%% ID/Pass check and other works.
%%

logout(LoginId, Token) ->
	discard_token(LoginId,Token).

id_pass_check(LoginId, Pass) when is_list(LoginId), is_list(Pass) ->
	0.

new_token(LoginId) ->
	0.

update_token(LoginId, Token) ->
	0.

discard_token(LoginId, Token) ->
	0.


%%
%% Behaviors
%%
start_link(ServerIp, AuthQueue) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, AuthQueue], []).

init(Args) ->
	[ServerIp, AuthQueue] = Args,
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
    Pid = amqp_rpc_server:start_link(Connection, AuthQueue,
		fun(X) ->
			list_to_binary(io_lib:format("received rpc request with ~p", [binary_to_list(X)]))
			end),

	State = [Pid],
	{ok, State}.

terminate(_Reason, State) ->
	[Pid] = State,
	amqp_rpc_server:stop(Pid),
	ok.


