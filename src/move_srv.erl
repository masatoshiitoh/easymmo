-module(move_srv).
-include_lib("amqp_client.hrl").

-export([start_link/0]).
-export([terminate/2]).
-export([init/1, handle_call/3]).
-export([start_loop/3]).

-export([start_service/3]).
-export([stop_service/3]).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, dict:new()}.

%%
%% APIs
%%
start_service(ServerIp, ToClientEx, FromClientEx)
	when is_binary(ToClientEx), is_binary(FromClientEx) ->
	Reply = gen_server:call(?MODULE, {start_service, ServerIp, ToClientEx, FromClientEx}).

stop_service(ServerIp, ToClientEx, FromClientEx) ->
	Reply = gen_server:call(?MODULE, {stop_service, ServerIp, ToClientEx, FromClientEx}).
%%
%% Internal use.
%%

start_loop(ServerIp, ToClientEx, FromClientEx) ->
    InboundExchange = FromClientEx,
    OutboundExchange = ToClientEx, 

    
    % コネクション開く
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = ServerIp}),

    %% 送信用
    % OUTチャネル開く
    {ok, ChOut} = amqp_connection:open_channel(Connection),
    % エクスチェンジを宣言
    amqp_channel:call(ChOut, #'exchange.declare'{exchange = OutboundExchange, type = <<"fanout">>}),

    %% 受信用
    % Inチャネルを開く
    {ok, ChIn} = amqp_connection:open_channel(Connection),
    % エクスチェンジを宣言
    amqp_channel:call(ChIn, #'exchange.declare'{exchange = InboundExchange, type = <<"fanout">>}),
    % Inキューを宣言する。
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(ChIn, #'queue.declare'{exclusive = true}),
    % 指定のOUTエクスチェンジに受信キューをバインドする。
    amqp_channel:call(ChIn, #'queue.bind'{exchange = InboundExchange, queue = Queue}),
    % 指定のキューの購読開始。
    amqp_channel:subscribe(ChIn, #'basic.consume'{queue = Queue, no_ack = true}, self()),

    % ok待ち
    io:format(" [*] Waiting for logs. To exit press CTRL+C~n"),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    % 受信ループ。
    loop(ChOut, OutboundExchange),

    % チャネル閉じる。
    ok = amqp_channel:close(ChIn),
    % チャネル閉じる。
    ok = amqp_channel:close(ChOut),

    % コネクション閉じる。
    ok = amqp_connection:close(Connection),
    ok.


loop(ChOut, OutboundExchange) ->
	%% 購読中は#amqp_msgでメッセージが飛んでくる。
	receive
		{#'basic.deliver'{}, #amqp_msg{payload = Body}} ->
			io:format(" [x] ~p~n", [Body]),

			Message = <<"info: Hello World!">>,
			% エクスチェンジにメッセージ送信。
			amqp_channel:cast(ChOut,
			#'basic.publish'{exchange = OutboundExchange},
			#amqp_msg{payload = Message}),
			io:format(" [x] Sent ~p~n", [Message]),

			loop(ChOut, OutboundExchange);

		"stop" -> ok 
	end.


%% gen_server behaviour %%        
terminate(Reason, State) ->
	%% TODO: write stopping code here!!
	ok.

handle_call({start_service, ServerIp, ToClientEx, FromClientEx}, From, State) ->

	%%
	%% check existing process
	%%
	Value = dict:find({ServerIp, ToClientEx, FromClientEx}, State),
	NS = case Value of
		ExistingPid when is_pid(ExistingPid) ->
			ExistingPid ! "stop",
			dict:erase({ServerIp, ToClientEx, FromClientEx}, State);
		_ ->
			State
	end,

	%%
	%% start new feeder loop
	%%
	Pid = spawn(?MODULE, start_loop, [ServerIp, ToClientEx, FromClientEx]),
	NewState = dict:store({ServerIp, ToClientEx, FromClientEx}, Pid, NS),
	{reply, ok, NewState};

handle_call({stop_service, ServerIp, ToClientEx, FromClientEx}, From, State) ->
	case dict:find({ServerIp, ToClientEx, FromClientEx}, State) of
		error ->
			{reply, {error, notfound} , State};
		{ok, Pid} when is_pid(Pid) ->
			Pid ! "stop", %% <== stop process
			NewState = dict:erase({ServerIp, ToClientEx, FromClientEx}, State),
			{reply, {ok, Pid} , NewState} 
		end.

