%%
%% mq_watch.erl
%%

-module(mq_rpc).

-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).

start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
	[ServerIp, ToClientEx, FromClientEx] = Args,
	%% {ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>, <<"move.#">>])}.
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"#">>])}.

%%
%% APIs
%%

%% gen_server behaviour %%        
terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

%% while subscribing, message will be delivered by #amqp_msg
handle_info( {#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}} , State) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	io:format("[mq_watch][~p] ~p~n", [RoutingKey, Body]),
	{noreply, State}.

