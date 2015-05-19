%%
%% player_if.erl
%%
%% this module communicates players unity client via AMQP (rabbitmq client) with JSON.
%% use internal service for this work. call internal services via Erlang gen_server framework.
%%

-module(player_if).
-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).
-export([rpctest/0]).
-export([test/0]).

-export([rpc_echo/1]).
-export([rpc_make_new_account/2]).
-export([rpc_login/2]).
-export([rpc_logout/2]).
-export([rpc_check_token/2]).
-export([rpc_online/2]).
-export([rpc_offline/2]).

rpctest() ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = "192.168.56.21"}),
	io:format("connection ok~n",[]),

	EchoPid = amqp_rpc_client:start(Connection, <<"echo">>),
	io:format("player_if/ctest:call echo returned with '~p'~n",
		[ binary_to_term(amqp_rpc_client:call(EchoPid,
					term_to_binary( [<<"ctest calls!">>])))]),

	NewAcctPid = amqp_rpc_client:start(Connection, <<"new_account">>),
	io:format("player_if/ctest:call newaccount returned with '~p'~n",
		[ binary_to_term(amqp_rpc_client:call(NewAcctPid,
					term_to_binary( [<<"mailaddr@example.jp">>, <<"pasuwado">>]))) ]),

	LogoutPid = amqp_rpc_client:start(Connection, <<"logout">>),
	io:format("player_if/ctest:call logout returned with '~p'~n",
		[ binary_to_term(amqp_rpc_client:call(LogoutPid,
					term_to_binary([<<"sampletoken00">>]))) ]),

	amqp_rpc_client:stop(LogoutPid),
	amqp_rpc_client:stop(NewAcctPid),
	amqp_rpc_client:stop(EchoPid),

	ok.

test() ->
	{ok, Uid, Token} = new_account("test0000", "1111"),
	ok = check_token(Uid, Token),
	ok = logout(Uid, Token),
	ok.


%%
%% APIs
%%

%%
%% client to server
%% this is for direct call test. (why test?, -> all clients access to this via AMQP.)
%%
new_account(Id, Password) -> impl_new_account(Id, Password).
login(Id, Password) -> impl_login(Id, Password).
logout(Uid, Token) -> impl_logout(Uid, Token).
check_token(Uid, Token) -> impl_check_token(Uid, Token).

online(Token) -> 0.
offline(Token) -> 0.


%%
%% RPC implements
%%

get_default_rpcs() -> [
	{<<"echo">>,		{?MODULE, rpc_echo}},
	{<<"new_account">>,	{?MODULE, rpc_make_new_account}},
	{<<"login">>,		{?MODULE, rpc_login}},
	{<<"logout">>,		{?MODULE, rpc_logout}},
	{<<"check_token">>,	{?MODULE, rpc_check_token}},
	{<<"online">>,		{?MODULE, rpc_online}},
	{<<"offline">>,		{?MODULE, rpc_offline}}
].

%%
%% server process body here.
%% returns binary values.
%%
rpc_echo(_Payload) -> term_to_binary({ok,"echo!!"}).

rpc_make_new_account(LoginId, Password) ->
	term_to_binary(impl_new_account(LoginId, Password)).

rpc_login(LoginId, Password) ->
	term_to_binary(impl_login(LoginId, Password)).

rpc_logout(Uid, Token) ->
	term_to_binary(impl_logout(Uid, Token)).

rpc_check_token(Uid, Token) ->
	term_to_binary(impl_check_token(Uid, Token)).

rpc_online(Uid, Token) -> ng.
rpc_offline(Uid, Token) -> ng.



%%
%% Implements
%%

impl_new_account(Id, Password) ->
	{ok, Uid} = auth_srv:add(Id, Password),
	Token = token_srv:add(Uid),
	{ok, Uid, Token}.

impl_login(Id, Password) ->
	{ok, Uid} = auth_srv:login(Id, Password),
	Token = token_srv:add(Uid),
	{ok, Uid, Token}.

impl_logout(Uid, Token) ->
	ok = auth_srv:logout(Uid, Token),
	ok = token_srv:remove(Uid, Token).

impl_check_token(Uid, Token) ->
	Result = token_srv:check(Uid, Token).

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
	[ServerIp, ToClientEx, FromClientEx] = Args,

	%% setup topic receiver
	%% now, this just listens ONLY chat.# topic.

	{ServerIp, ToClientEx, FromClientEx, {Connection, ChTC, ChFC}}
		= bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>]),

	%% setup RPC listeners
	RpcPids1 = [amqp_rpc_server:start_link(Connection, QueueName, fun(Payload) ->
					AList = binary_to_term(Payload),
					apply(M,F,AList) end)
		|| {QueueName, {M, F}} <- get_default_rpcs() ],
	RpcPids = RpcPids1,

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
%handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , State) ->
%	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
%	Message = Body ,
%	amqp_channel:cast(ChTC,
%		#'basic.publish'{exchange = ToClientEx, routing_key = <<"chat.open">> },
%		#amqp_msg{payload = Message}),
%	{noreply, State};

%% drop all
handle_info(X, State) ->
	io:format("handle_info get unknown message ~p~n", [X]),
	{noreply, State}.

handle_call({broadcast, Id, Payload}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = jsx:encode([{<<"id">>, list_to_binary(Id)}, {<<"message">>, list_to_binary(Payload)}]),
	%%BinMsg = list_to_binary(JsonMsg) ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = <<"chat.open">> },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.

