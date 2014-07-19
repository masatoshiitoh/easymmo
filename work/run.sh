#!/bin/sh

erlc -I amqp_client/include -I amqp_client/deps/rabbit_common/include amqp_example.erl

erl -pa amqp_client/ebin -pa amqp_client/deps/rabbit_common/ebin -run amqp_example test
