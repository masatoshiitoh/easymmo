%%
%% mqutil.erl
%%
%%

-module(mqutil).


-include_lib("amqp_client.hrl").
-include("emmo.hrl").

-export([mq_test/0]).
-export([mq_test_sender/2]).


%%
%% MQ support functions.
%%

%% please write handle_info yourself.

connect(ServerIp) ->
	conn_info.

subscribe(ConnInfo, StrTopic) ->
	new_conn_info.

unsbscribe(ConnInfo, StrTopic) ->
	new_conn_info.

disconnect(ConnInfo) ->
	ng.

%%
%% following mq_* functions are prepareing for future experiments..
%%

mq_listen_area(chat, <<"chat.open.1">>) ->
0.

mq_change_area(chat, <<"chat.open.2">>) ->
0.

mq_end_area() ->
0.

mq_listen_id(cid, 1) ->
0.

mq_end_id() ->
0.


%% receiver
mq_test() ->
	io:format("please use topic t.1 or t.2~n",[]),
	ServerIp = "192.168.56.21",
	spawn_link(fun() ->
		{mq, ServerIp, Connection, Exchange, Channel, Queue, Topics} =
			mq_setup_topic_receiver(ServerIp, <<"testexchange">>, [<<"t.1">>]),
		mq_test_loop({mq, ServerIp, Connection, Exchange, Channel, Queue, Topics})
	end).

mq_test_loop( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}) ->
	mq_test_receiver(10000),
	{mq, S1, Co1, Ex1, Ch1, Q1, T1} =
		mq_replace_topic({mq, ServerIp, Connection, Exchange, Channel, Queue, Topics} , [<<"t.1">>] , [<<"t.2">>]),
	io:format("now, set topic to ~p~n", ["t.2"]),
	mq_test_receiver(10000),
	{mq, S2, Co2, Ex2, Ch2, Q2, T2} =
		mq_replace_topic({mq, S1, Co1, Ex1, Ch1, Q1, T1} , [<<"t.2">>] , [<<"t.1">>]),
	io:format("now, set topic to ~p~n", ["t.1"]),
	mq_test_loop( {mq, S2, Co2, Ex2, Ch2, Q2, T2} ).

mq_test_receiver(Timeout) ->
	receive
		#'basic.consume_ok'{} -> mq_test_receiver(Timeout);
		{#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}} ->
			io:format("now, receive from ~p,  body ~p~n", [RoutingKey, Body]),
			mq_test_receiver(Timeout)
		after Timeout -> 0
	end.


%% send message once.
mq_test_sender(Topic, Message)->
	Connection = mq_connect("192.168.56.21"),
	Ch = mq_setup_send_topics(Connection, <<"testexchange">>),
	amqp_channel:cast(Ch,
		#'basic.publish'{exchange = <<"testexchange">>, routing_key = list_to_binary(Topic) },
		#amqp_msg{payload = list_to_binary(Message)}).


mq_connect(ServerIp) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	Connection.

mq_disconnect(Connection) ->
    ok = amqp_connection:close(Connection).

mq_shutdown_connect(ChTC, ChFC) ->
    ok = amqp_channel:close(ChFC),
    ok = amqp_channel:close(ChTC),
	ok.

mq_setup_topic_receiver(ServerIp, Exchange, Topics) ->
	Connection = mq_connect(ServerIp),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	#'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
	mq_replace_topic( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}, [], Topics),
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue, no_ack = true}, self()),
	{mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}.

mq_replace_topic( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}, RemovingTopics, NewTopics) ->
	Ch1 = mq_add_receive_topics(Channel, Exchange,Queue, NewTopics),
	Ch2 = mq_remove_receive_topics(Ch1, Exchange, Queue, RemovingTopics),
	LatestTopics = lists:subtract(lists:append(Topics, NewTopics), RemovingTopics),
	{mq, ServerIp, Connection, Exchange, Ch2, Queue, LatestTopics}.

mq_setup_send_topics(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	Ch.

mq_add_receive_topics(Channel, Exchange, Queue, TopicList) ->
	[amqp_channel:call(Channel, #'queue.bind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	Channel.

mq_remove_receive_topics(Channel, Exchange, Queue, TopicList) ->
	[amqp_channel:call(Channel, #'queue.unbind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	Channel.

mq_setup_send_routing(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	Ch.
