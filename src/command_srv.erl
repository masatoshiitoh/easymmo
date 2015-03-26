%%
%% command_srv.erl
%%
%% This module handles request command messages from clients and NPCs.
%%

-module(command_srv).
-include_lib("amqp_client.hrl").

-include("emmo.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).

-export([login/2]).
-export([logout/1]).
-export([get_all/1]).
-export([req_start/1]).
-export([req_stop/1]).

%%
%% APIs
%%

login(UserId,Password) ->
	Reply = gen_server:call(?MODULE, {login, UserId, Password}).

logout(Id) ->
	Reply = gen_server:call(?MODULE, {logout, Id}).

get_all(Id) ->
	Reply = gen_server:call(?MODULE, {get_all, Id}).

req_start(Id) ->
	Reply = gen_server:call(?MODULE, {req_start, Id}).

req_stop(Id) ->
	Reply = gen_server:call(?MODULE, {req_stop, Id}).

%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
    [ServerIp, ToClientEx, FromClientEx] = Args,
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"command.#">>])}.

terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

handle_call({add, Id}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = jsx:encode([{<<"type">>,<<"add">>},{<<"id">>,list_to_binary(Id)}]),
	BinRoutingKey = list_to_binary("command.id." ++ Id ),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State};

handle_call({del, Id}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = jsx:encode([{<<"type">>,<<"del">>},{<<"id">>,list_to_binary(Id)}]),
	BinRoutingKey = list_to_binary("command.id." ++ Id ),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, State) ->
	{noreply, State};

%% while subscribing, message will be delivered by #amqp_msg
handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , State) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	%%BinMsg = [<<"info: Auto-reply, this is command_srv! your message is ">> , Body],
	BinMsg = Body,
	BinRoutingKey = list_to_binary("command.map.all"),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{noreply, State}.



