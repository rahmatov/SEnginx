#!/usr/bin/perl

# (C) Jason Liu

# Tests for nginx round_robin module.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

plan(skip_all => 'win32') if $^O eq 'MSWin32';

my @port_array = (8081, 8082, 8083);

my $test_num = @port_array;
my $t = Test::Nginx->new()->has(qw/upstream_round_robin/)->plan($test_num);

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon         off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    upstream pool {
        server 127.0.0.1:8081;
        server 127.0.0.1:8082;
        server 127.0.0.1:8083;
    }

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;
        location / {
            proxy_pass http://pool;
        }
    }
}

EOF

my $each_port;
foreach $each_port (@port_array) {
    $t->run_daemon(\&http_daemon, $each_port);
}
$t->run();

##########################################################################################################
foreach $each_port (@port_array) {
    like(http_get('/test.html'), qr/TEST-OK-IF-YOU-SEE-THIS-FROM-$each_port/m, "request $each_port");
}

##########################################################################################################


sub http_daemon {
    my ($port) = @_;
	my $server = IO::Socket::INET->new(
		Proto => 'tcp',
		LocalHost => "127.0.0.1:$port",
		Listen => 5,
		Reuse => 1
	)
		or die "Can't create listening socket: $!\n";

	while (my $client = $server->accept()) {
		$client->autoflush(1);

		my $headers = '';
		my $uri = '';

		while (<$client>) {
			$headers .= $_;
			last if (/^\x0d?\x0a?$/);
		}

		$uri = $1 if $headers =~ /^\S+\s+([^ ]+)\s+HTTP/i;

		if ($uri eq '/test.html') {

			print $client <<"EOF";
HTTP/1.1 200 OK
Connection: close

TEST-OK-IF-YOU-SEE-THIS-FROM-$port

EOF
		} else {

			print $client <<"EOF";
HTTP/1.1 404 Not Found
Connection: close

Oops, '$uri' not found
EOF
		}

		close $client;
	}
}


###############################################################################
