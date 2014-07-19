-module(amqp_example).
-include("amqp_client.hrl").
-compile([export_all]).
 
test() ->
	{ok, Connection} = amqp_connection:start({network, #amqp_params_network{}}),
	{ok, Channel} = amqp_connection:open_channel(Connection),
	#'queue.declare_ok'{queue = Q} = amqp_channel:call(Channel, #'queue.declare'{}),
	Payload = <<"foobar">>,
	Publish = #'basic.publish'{exchange = <<>>, routing_key = Q},
	amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
	Get = #'basic.get'{queue = Q},
	{#'basic.get_ok'{delivery_tag = Tag}, Content} = amqp_channel:call(Channel, Get),
	  % Do something with the message payload.......and then ack it
	amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
	amqp_channel:close(Channel),
	amqp_connection:close(Connection),
	ok.
