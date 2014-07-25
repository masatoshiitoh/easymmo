-module(chat_srv).
-include_lib("amqp_client.hrl").

-export([start_link/0]).
-export([terminate/2]).
-export([init/1, handle_call/3]).
-export([loop/4]).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	{ok, []}.

%%
%% APIs
%%
start_service(ServerIp, Exchange) ->
	Reply = gen_server:call(?MODULE, {stop_feed, ServerIp, Exchange}).

%%
%% Internal use.
%%

start_service(_Argv) ->
    InboundExchange = <<"xin">>,
    OutboundExchange = <<"xout">>,
    
    % コネクション開く
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = "localhost"}),

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
    	_ -> 0
    end.


%% gen_server behaviour %%        
terminate(Reason, State) ->
	ok.

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

