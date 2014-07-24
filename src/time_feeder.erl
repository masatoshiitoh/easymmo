-module(time_feeder).
-include_lib("amqp_client.hrl").

-export([feed_once/2]).
-export([feed/3]).
-export([stop_feed/2]).

-export([start_link/0]).
-export([terminate/2]).
-export([init/1, handle_call/3]).
-export([loop/4]).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, dict:new()}.

%%
%% APIs
%%
feed_once(ServerIp, Exchange) ->
	Reply = gen_server:call(?MODULE, {feed_one, ServerIp, Exchange}).

feed(ServerIp, Exchange, IntervalMs) ->
	Reply = gen_server:call(?MODULE, {feed, ServerIp, Exchange, IntervalMs}).

stop_feed(ServerIp, Exchange) ->
	Reply = gen_server:call(?MODULE, {stop_feed, ServerIp, Exchange}).

%%
%% Internal use.
%%

gen_message() ->
	{{Year,Mon,Day},{Hour,Min,Sec}} = erlang:localtime(),
	TimeStr = io_lib:format("~p/~p/~p ~p:~p:~p", [Year,Mon,Day,Hour,Min,Sec]),
	list_to_binary(TimeStr).

loop(Connection, Channel, Exchange, IntervalMs) ->
	Message = gen_message(),
	receive
		"stop" ->
			close_exchange(Connection, Channel), 0
	after IntervalMs ->
		send_one(Channel, Exchange, Message),
		loop(Connection, Channel, Exchange, IntervalMs)
	end.

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
terminate(Reason, State) ->
	ok.

handle_call({feed_one, ServerIp, Exchange}, From, State) ->
	{ok, Connection, Channel} = init_fanout_exchange(ServerIp, Exchange),
	Message = gen_message(),
	send_one(Channel, Exchange, Message),
	ok = close_exchange(Connection, Channel),
	Reply = {ok, Message},
	{reply, Reply, State};

handle_call({feed, ServerIp, Exchange, Interval}, From, State) ->

	%%
	%% check existing process
	%%
	Value = dict:find({ServerIp, Exchange}, State),
	NS = case Value of
		ExistingPid when is_pid(ExistingPid) ->
			ExistingPid ! "stop",
			dict:erase({ServerIp, Exchange}, State);
		_ ->
			State
	end,

	%%
	%% start new feeder loop
	%%
	{ok, Connection, Channel} = init_fanout_exchange(ServerIp, Exchange),
	Pid = spawn(?MODULE, loop, [Connection, Channel, Exchange, Interval]),
	NewState = dict:store({ServerIp, Exchange}, Pid, NS),
	{reply, ok, NewState};

handle_call({stop_feed, ServerIp, Exchange}, From, State) ->

	case dict:find({ServerIp, Exchange}, State) of
		error ->
			{reply, {error, notfound} , State};

		{ok, Pid} when is_pid(Pid) ->
			Pid ! "stop", %% <== stop process
			NewState = dict:erase({ServerIp, Exchange}, State),
			{reply, {ok, Pid} , NewState} 

		end.


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
