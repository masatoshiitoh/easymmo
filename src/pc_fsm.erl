-module(pc_fsm).
-behaviour(gen_fsm).

-include_lib("amqp_client.hrl").
-include("emmo.hrl").

-export([activate/0]).

-export([start_link/1, stop/1]).
-export([attack/2, get_state/1]).
-export([heal/2]).

-export([init/1, good/2, dead/2]).
-export([handle_event/3, terminate/3]).
-export([handle_sync_event/4, handle_info/3, code_change/4]).

-record(pcstat, {stat, mq}).

%%
%% FSM will not be registerd.
%%
start_link(Hp) -> gen_fsm:start_link(pc_simple, Hp, []).

stop(Pid) -> gen_fsm:send_all_state_event(Pid, stop).

attack(Pid, Damage) -> gen_fsm:send_event(Pid, {attack, Damage}).

heal(Pid, AddHp) -> gen_fsm:send_event(Pid, {heal, AddHp}).

get_state(Pid) -> gen_fsm:sync_send_all_state_event(Pid, get_state).

init(StartHp) ->
	{ok, Mq} = chat_init("127.0.0.1", <<"xout">>, <<"xin">> ),
	{ok, good, #pcstat{stat = StartHp, mq = Mq}}.

good({attack, Damage}, #pcstat{stat = Hp, mq = Mq}) ->
	io:format("hp is ~p!!~n", [Hp]),
	NewHp = Hp - Damage,
	if
		NewHp < 1  ->
			io:fwrite("uncon!!~n"),
            {next_state, dead,
				#pcstat{stat = NewHp, mq = Mq},
				10000};

        true ->
            {next_state, good,
				#pcstat{stat = NewHp, mq = Mq}}
    end;

good({heal, AddHp}, #pcstat{stat = Hp, mq = Mq}) ->
	NewHp = Hp + AddHp,
	{next_state, good,
		#pcstat{stat = NewHp, mq = Mq}}.

dead(timeout,  #pcstat{stat = Hp, mq = Mq}) ->
    io:fwrite("respawn!!~n"),
    {next_state, good, #pcstat{stat = 1, mq = Mq}}.

handle_event(stop, _StateName, StateData) -> {stop, normal, StateData}.
terminate(normal, _StateName, _StateData) -> ok.

handle_sync_event(get_state, _From, StateName, StateData) ->
    {reply, StateName, StateName, StateData}.

%% just after setup, this message will arrive.
handle_info(#'basic.consume_ok'{}, good, State) ->
	{next_state, good, State};

handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , good,
		#pcstat{stat = Hp, mq = Mq}) ->
	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = Mq,
	%% Message = Body ,
	io:format("pc_simple instance : say Hello world~p~n", [self()]),
	Message = <<"hello, world!!">> ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = ToClientEx, routing_key = <<"chat.open">> },
		#amqp_msg{payload = Message}),
	{next_state, good,
		#pcstat{stat = Hp, mq = Mq}
	};

handle_info(_Info, StateName, StateData) -> {next_state, StateName, StateData}.

code_change(_OldVsn, StateName, StateData, _Extra) -> {ok, StateName, StateData}.



%%
%% following mq_* functions are prepareing for future experiments..
%%

mq_listen_area(chat, <<"chat.open.1">>) ->
0.

mq_change_area(chat, <<"chat.open.2">>) ->
0.

mq_end_area() ->
0.

mq_listen_id(cid, 1) ->
0.

mq_end_id() ->
0.


activate() ->
	start_link(10).

chat_init(ServerIp, ToClientEx, FromClientEx) ->
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"chat.#">>])}.

chat_terminate(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

%% chat handler

connect(Id) ->
	Reply = gen_server:call(?MODULE, {connect, Id}).

disconnect(Id) ->
	Reply = gen_server:call(?MODULE, {disconnect, Id}).

broadcast(Id, Payload) ->
	Reply = gen_server:call(?MODULE, {broadcast, Id, Payload}).


%% while subscribing, message will be delivered by #amqp_msg
chat_info({broadcast, Id, Payload}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	BinMsg = jsx:encode([{<<"id">>, list_to_binary(Id)}, {<<"message">>, list_to_binary(Payload)}]),
	%%BinMsg = list_to_binary(JsonMsg) ,
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = <<"chat.open">> },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.



init_move([ServerIp, ToClientEx, FromClientEx]) ->
	{ok, bidir_mq:init_topic(ServerIp, ToClientEx, FromClientEx, [<<"move.#">>])}.

stop_move(_Reason, State) ->
	bidir_mq:shutdown_by_state(State),
	ok.

move({move_abs, Id, Loc}, From, State) when is_record(Loc, loc)->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	Payload = io_lib:format("move,abs,~p,~p,~p", [Id, Loc#loc.x, Loc#loc.y]),
	BinMsg = list_to_binary(Payload) ,
	BinRoutingKey = list_to_binary("move.id." ++ Id ),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State};

move({move_rel, Id, DeltaX, DeltaY}, From, State) ->
	{_ServerIp, ToClientEx, FromClientEx, {_Connection, ChTC, _ChFC}} = State,
	%Payload = io_lib:format("move,rel,~p,~p,~p", [Id, DeltaX, DeltaY]),
	%%BinMsg = list_to_binary(Payload) ,
	BinMsg = jsx:encode([{<<"type">>,<<"rel">>},{<<"id">>,list_to_binary(Id)},{<<"x">>, DeltaX}, {<<"y">>, DeltaY}]),
	BinRoutingKey = list_to_binary("move.id." ++ Id ),
	amqp_channel:cast(ChTC,
		#'basic.publish'{exchange = FromClientEx, routing_key = BinRoutingKey },
		#amqp_msg{payload = BinMsg}),
	{reply, ok, State}.

