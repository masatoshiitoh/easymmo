%%
%% notifier.erl
%%
%%

-module(notifier).
-include_lib("amqp_client.hrl").

-export([start_link/0]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).

-export([add/2]).

%%
%% APIs
%%
add(DeltaMs, MFA) ->
	{mfa, M, F, A} = MFA,
	Reply = gen_server:call(?MODULE, {add, DeltaMs, {mfa, M, F, A}}).

%%
%% Behaviors
%%
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, []}.

terminate(_Reason, State) ->
	ok.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

%% while subscribing, message will be delivered by #amqp_msg
handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , State) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Message = <<"info: Hello, this is notifier! ">> ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = <<"id.99999">> },
		#amqp_msg{payload = Message}),
	{noreply, State}.

handle_call({add, DeltaMs, {mfa, M, F, A}}, From, State) ->
	{reply, ok, State}.

