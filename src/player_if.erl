%%
%% player_if.erl
%%
%% this module communicates players unity client via AMQP (rabbitmq client) with JSON.
%% use internal service for this work. call internal services via Erlang gen_service framework.
%%

-module(player_if).
-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).
-export([ctest/0]).

ctest() ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = "192.168.56.21"}),
	io:format("connection ok~n",[]),
	Pid = amqp_rpc_client:start(Connection, <<"authrpc">>),
	io:format("start link ok, ~p~n",[Pid]),
	io:format("call return ~p~n",[ amqp_rpc_client:call(Pid, <<"ctest calls!">>) ]),
	amqp_rpc_client:stop(Pid),
	ok.
	
%%
%% APIs
%%

%% client to server
new_account(Id, Password) -> impl_new_account(Id, Password).
login(Id, Password) -> impl_login(Id, Password).
logout(Token) -> impl_logout(Token).

impl_online(Id, password) -> 0.
impl_offline(Id, password) -> 0.
impl_chat_open(Id, password) -> 0.
impl_move_rel(Id, password) -> 0.

%% server to client

impl_notify_world_stats() -> 0.		%% setup message distribution to the user.


%%
%% Echo - default service for RPC
%%
rpc_echo(X) -> X.



%%
%% Implements
%%

impl_new_account(Id, Password) ->
	{auth, Result, Uid} = auth_srv:new(Id, Password),
	{token, Token, Expire} = token_srv:new(Uid),
	{new_account, Uid, Token, Expire}.

impl_login(Id, Password) ->
	{auth, Result, Uid} = auth_srv:lookup(Id, Password),
	{token, Token, Expire} = token_srv:new(Uid),
	{login, Uid, Token, Expire}.

impl_logout(Token) ->
	{auth, ok} = auth_srv:record_logout(Token),
	{token, ok} = token_srv:invalidate(Token),
	{logout, ok}.


%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).


%%
%% ListOfRpcEntries is [ { "rpcname", {M, F}}, ... ]
%% "rpcname" is list, this is queue name for its rpc entry.
%%
init(Args) ->
	[ServerIp, ToClientEx, FromClientEx, ListOfRpcEntries] = Args,

	%% setup topic receiver
	%% now, this just listens ONLY chat.# topic.

	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}
		= bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>]),

	%% setup RPC listeners
	RpcPids =
		[
			[Pid] = amqp_rpc_server:start_link(Connection, QueueName, fun(A) -> apply(M, F, A) end)
				|| {QueueName, {M, F}} <- ListOfRpcEntries
		],

	{ok, {ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}, RpcPids}}.

terminate(_Reason, State) ->
	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}, RpcPids} = State,

	%% stop RPC listeners
	_Terminated = [amqp_rpc_server:stop(Pid) || Pid <- RpcPids],

	%% stop topic receiver
	bidir_mq:shutdown_by_state({ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}),

	ok.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

%% while subscribing, message will be delivered by #amqp_msg
handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , State) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Message = Body ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = <<"chat.open">> },
		#amqp_msg{payload = Message}),
	{noreply, State}.

handle_call({broadcast, Id, Payload}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = jsx:encode([{<<"id">>, list_to_binary(Id)}, {<<"message">>, list_to_binary(Payload)}]),
	%%BinMsg = list_to_binary(JsonMsg) ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = <<"chat.open">> },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.

