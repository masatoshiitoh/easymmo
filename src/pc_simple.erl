-module(pc_simple).
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

-export([mq_test/0]).
-export([mq_test_sender/2]).

-record(pcstat, {stat, mq}).

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


%%
%% FSM will not be registerd.
%%
start_link(Hp) -> gen_fsm:start_link(pc_simple, Hp, []).

stop(Pid) -> gen_fsm:send_all_state_event(Pid, stop).

attack(Pid, Damage) -> gen_fsm:send_event(Pid, {attack, Damage}).

heal(Pid, AddHp) -> gen_fsm:send_event(Pid, {heal, AddHp}).

get_state(Pid) -> gen_fsm:sync_send_all_state_event(Pid, get_state).

init(StartHp) ->
	{ok, Mq} = chat_init("192.168.56.21", <<"xout">>, <<"xin">> ),
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

%% 
%% handle_info( {#'basic.deliver'{routing_key = _RoutingKey}, #amqp_msg{payload = Body}} , good,  State) ->
%% 	{_ServerIp, ToClientEx, _FromClientEx, {_Connection, ChTC, _ChFC}} = State,
%% 	%% BinMsg = [<<"info: Auto-reply, this is move_srv! your message is ">> , Body],
%% 	BinMsg = Body,
%% 	BinRoutingKey = list_to_binary("move.map.all"),
%% 	amqp_channel:cast(ChTC,
%% 		#'basic.publish'{exchange = ToClientEx, routing_key = BinRoutingKey },
%% 		#amqp_msg{payload = BinMsg}),
%%	{noreply, State};
%% 

handle_info(_Info, StateName, StateData) -> {next_state, StateName, StateData}.

code_change(_OldVsn, StateName, StateData, _Extra) -> {ok, StateName, StateData}.



%%
%% MQ support functions.
%%


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


%% receiver
mq_test() ->
	io:format("please use topic t.1 or t.2~n",[]),
	ServerIp = "192.168.56.21",
	spawn_link(fun() ->
		{mq, ServerIp, Connection, Exchange, Channel, Queue, Topics} =
			mq_setup_topic_receiver(ServerIp, <<"testexchange">>, [<<"t.1">>]),
		mq_test_loop({mq, ServerIp, Connection, Exchange, Channel, Queue, Topics})
	end).

%% send message once.
mq_test_sender(Topic, Message)->
	Connection = mq_connect("192.168.56.21"),
	Ch = mq_setup_send_topics(Connection, <<"testexchange">>),
	amqp_channel:cast(Ch,
		#'basic.publish'{exchange = <<"testexchange">>, routing_key = list_to_binary(Topic) },
		#amqp_msg{payload = list_to_binary(Message)}).

%% followings are internal functions.

mq_test_loop( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}) ->
	mq_test_receiver(10000),
	{mq, S1, Co1, Ex1, Ch1, Q1, T1} =
		mq_replace_topic({mq, ServerIp, Connection, Exchange, Channel, Queue, Topics} , [<<"t.1">>] , [<<"t.2">>]),
	io:format("now, set topic to ~p~n", ["t.2"]),
	mq_test_receiver(10000),
	{mq, S2, Co2, Ex2, Ch2, Q2, T2} =
		mq_replace_topic({mq, S1, Co1, Ex1, Ch1, Q1, T1} , [<<"t.2">>] , [<<"t.1">>]),
	io:format("now, set topic to ~p~n", ["t.1"]),
	mq_test_loop( {mq, S2, Co2, Ex2, Ch2, Q2, T2} ).

mq_setup_topic_receiver(ServerIp, Exchange, Topics) ->
	Connection = mq_connect(ServerIp),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	#'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
	mq_replace_topic( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}, [], Topics),
	amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue, no_ack = true}, self()),
	{mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}.

mq_replace_topic( {mq, ServerIp, Connection, Exchange, Channel, Queue, Topics}, RemovingTopics, NewTopics) ->
	Ch1 = mq_add_receive_topics(Channel, Exchange,Queue, NewTopics),
	Ch2 = mq_remove_receive_topics(Ch1, Exchange, Queue, RemovingTopics),
	LatestTopics = lists:subtract(lists:append(Topics, NewTopics), RemovingTopics),
	{mq, ServerIp, Connection, Exchange, Ch2, Queue, LatestTopics}.

mq_setup_send_topics(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	Ch.

mq_connect(ServerIp) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = ServerIp}),
	Connection.

mq_disconnect(Connection) ->
    ok = amqp_connection:close(Connection).

mq_shutdown_connect(ChTC, ChFC) ->
    ok = amqp_channel:close(ChFC),
    ok = amqp_channel:close(ChTC),
	ok.

mq_add_receive_topics(Channel, Exchange, Queue, TopicList) ->
	[amqp_channel:call(Channel, #'queue.bind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	Channel.

mq_remove_receive_topics(Channel, Exchange, Queue, TopicList) ->
	[amqp_channel:call(Channel, #'queue.unbind'{
		exchange = Exchange,
		routing_key = BindingKey,
		queue = Queue})
	|| BindingKey <- TopicList],
	Channel.

mq_setup_send_routing(Connection, Exchange) ->
    {ok, Ch} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Ch, #'exchange.declare'{exchange = Exchange, type = <<"topic">>, auto_delete = true}),
	Ch.

mq_test_receiver(Timeout) ->
	receive
		#'basic.consume_ok'{} -> mq_test_receiver(Timeout);
		{#'basic.deliver'{routing_key = RoutingKey}, #amqp_msg{payload = Body}} ->
			io:format("now, receive from ~p,  body ~p~n", [RoutingKey, Body]),
			mq_test_receiver(Timeout)
		after Timeout -> 0
	end.
