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
	[ServerIp, Exchange] = Args,

	%% Setup connection

	{ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),

	%% channel open

	{ok, Ch} = amqp_connection:open_channel(Connection),

	%% declare exchange

	amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, auto_delete = true}),
	#'queue.declare_ok'{queue = Queue} = amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),

	%% subscribe queue

	amqp_channel:subscribe(Ch, #'basic.consume'{queue = Queue, no_ack = true}, self()),
	{ServerIp, Exchange, Connection, Ch}.

% QOSを指定する
%% amqp_channel:call(Channel, #'basic.qos'{prefetch_count = Prefetch})
% コンシューマーを作成する
% 受信待ち。(infoがとんでくるので、erlang クライアントではループに入らない）
% おしまい。



shutdown_by_state(State) ->
	{ServerIp, Exchange, Connection, Ch} = State,.
    ok = amqp_channel:close(Ch),
    ok = amqp_connection:close(Connection),
	ok.


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

