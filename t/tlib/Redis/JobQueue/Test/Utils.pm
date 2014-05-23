package Redis::JobQueue::Test::Utils;

use 5.010;
use strict;
use warnings;

use Exporter qw(
    import
);
our @EXPORT_OK  = qw(
    get_redis
);

use Net::EmptyPort;
use Test::More;
use Test::RedisServer;
use Try::Tiny;

sub get_redis
{
    my @args = @_;

    my ( $redis, $error );
    for ( 1..3 )
    {
# !!!!
diag "attempt = $_";
        try
        {
            $redis = Test::RedisServer->new( @args );
        }
        catch
        {
            $error = $_;
# !!!!
diag "error: $error";
        };
        last unless $error;
        sleep 1;
    }
    BAIL_OUT $error if $error;

    return $redis;
}

1;
