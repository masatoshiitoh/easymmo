%%
%% chat_srv.erl
%%
%%

-module(chat_srv).
-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).
-export([broadcast/2]).

%%
%% APIs
%%
broadcast(Id, Payload) ->
	Reply = gen_server:call(?MODULE, {broadcast, Id, Payload}).

%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
	[ServerIp, ToClientEx, FromClientEx] = Args,
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>])}.

terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

%% while subscribing, message will be delivered by #amqp_msg
handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , State) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Message = <<"info: Hello, this is chat_srv! ">> ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = <<"id.99999">> },
		#amqp_msg{payload = Message}),
	{noreply, State}.

handle_call({broadcast, Id, Payload}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = list_to_binary(Payload) ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = <<"id.99999">> },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.

