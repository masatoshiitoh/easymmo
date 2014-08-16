-module(time_feeder).
-include_lib("amqp_client.hrl").

-export([feed_once/2]).
-export([feed/3]).
-export([stop_feed/2]).

-export([start_link/2]).
-export([terminate/2]).
-export([init/1]).
-export([handle_call/3]).
-export([handle_info/2]).

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
%% Behaviors
%%
start_link(ServerIp, TimeEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, TimeEx], []).

init(Args) ->
	[ServerIp, ToClientEx] = Args,
	IntervalMs = 1000,
	{Connection, ChTC} = setup_connection(ServerIp, ToClientEx),
	NewState = {ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs},
	request_send(IntervalMs),
	{ok, NewState}.

terminate(Reason, State) ->
	{ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs} = State,
	shutdown_connect(Connection, ChTC),
	ok.

handle_call(feed_one, From, State) ->
	{ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs} = State,
	Message = gen_message(),
	send_one(ChTC, ToClientEx, Message),
	Reply = {ok, Message},
	{reply, Reply, State};

handle_call({feed, IntervalMs}, From, State) ->
	{ServerIp, ToClientEx, {Connection, ChTC}, _} = State,
	request_send(IntervalMs),
	NewState = {ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs},
	{reply, ok, NewState};

handle_call(stop_feed, From, State) ->
	{ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs} = State,
	NewState = {ServerIp, ToClientEx, {Connection, ChTC}, 0},
	{reply, ok, NewState}.

%% while subscribing, message will be delivered by #amqp_msg
handle_info(send , State = {ServerIp, ToClientEx, {Connection, ChTC}, 0}) ->
	%% do nothing.
	{noreply, State};

handle_info(send , State = {ServerIp, ToClientEx, {Connection, ChTC}, IntervalMs}) ->
	%% send time info
	send_one(ChTC, ToClientEx, gen_message()),
	%% use timer:send_after for next send
	timer:send_after(IntervalMs, send),
	{noreply, State}.

%%
%% Internal use.
%%
request_send(IntervalMs) ->
	timer:send_after(IntervalMs, send).

gen_message() ->
	{{Year,Mon,Day},{Hour,Min,Sec}} = erlang:localtime(),
	TimeStr = io_lib:format("~p/~p/~p ~p:~p:~p", [Year,Mon,Day,Hour,Min,Sec]),
	list_to_binary(TimeStr).

send_one(Channel, Exchange, Message) ->
    amqp_channel:cast(
		Channel,
		#'basic.publish'{exchange = Exchange},
		#amqp_msg{payload = Message}).

setup_connection(ServerIp, ToClientEx) ->
    % コネクション開く
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = ServerIp}),

    %% 送信用
    % チャネル開く
    {ok, ChTC} = amqp_connection:open_channel(Connection),
    % エクスチェンジを宣言
    amqp_channel:call(ChTC, #'exchange.declare'{exchange = ToClientEx, type = <<"fanout">>}),

	{Connection, ChTC}.

shutdown_connect(Connection, ChTC) ->
    % チャネル閉じる。
    ok = amqp_channel:close(ChTC),
    % コネクション閉じる。
    ok = amqp_connection:close(Connection),
	ok.

