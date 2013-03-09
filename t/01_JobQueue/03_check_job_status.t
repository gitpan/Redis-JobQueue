#!/usr/bin/perl -w

use 5.010;
use strict;
use warnings;

use lib 'lib';

use Test::More;
plan "no_plan";

BEGIN {
    eval "use Test::Exception";                 ## no critic
    plan skip_all => "because Test::Exception required for testing" if $@;
}

BEGIN {
    eval "use Test::RedisServer";               ## no critic
    plan skip_all => "because Test::RedisServer required for testing" if $@;
}

BEGIN {
    eval "use Net::EmptyPort";                  ## no critic
    plan skip_all => "because Net::EmptyPort required for testing" if $@;
}

use Redis::JobQueue qw(
    DEFAULT_SERVER
    DEFAULT_PORT
    DEFAULT_TIMEOUT
    STATUS_CREATED
    STATUS_WORKING
    STATUS_COMPLETED
    );

# options for testing arguments: ( undef, 0, 0.5, 1, -1, -3, "", "0", "0.5", "1", 9999999999999999, \"scalar", [] )

my $server = "127.0.0.1";
#my $port = 6379;
my $timeout = 1;

my $redis;
my $real_redis;
my $port = Net::EmptyPort::empty_port( 32637 ); # 32637-32766 Unassigned

#eval { $real_redis = Redis->new( server => "$server:$port" ) };
eval { $real_redis = Redis->new( server => DEFAULT_SERVER.":".DEFAULT_PORT ) };
if ( !$real_redis )
{
    $redis = eval { Test::RedisServer->new( conf => { port => $port }, timeout => 3 ) };
    if ( $redis )
    {
        eval { $real_redis = Redis->new( server => DEFAULT_SERVER.":".$port ) };
    }
}
my $skip_msg;
$skip_msg = "Redis server is unavailable" unless ( !$@ and $real_redis and $real_redis->ping );

SKIP: {
    diag $skip_msg if $skip_msg;
    skip( "Redis server is unavailable", 1 ) unless ( !$@ and $real_redis and $real_redis->ping );

# For real Redis:
#$redis = $real_redis;
#isa_ok( $redis, 'Redis' );

# For Test::RedisServer
$real_redis->quit;
$redis = Test::RedisServer->new( conf => { port => Net::EmptyPort::empty_port( 32637 ) } );
isa_ok( $redis, 'Test::RedisServer' );

my ( $jq, $job );
my $pre_job = {
    id           => '4BE19672-C503-11E1-BF34-28791473A258',
    queue        => 'lovely_queue',
    job          => 'strong_job',
    expire       => 30,
    status       => 'created',
    attribute    => scalar( localtime ),
    workload     => \'Some stuff up to 512MB long',
    result       => \'JOB result comes here, up to 512MB long',
    };

$jq = Redis::JobQueue->new(
    $redis,
    timeout => $timeout,
    );
isa_ok( $jq, 'Redis::JobQueue');

$jq->_call_redis( "DEL", $_ ) foreach $jq->_call_redis( "KEYS", "JobQueue:*" );

$job = $jq->add_job(
    $pre_job,
    );
isa_ok( $job, 'Redis::JobQueue::Job');

is $jq->check_job_status( $job ), STATUS_CREATED, "status OK";
is $jq->check_job_status( $job->id ), STATUS_CREATED, "status OK";

dies_ok { $jq->check_job_status() } "expecting to die - no arguments";

foreach my $arg ( ( undef, "", \"scalar", [] ) )
{
    dies_ok { $jq->check_job_status( $arg ) } "expecting to die: ".( $arg || "" );
}

is $jq->check_job_status( "something wrong" ), undef, "job does not exist";

$jq->_call_redis( "DEL", $_ ) foreach $jq->_call_redis( "KEYS", "JobQueue:*" );

#-- check_job_status -----------------------------------------------------------

$job = $jq->add_job(
    $pre_job,
    );
isa_ok( $job, 'Redis::JobQueue::Job');

is $jq->check_job_attribute( $job ), $pre_job->{attribute}, "attribute OK";
is $jq->check_job_attribute( $job->id ), $pre_job->{attribute}, "attribute OK";

dies_ok { $jq->check_job_attribute() } "expecting to die - no arguments";

foreach my $arg ( ( undef, "", \"scalar", [] ) )
{
    dies_ok { $jq->check_job_attribute( $arg ) } "expecting to die: ".( $arg || "" );
}

is $jq->check_job_attribute( "something wrong" ), undef, "job does not exist";

$jq->_call_redis( "DEL", $_ ) foreach $jq->_call_redis( "KEYS", "JobQueue:*" );

};