package GIR::Util;

use v5.10;
use strict;
use warnings;
use parent 'Exporter';

use Database::Postgres;

use LWP::UserAgent;

our @EXPORT = qw/ db get_url /;

sub db()
{
	state $db;

	unless (defined $db) {
		$db = Database::Postgres->new(
			'database' => $GIR::Bot::config->{'database'}->{'name'},
			'password' => $GIR::Bot::config->{'database'}->{'password'},
			'username' => $GIR::Bot::config->{'database'}->{'user'},
		);
	}

	return $db;
}

sub get_url($)
{
	my ($url) = @_;

	my $agent = LWP::UserAgent->new(
		'agent' => 'Mozilla/5.0',
		'timeout' => 3,
	);
	my $response = $agent->get($url);

	unless ($response->is_success) {
		die $response->status_line;
	}

	return $response->content;
}

1;
