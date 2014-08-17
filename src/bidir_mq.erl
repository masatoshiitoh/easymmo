%%
%% bidir_mq.erl
%%
%% utilities for bi-directional MQ.
%%

-module(bidir_mq).
-include_lib("amqp_client.hrl").

-export([init_fanout/3]).
-export([shutdown_by_state/1]).
-export([setup_fanout/3]).
-export([shutdown_connect/3]).

init_fanout(ServerIp, ToClientEx, FromClientEx) ->
	{Connection, ChTC, ChFC} = setup_fanout(ServerIp, ToClientEx, FromClientEx),
	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}.

shutdown_by_state(State) ->
	{_ServerIp, _ToClientEx, _FromClientEx, {Connection, ChTC, ChFC}} = State,
	shutdown_connect(Connection, ChTC, ChFC).

setup_fanout(ServerIp, ToClientEx, FromClientEx) ->
    % コネクション開く
    {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = ServerIp}),

    %% 送信用(exchange name = FromClientEx, channel = ChFC)
    % チャネル開く
    {ok, ChTC} = amqp_connection:open_channel(Connection),
    % エクスチェンジを宣言
    amqp_channel:call(ChTC, #'exchange.declare'{exchange = ToClientEx, type = <<"fanout">>}),

    %% 受信用(exchange name = ToClientEx, channel = ChTC)
    % OUTチャネルを開く
    {ok, ChFC} = amqp_connection:open_channel(Connection),
    % エクスチェンジを宣言
    amqp_channel:call(ChFC, #'exchange.declare'{exchange = FromClientEx, type = <<"fanout">>}),
    % クライアント宛キューを宣言する。
    #'queue.declare_ok'{queue = Queue} = amqp_channel:call(ChFC, #'queue.declare'{exclusive = true}),
    % 指定のエクスチェンジに受信キューをバインドする。
    amqp_channel:call(ChFC, #'queue.bind'{exchange = FromClientEx, queue = Queue}),
    % 指定のキューの購読開始。
    amqp_channel:subscribe(ChFC, #'basic.consume'{queue = Queue, no_ack = true}, self()),

	{Connection, ChTC, ChFC}.

shutdown_connect(Connection, ChTC, ChFC) ->
    % チャネル閉じる。
    ok = amqp_channel:close(ChFC),
    % チャネル閉じる。
    ok = amqp_channel:close(ChTC),
    % コネクション閉じる。
    ok = amqp_connection:close(Connection),
	ok.


