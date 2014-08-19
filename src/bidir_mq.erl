%%
%% bidir_mq.erl
%%
%% utilities for bi-directional MQ.
%%

-module(bidir_mq).
-include_lib("amqp_client.hrl").

-export([init_fanout/3]).
-export([init_topic/4]).
-export([shutdown_by_state/1]).
-export([setup_fanout/3]).
-export([setup_topic/4]).
-export([shutdown_connect/3]).


init_fanout(ServerIp, ToClientEx, FromClientEx) ->
	{Connection, ChTC, ChFC} = setup_fanout(ServerIp, ToClientEx, FromClientEx),
	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}.

init_topic(ServerIp, ToClientEx, FromClientEx, ReceiveTopicList) ->
	{Connection, ChTC, ChFC} = setup_topic(ServerIp, ToClientEx, FromClientEx, ReceiveTopicList),
	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}.

shutdown_by_state(State) ->
	{_ServerIp, _ToClientEx, _FromClientEx, {Connection, ChTC, ChFC}} = State,
	shutdown_connect(Connection, ChTC, ChFC).

shutdown_connect(Connection, ChTC, ChFC) ->
    ok = amqp_channel:close(ChFC),
    ok = amqp_channel:close(ChTC),
    ok = amqp_connection:close(Connection),
	ok.

%%
%% Setup fanout in/out
%%
setup_fanout(ServerIp, ToClientEx, FromClientEx) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	ChTC = setup_emit_fanout(Connection, ToClientEx),
	ChFC = setup_receive_fanout(Connection, FromClientEx),
	{Connection, ChTC, ChFC}.

setup_emit_fanout(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"fanout">>, auto_delete = true}),
	Ch.

setup_receive_fanout(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"fanout">>, auto_delete = true}),
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),
    amqp_channel:call(Ch, #'queue.bind'{exchange = Exchange, queue = Queue}),
    amqp_channel:subscribe(Ch, #'basic.consume'{queue = Queue, no_ack = true}, self()),
	Ch.

%%
%% Setup topic in/out
%%
setup_topic(ServerIp, ToClientEx, FromClientEx, ReceiveTopicList) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	ChTC = setup_emit_topics(Connection, ToClientEx),
	ChFC = setup_receive_topics(Connection, FromClientEx, ReceiveTopicList),
	{Connection, ChTC, ChFC}.

setup_emit_topics(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	Ch.

setup_receive_topics(Connection, Exchange, TopicList) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	#'queue.declare_ok'{queue = Queue} =
	amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),
	[amqp_channel:call(Ch, #'queue.bind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	amqp_channel:subscribe(Ch, #'basic.consume'{queue = Queue, no_ack = true}, self()),
	Ch.


