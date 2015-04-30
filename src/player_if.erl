%%
%% player_if.erl
%%
%% this module communicates players unity client via AMQP (rabbitmq client) with JSON.
%%

-module(player_if).
-include_lib("amqp_client.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).

%%
%% APIs
%%

%% client to server
new_account(Id, Password) -> impl_new_account(Id, Password).
impl_login(Id, password) -> 0.
impl_logout(Id, password) -> 0.
impl_online(Id, password) -> 0.
impl_offline(Id, password) -> 0.
impl_chat_open(Id, password) -> 0.
impl_move_rel(Id, password) -> 0.

%% server to client

impl_notify_world_stats() -> 0.		%% setup message distribution to the user.



%%
%% Implements
%%

impl_new_account(Id, Password) ->
	{auth, Result, Uid} = auth_srv:new(Id, Password),
	{token, Token, Expire} = token_srv:new(Uid),
	{new_account, Uid, Token, Expire}.

%% impl_login(Id, Password)

%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
	[ServerIp, ToClientEx, FromClientEx] = Args,
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>])}.

terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
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

