%%
%% mq_rpc_srv.erl
%%

-module(mq_rpc_srv).

-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).

%%
%% APIs
%%

start_link(ServerIp, ListenEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ListenEx], []).

init(Args) ->
	[ServerIp, ListenEx] = Args,

	%% {ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>, <<"move.#">>])}.
	
	%%{Connection, ChTC, ChFC} = setup_topic(ServerIp, ToClientEx, FromClientEx, ReceiveTopicList),
	%%{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}.

    %%%{ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	%%ChTC = setup_emit_topics(Connection, ToClientEx),
	%%ChFC = setup_receive_topics(Connection, FromClientEx, ReceiveTopicList),
	%%{Connection, ChTC, ChFC}.

%%setup_receive_topics(Connection, Exchange, TopicList) ->
%%    {ok, Ch} = amqp_connection:open_channel(Connection),
%%    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
%%	#'queue.declare_ok'{queue = Queue} =
%%	amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),
%%	[amqp_channel:call(Ch, #'queue.bind'{
%%		exchange = Exchange,
%%		routing_key = BindingKey,
%%		queue = Queue})
%%	|| BindingKey <- TopicList],
%%	amqp_channel:subscribe(Ch, #'basic.consume'{queue = Queue, no_ack = true}, self()),
%%	Ch.
%%
%%
	
	%% Setup connection
	%%

	%%{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"#">>])}.

% コネクションを作成する
	{ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	{ok, Ch} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	#'queue.declare_ok'{queue = Queue} =
	amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),

% キューを宣言する
	[amqp_channel:call(Ch, #'queue.bind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	amqp_channel:subscribe(Ch, #'basic.consume'{queue = Queue, no_ack = true}, self()),

% QOSを指定する
% コンシューマーを作成する
% 受信待ち。(infoがとんでくるので、erlang クライアントではループに入らない）



% 
% // RPC Server code
% var factory = new ConnectionFactory() { HostName = "localhost" };
% using (var connection = factory.CreateConnection())
% {
% 	using (var channel = connection.CreateModel())
% 	{
% 		channel.QueueDeclare("rpc_queue", false, false, false, null);
% 		channel.BasicQos(0, 1, false);
% 		var consumer = new QueueingBasicConsumer(channel);
% 		channel.BasicConsume("rpc_queue", false, consumer);
% 		Console.WriteLine(" [x] Awaiting RPC requests");
% 		while (true)
% 		{
% 			string response = null;
% 			var ea = (BasicDeliverEventArgs)consumer.Queue.Dequeue();
% 			var body = ea.Body;
% 			var props = ea.BasicProperties;
% 			var replyProps = channel.CreateBasicProperties();
% 			replyProps.CorrelationId = props.CorrelationId;
% 			try
% 			{
% 				var message = Encoding.UTF8.GetString(body);
% 				int n = int.Parse(message);
% 				Console.WriteLine(" [.] fib({0})", message);
% 				response = fib(n).ToString();
% 			}
% 			catch (Exception e)
% 			{
% 				Console.WriteLine(" [.] " + e.Message);
% 				response = "";
% 			}
% 			finally
% 			{
% 				var responseBytes =
% 				Encoding.UTF8.GetBytes(response);
% 				channel.BasicPublish("", props.ReplyTo, replyProps,
% 				responseBytes);
% 				channel.BasicAck(ea.DeliveryTag, false);
% 			}
% 		}
% 	}
% }
% 



	{ok, 0}.

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

