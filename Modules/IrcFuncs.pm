package Modules::IrcFuncs;

use strict;

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

	&Modules::register_action('op', \&Modules::IrcFuncs::op);
	&Modules::register_action('deop', \&Modules::IrcFuncs::deop);
	&Modules::register_action('kick', \&Modules::IrcFuncs::kick);
	&Modules::register_action('nick', \&Modules::IrcFuncs::change_nick);

	&Modules::register_help('op', \&Modules::IrcFuncs::help);
	&Modules::register_help('deop', \&Modules::IrcFuncs::help);
	&Modules::register_help('kick', \&Modules::IrcFuncs::help);
	&Modules::register_help('nick', \&Modules::IrcFuncs::help);
}


sub op()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Split into parts
	my ($password, $channel, $target) = split(/\s+/, $message);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'op')) {
		if ($addressed || $type eq 'private') {
			return "You don't have permission to do that, $user!";
		} else {
			return;
		}
	}

	&Bot::give_op($channel, $target || $user);

	return 'NOREPLY';
}

sub deop()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Split into parts
	my ($password, $channel, $target) = split(/\s+/, $message);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'deop')) {
		if ($addressed || $type eq 'private') {
			return "You don't have permission to do that, $user!";
		} else {
			return;
		}
	}

	&Bot::take_op($channel, $target || $user);

	return 'NOREPLY';
}

sub kick()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Split into parts
	my ($password, $channel, $target, $reason) = split(/\s+/, $message, 4);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'kick')) {
		if ($addressed || $type eq 'private') {
			return "You don't have permission to do that, $user!";
		} else {
			return;
		}
	}

	&Bot::kick($channel, $target, $reason);

	return 'NOREPLY';
}

sub change_nick()
{
	my ($type, $user, $message, $where, $addressed) = @_;

	# Split into parts
	my ($password, $nick) = split(/\s+/, $message, 2);

	# Check for access
	unless (&Modules::Access::check_access($user, $password, 'nick')) {
		if ($addressed || $type eq 'private') {
			return "You don't have permission to do that, $user!";
		} else {
			return;
		}
	}

	# Change nickname
	&Bot::change_nick($nick);

	return 'NOREPLY';
}

sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	if ($data eq 'op') {
		return "'op <password> <channel> [<user>]': Gives ops to <user> (or you, if no one is named) in <channel>. I need to have ops for this to work, of course. Private messages only.";
	} elsif ($data eq 'deop') {
		return "'deop <password> <channel> [<user>]': Removes ops from <user> (or you, if no one is named) in <channel>. I need to have ops for this to work. Private messages only.";
	} elsif ($data eq 'kick') {
		return "'kick <password> <channel> <user> [<reason>]': Kicks <user> from <channel>. I need to have ops in that channel for this to work. Private messages only.";
	} elsif ($data eq 'nick') {
		return "'nick <password> <name>': Changes my IRC nick to <name>. Private messages only.";
	}
}

1;
