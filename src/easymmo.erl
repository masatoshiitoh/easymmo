-module(easymmo).
-export([start/0]).
-export([stop/0]).


start() ->
	ToClient="xout",
	FromClient="xin",
	ToMClient="xout",
	FromMClient="xin",
	ServerIp="localhost",
	IntervalMs = 1000,
	Exchange = <<"time">>,
	chat_srv:start_service(ServerIp, ToClient, FromClient),
	move_srv:start_service(ServerIp, ToMClient, FromMClient),
	time_feeder:feed(ServerIp, Exchange, IntervalMs) ,
	ok.

stop() ->
	ToClient="xout",
	FromClient="xin",
	ToMClient="xout",
	FromMClient="xin",
	ServerIp="localhost",
	Exchange = <<"time">>,
	chat_srv:stop_service(ServerIp, ToClient, FromClient),
	move_srv:stop_service(ServerIp, ToMClient, FromMClient),
	time_feeder:stop_feed(ServerIp, Exchange) ,
	ok.

