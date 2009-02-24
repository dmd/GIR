package Modules::Greeting;

use strict;

my @hello;

BEGIN {
	# ways to say hello
	@hello = (
		'hello',
		'hi',
		'hey',
		'niihau',
		'bonjour',
		'hola',
		'salut',
		'que tal',
		'privet',
		"what's up"
	);
}

sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	&Modules::register_action("REGEXP:^\\s*(h(ello|i( there)?|owdy|ey|ola)|salut|bonjour|niihau|que\\s*tal)(\\,|\\s)?($Bot::config->{'nick'})?\\s*\$", \&Modules::Greeting::process);
}

sub process()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	if (!$addressed and rand() > 0.35) {
		# 65% chance of replying to a random greeting when not addressed
		return;
	}

	return $hello[int(rand(@hello))] . ', ' . $user;

}

1;
