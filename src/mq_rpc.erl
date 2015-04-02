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




% 
% class RPCClient
% {
% 	private IConnection connection;
% 	private IModel channel;
% 	private string replyQueueName;
% 	private QueueingBasicConsumer consumer;
% 	public RPCClient()
% 	{
% 		var factory = new ConnectionFactory() { HostName = "localhost" };
% 		connection = factory.CreateConnection();
% 		channel = connection.CreateModel();
% 		replyQueueName = channel.QueueDeclare();
% 		consumer = new QueueingBasicConsumer(channel);
% 		channel.BasicConsume(replyQueueName, true, consumer);
% 	}
% 	public string Call(string message)
% 	{
% 		var corrId = Guid.NewGuid().ToString();
% 		var props = channel.CreateBasicProperties();
% 		props.ReplyTo = replyQueueName;
% 		props.CorrelationId = corrId;
% 		var messageBytes = Encoding.UTF8.GetBytes(message);
% 		channel.BasicPublish("", "rpc_queue", props, messageBytes);
% 		while (true)
% 		{
% 			var ea = (BasicDeliverEventArgs)consumer.Queue.Dequeue();
% 			if (ea.BasicProperties.CorrelationId == corrId)
% 			{
% 				return Encoding.UTF8.GetString(ea.Body);
% 			}
% 		}
% 	}
% 	public void Close()
% 	{
% 		connection.Close();
% 	}
% }
% 





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

