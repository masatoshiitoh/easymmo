%%
%% move_srv.erl
%%
%%

-module(move_srv).
-include_lib("amqp_client.hrl").

-include("emmo.hrl").

-export([start_link/3]).
-export([terminate/2]).
-export([init/1]).
-export([handle_info/2]).
-export([handle_call/3]).

-export([move_abs/2]).
-export([move_rel/3]).

%%
%% APIs
%%

move_abs(Id, Loc) ->
	Reply = gen_server:call(?MODULE, {move_abs, Id, Loc}).

move_rel(Id, X, Y) ->
	Reply = gen_server:call(?MODULE, {move_rel, Id, X, Y}).


%%
%% Behaviors
%%
start_link(ServerIp, ToClientEx, FromClientEx) ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [ServerIp, ToClientEx, FromClientEx], []).

init(Args) ->
    [ServerIp, ToClientEx, FromClientEx] = Args,
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"move.#">>])}.

terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

handle_call({move_abs, Id, Loc}, From, State) when is_record(Loc, loc)->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Payload = io_lib:format("move,abs,~p,~p,~p", [Id, Loc#loc.x, Loc#loc.y]),
	BinMsg = list_to_binary(Payload) ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = <<"move.id.99999">> },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State};

handle_call({move_rel, Id, DeltaX, DeltaY}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Payload = io_lib:format("move,rel,~p,~p,~p", [Id, DeltaX, DeltaY]),
	BinMsg = list_to_binary(Payload) ,
	BinRoutingKey = list_to_binary("move.id." ++ Id ),
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
	BinMsg = <<"info: Hello, this is move_srv!">>,
	BinRoutingKey = list_to_binary("move.id.99999"),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{noreply, State}.


