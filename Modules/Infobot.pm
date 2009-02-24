package Modules::Infobot;

#######
## PERL SETUP
#######
use strict;
use lib ('./', '../Main');

#######
## INCLUDES
#######
use Database::MySQL;

#######
## GLOBALS
#######
my @dunno = ("I don't know", 'Wish I knew', 'Beats me', 'I have no idea', "I think it's your mother");

my $feedbacked = 0;

#######
## MAIN
#######
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

	&Modules::register_action('REGEXP:^(.+)\s+(is|are)\s+(.+)$', \&Modules::Infobot::process); # learn()
	&Modules::register_action('REGEXP:^forget\s+(.+)$', \&Modules::Infobot::process); # forget()
	&Modules::register_action('REGEXP:^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$', \&Modules::Infobot::process); # amend()
	&Modules::register_action('REGEXP:^(what\s+[is|are]*\s+)(.+?)(\?)*$', \&Modules::Infobot::process); # reply()
	&Modules::register_action('REGEXP:^(.+)\?$', \&Modules::Infobot::process); # reply
	&Modules::register_action('REGEXP:^no\,?\s+(' . $Bot::config->{'nick'} . ')?\,?\s*(.+?)\s+(is|are)\s+(.+)$', \&Modules::Infobot::process); # replace()
	&Modules::register_action('REGEXP:^(.+)\s+(is|are)\s+also\s+(.+)$', \&Modules::Infobot::process); # append()
	&Modules::register_action('lock', \&Modules::Infobot::lock); # lock()
	&Modules::register_action('unlock', \&Modules::Infobot::unlock); # unlock()

	&Modules::register_listener(\&Modules::Infobot::reply);
}

sub process()
{
	my ($type, $who, $message, $where, $addressed) = @_;

	# Figure out what we're doing
	if ($message =~ /^no\,?\s+($Bot::config->{'nick'})?\,?\s*(.+?)\s+(is|are)\s+(.+)$/i) {
		return &replace($type, $who, $2, $3, $4, $addressed || $1);
	} elsif ($message =~ /^(what\s+[is|are]*\s+)(.+?)(\?)*$/i) {
		return &reply($type, $who, $2, $where, $addressed);
	} elsif ($message =~ /^(.+)\?$/) {
		return &reply($type, $who, $1, $where, $addressed);
	} elsif ($message =~ /^(.+)\s+(is|are)\s+also\s+(.+)$/i) {
		return &append($type, $who, $1, $2, $3, $addressed);
	} elsif ($message =~ /^(.+)\s+(is|are)\s+(.+)$/i) {
		return &learn($type, $who, $1, $2, $3, $addressed);
	} elsif ($message =~ /^forget\s+(.+)$/i) {
		return &forget($type, $who, $1, $addressed);
	} elsif ($message =~ /^(.+)\s+\=\~\s*s\/(.+)\/(.+)\/$/i) {
		return &amend($type, $who, $1, $2, $3, $addressed);
	} else {
		&Bot::status("Infobot::process fell through somehow: message == $message") if $Bot::config->{'debug'};
	}
}

sub learn()
{
	my ($type, $who, $phrase, $relates, $value, $addressed) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Check to see if we already have something matching this
	my $query = qq~
		SELECT phrase, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $result = $sth->fetchrow_hashref();

	$sth->finish();

	if ($result && $result->{'phrase'}) {
		if ($addressed || $type eq 'private') {
			return "... but $phrase $relates $result->{'value'}...";
		} else {
			return 'NOREPLY';
		}
	} else {
		$query = qq~
			INSERT INTO infobot
			(phrase, relates, value)
			VALUES
			(?, ?, ?)
		~;
		$db->prepare($query);
		$db->execute($phrase, $relates, $value);	

		&Bot::status("LEARN: $phrase =$relates=> $value");
	}

	if ($addressed || $type eq 'private') {
		return "OK, $who";
	} else {
		return 'NOREPLY';
	}
}

sub append()
{
	my ($type, $who, $phrase, $relates, $value, $addressed) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Get current info
	my $query = qq~
		SELECT phrase, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $result = $sth->fetchrow_hashref();

	$sth->finish();

	if ($result && $result->{'phrase'}) {
		# Make sure the item isn't locked
		if ($result->{'locked'}) {
			if ($addressed || $type eq 'private') {
				&Bot::status("LOCKED: $result->{'phrase'}");
				return "I can't update that, $who";
			} else {
				return 'NOREPLY';
			}
		}

		$result->{'value'} .= '|' . $value;

		$query = qq~
			UPDATE infobot SET
				value = ?
			WHERE LOWER(phrase) = LOWER(?)
		~;
		$db->prepare($query);
		$db->execute($result->{'phrase'}, $result->{'value'});
	} else {
		if ($addressed || $type eq 'private') {
			return "I didn't have anything matching '$phrase', $who";
		}
	}

	if ($addressed) {
		return "OK, $who";
	}
}

sub forget()
{
	my ($type, $who, $what, $addressed) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# cut off final punctuation
	$what =~ s/[.!?]+$//;

	my ($found, $locked) = (0, 0);

	# Check if we have something matching this
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);

	while (my $result = $sth->fetchrow_hashref()) {
		if ($result->{'locked'}) {
			$locked = 1;
			&Bot::status("LOCKED: $result->{'phrase'}");
		} else {
			$found = 1;

			# Remove
			$query = qq~
				DELETE FROM infobot
				WHERE LOWER(phrase) = LOWER(?)
			~;
			$db->prepare($query);
			$db->execute($what);

			&Bot::status("FORGET: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");
		}
	}

	$sth->finish();

	if ($found) {
		return "$who: I forgot $what";
	} elsif ($locked) {
		if ($addressed || $type eq 'private') {
			return "I can't forget that, $who";
		} else {
			return 'NOREPLY';
		}
	} elsif ($addressed || $type eq 'private') {
		return "$who, I didn't have anything matching $what";
	}
}

sub amend()
{
	my ($type, $who, $what, $replace, $with, $addressed) = @_;

	my $rep_part = quotemeta($replace);

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Look for initial value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if ($addressed || $type eq 'private') {
			return "I don't have anything matching '$what', $who";
		} else {
			return 'NOREPLY';
		}
	}

	# Check if it's locked
	if ($result->{'locked'}) {
		if ($addressed || $type eq 'private') {
			&Bot::status("LOCKED: $result->{'phrase'}");
			return "I can't update that, $who";
		} else {
			return 'NOREPLY';
		}
	}

	# Check that it matches
	unless ($result->{'value'} =~ /$rep_part/i && ($addressed || $type eq 'private')) {
		return "That doesn't contain '$replace', $who";
	}

	&Bot::status("OLD: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Replace
	$result->{'value'} =~ s/$rep_part/$with/i;

	&Bot::status("NEW: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($result->{'value'}, $result->{'phrase'});

	if ($addressed || $type eq 'private') {
		return "OK, $who";
	}
}

sub replace()
{
	my ($type, $who, $what, $relates, $value, $addressed) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Look up current value
	my $query = qq~
		SELECT phrase, relates, value, locked
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($what);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if ($addressed || $type eq 'private') {
			return "I don't have anything matching '$what', $who";
		} else {
			return 'NOREPLY';
		}
	}

	# Check if the item is locked
	if ($result->{'locked'}) {
		if ($addressed || $type eq 'private') {
			&Bot::status("LOCKED: $result->{'phrase'}");
			return "I can't update that, $who";
		} else {
			return 'NOREPLY';
		}
	}

	&Bot::status("WAS: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");
	&Bot::status("IS:  $result->{'phrase'} =$relates=> $value");

	# Update
	$query = qq~
		UPDATE infobot SET
			value = ?,
			relates = ?
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($value, $relates, $what);

	if ($addressed || $type eq 'private') {
		return "OK, $who";
	}
}

sub reply()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Take off any trailing punctuation
	$data =~ s/[\?|\!|\.|\,|\s*]+$//;

	# Look for a match for the whole string
	my $query = qq~
		SELECT phrase, relates, value
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
		LIMIT 1
	~;
	$db->prepare($query);
	my $sth = $db->execute($data);
	my $result = $sth->fetchrow_hashref();

	unless ($result && $result->{'phrase'}) {
		if (defined($type)) {
			return;
		} elsif ($addressed || $type eq 'private') {
			return $dunno[int(rand(scalar(@dunno)))] . ", $user";
		} else {
			return 'NOREPLY';
		}
	}

	&Bot::status("FOUND: $result->{'phrase'} =$result->{'relates'}=> $result->{'value'}");

	# Parse if we need to
	my @parts = split(/\|/, $result->{'value'});
	if (scalar(@parts) > 1) {
		$result->{'value'} = $parts[int(rand(scalar(@parts)))];
	}

	if ($result->{'value'} =~ /^\s*\<reply\>\s*(.+)$/) {
		return &parse_special($1, $user);
	} elsif ($result->{'value'} =~ /^\s*\<reply\>\s*$/) {
		return 'NOREPLY';
	} elsif ($result->{'value'} =~ /^\s*\<action\>\s*(.+)$/) {
		&Bot::action($where, &parse_special($1, $user));
		return 'NOREPLY';
	} elsif ($result->{'value'} =~ /^\s*(.+)?\s*\<markov\>\s*(.+)?$/) {
		my $prepend = &trim($1);
		my $phrase  = &trim($2);
		my $result  = '';
		if ($phrase) {
			$phrase = &parse_special($phrase, $user);
			my @parts = split(/\s+/, $phrase);
			if (scalar(@parts) >= 2) {
				$result = &Modules::Markov::gen_output($parts[0], $parts[1]);
			} elsif (scalar(@parts) == 1) {
				$result = &Modules::Markov::gen_output($parts[0]);
			} else {
				$result = &Modules::Markov::gen_output();
			}
		} else {
			$result = &Modules::Markov::gen_output();
		}
		if ($prepend) {
			$prepend = &parse_special($prepend, $user);
			return "$prepend $result";
		} else {
			return $result;
		}
	} elsif ($result->{'value'} =~ /^\s*\<markov2\>\s*(.+)?$/) {
		my $phrase = &trim($1);
		if ($phrase) {
			$phrase = &parse_special($phrase, $user);
			my @parts = split(/\s+/, $phrase);
			if (scalar(@parts) >= 2) {
				return &Modules::Markov::gen_output_multi($parts[0], $parts[1]);
			} elsif (scalar(@parts) == 1) {
				return &Modules::Markov::gen_output_multi($parts[0]);
			} else {
				return &Modules::Markov::gen_output();
			}
		} else {
			return &Modules::Markov::gen_output();
		}
	} elsif ($result->{'value'} =~ /^\s*(.+)?\s*\<vokram\>\s*(.+)?$/) {
		my $append = &trim($1);
		my $phrase = &trim($2);
		my $result = '';
		if ($phrase) {
			$phrase = &parse_special($phrase, $user);
			my @parts = split(/\s+/, $phrase);
			if (scalar(@parts) >= 2) {
				$result = &Modules::Markov::gen_output_from_end($parts[0], $parts[1]);
			} elsif (scalar(@parts) == 1) {
				$result = &Modules::Markov::gen_output_from_end($parts[0]);
			} else {
				$result = &Modules::Markov::gen_output_from_end();
			}	
		} else {
			$result = &Modules::Markov::gen_output_from_end();
		}
		if ($append) {
			$append = &parse_special($append, $user);
			return "$result$append";
		} else {
			return $result;
		}
	} elsif ($result->{'value'} =~ /^\s*\<feedback\>\s*(.+)$/) {
		if ($feedbacked > 0) {
			$feedbacked = 0;
			return undef;
		}
		my $phrase = $1;
		$feedbacked = 1;
		$sth->finish();
		$db->close();
		&Modules::dispatch($type, $user, $phrase, $where, $addressed);
		$feedbacked = 0;
		return 'NOREPLY';
	} else {
		return "$result->{'phrase'} $result->{'relates'} " . &parse_special($result->{'value'}, $user);
	}
}

sub lock()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $data, 2);

	# Only handle this privately
	unless ($type eq 'private') {
		return 'NOREPLY';
	}

	# Make sure the user can do that
  unless (&Modules::Access::check_access($user, $password, 'lock')) {
    return "You don't have permission to do that, $user!";
  }

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry && $entry->{'phrase'}) {
		return "I don't have anything matching '$phrase', $user";
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 1
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, $user";
}

sub unlock()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Only handle this privately
	unless ($type eq 'private') {
		return 'NOREPLY';
	}

	# Split into parts
	my ($password, $phrase) = split(/\s+/, $data, 2);

	# Make sure the user can do that
  unless (&Modules::Access::check_access($user, $password, 'unlock')) {
    return "You don't have permission to do that, $user!";
  }

	# Open database
	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	# Make sure phrase exists
	my $query = qq~
		SELECT *
		FROM infobot
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	my $sth = $db->execute($phrase);

	my $entry = $sth->fetchrow_hashref();
	unless ($entry && $entry->{'phrase'}) {
		return "I don't have anything matching '$phrase', $user";
	}

	# Update record
	$query = qq~
		UPDATE infobot SET
			locked = 0
		WHERE LOWER(phrase) = LOWER(?)
	~;
	$db->prepare($query);
	$db->execute($phrase);

	return "OK, $user";
}	


# Handle $who in string
sub parse_special()
{
	my ($str, $user) = @_;

	$str =~ s/\$who/$user/ig;

	return $str;
}

sub trim()
{
	my $str = shift;

	$str =~ s/^\s+//;
	$str =~ s/\s+$//;

	return $str;
}

1;
