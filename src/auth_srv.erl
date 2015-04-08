%%
%% auth_srv.erl
%%
%%

-module(auth_srv).
-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).

%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
	Params = [ServerIp, ToClientEx, FromClientEx] = Args,
	%% make connection
	%% make queue
	%% start amqp_rpc_server with start_link/3

	{ok, Params}.

terminate(_Reason, State) ->
	%% stop amqp_rpc_server with stop/1
	ok.

handle_info(_, State) ->
	{noreply, State}.

handle_call(_, From, State) ->
	{reply, ok, State}.

