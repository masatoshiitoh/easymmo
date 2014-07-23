-module(time_feeder).
-include_lib("amqp_client.hrl").

-export([start/0, feed_one/2]).

-export([start_link/0]).
-export([init/1, handle_call/3]).

start() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, []}.

%% kick %%
feed_one(ServerIp, Exchange) ->
	Reply = gen_server:call(?MODULE, {feed_one, ServerIp, Exchange}).

gen_message() ->
	{{Year,Mon,Day},{Hour,Min,Sec}} = erlang:localtime(),
	TimeStr = io_lib:format("~p/~p/~p ~p:~p:~p", [Year,Mon,Day,Hour,Min,Sec]),
	list_to_binary(TimeStr).

send_one(Channel, Exchange, Message) ->
    amqp_channel:cast(
		Channel,
		#'basic.publish'{exchange = list_to_binary(Exchange)},
		#amqp_msg{payload = Message}).

init_fanout_exchange(ServerIp, Exchange) ->
    {ok, Connection} = amqp_connection:start(
		#amqp_params_network{host = ServerIp}),
	{ok, Channel} = amqp_connection:open_channel(Connection),

    amqp_channel:call(
		Channel,
		#'exchange.declare'{
			exchange = list_to_binary(Exchange),
			type = <<"fanout">>}),

	{ok, Connection, Channel}.

close_exchange(Connection, Channel) ->
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.

%% gen_server behaviour %%        
handle_call({feed_one, ServerIp, Exchange}, From, State) ->
	{ok, Connection, Channel} = init_fanout_exchange(ServerIp, Exchange),
	Message = gen_message(),
	send_one(Channel, Exchange, Message),
	ok = close_exchange(Connection, Channel),
	Reply = {ok, Message},
	{reply, Reply, State}.


%
%
%
%-module(loop_publisher).
%-include_lib("amqp_client/include/amqp_client.hrl").
%-export([start/0, main/1,stop/0]).
%-export([loop/3]).
%
%start() ->
%	main(ok).
%
%main(_MsgArg) ->
%	main("27.120.111.23", "time").
%
%main(ServerIp, Exchange) ->
%	{ok, Connection, Channel} = init_fanout_exchange(ServerIp, Exchange),
%	start_loop(Connection, Channel, Exchange).
%
%start_loop(Connection, Channel, Exchange) ->
%	Pid = spawn(?MODULE, loop, [Connection, Channel, Exchange]),
%	register(loopsender, Pid).
%
%loop(Connection, Channel, Exchange) ->
%	Message = gen_message(),
%	%%io:format("loop/3 called.~n"),
%
%	receive
%		"stop" ->
%			%%io:format("stop requested.~n"),
%			close_exchange(Connection, Channel), 0
%	after 1000 ->
%		%%io:format("send message.~n"),
%		send_one(Channel, Exchange, Message),
%		loop(Connection, Channel, Exchange)
%	end.
%
%stop() ->
%	loopsender ! "stop".
%
%
%
