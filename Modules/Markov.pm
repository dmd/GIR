package Modules::Markov;

#######
## PERL SETUP
#######
use strict;
use lib ('./', '../Main');

#######
## INCLUDES
#######
use Database::MySQL;

##############
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

	&Modules::register_action('markov', \&Modules::Markov::output);
	&Modules::register_action('markov2', \&Modules::Markov::output_multi);
	&Modules::register_action('vokram', \&Modules::Markov::output_from_end);
#	&Modules::register_listener(\&Modules::Markov::user_learn, 'always');
	&Modules::register_listener(\&Modules::Markov::learn, 'low');

	&Modules::register_help('markov', \&Modules::Markov::help);
	&Modules::register_help('markov2', \&Modules::Markov::help);
	&Modules::register_help('vokram', \&Modules::Markov::help);
}

#######
## OUTPUT
#######
sub output()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
		&Bot::status("Markov output with '$first' and '$second'") if $Bot::config->{'debug'};
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
		&Bot::status("Markov output with '$first'") if $Bot::config->{'debug'};
	}
	return &gen_output($first, $second);
}

sub gen_output()
{
	my ($first, $second) = @_;

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});
	my $word;

	my $phrase = '';

	if ($first && $second) {
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first, $second);
		$word = $sth->fetchrow_hashref();
		$sth->finish();

		if ($word && $word->{'prev'}) {
			$phrase .= "$word->{'prev'} ";
		} else {
			return;
		}
	} elsif ($first) {
		# Find something starting with this
		my $query = qq~
			SELECT this, next
			FROM words
			WHERE this = ? AND next <> '__END__'
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first);
		$word = $sth->fetchrow_hashref();
		$sth->finish();

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		my $query = qq~
			SELECT this, next
			FROM words
			WHERE prev = '__BEGIN__'
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute();
		$word = $sth->fetchrow_hashref();
		$sth->finish();
	}

	$phrase .= "$word->{'this'} ";
	if ($word->{'next'} eq '__END__') {
		return $phrase;
	}

	my $query = qq~
		SELECT this, next
		FROM words
		WHERE prev = ? AND this = ?
		ORDER BY RAND() DESC
		LIMIT 1
	~;
	$db->prepare($query);

	my $count = 0;
	while (1) {
		# Get next word
		my $sth = $db->execute($word->{'this'}, $word->{'next'});
		$word = $sth->fetchrow_hashref();
		unless ($word && $word->{'this'}) {
			last;
		}
		$sth->finish();

		$phrase .= "$word->{'this'} ";

		if ($word->{'next'} eq '__END__' || $count > 25) {
			last;
		}

		$count++;
	}
	return $phrase;
}

#######
## OUTPUT (FORWARD & BACKWARD)
#######
sub output_multi()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
	}
	return &gen_output_multi($first, $second);
}

sub gen_output_multi()
{
	my ($first, $second) = @_;

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});
	my $word;

	my $phrase = '';

	if ($first && $second) {
		# First make sure the combo exists
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first, $second);
		$word = $sth->fetchrow_hashref();
		my $start = $word;
		$sth->finish();

		$phrase  = $word->{'this'};

		# Work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);

		while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__') {
			$sth    = $db->execute($word->{'prev'}, $word->{'this'});
			$word   = $sth->fetchrow_hashref();
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
		~;
		$db->prepare($query);

		$word = $start;
		while ($word && $word->{'next'} && $word->{'next'} ne '__END__') {
			$sth = $db->execute($word->{'this'}, $word->{'next'});
			$word = $sth->fetchrow_hashref();
			$phrase = "$phrase $word->{'this'}";
		}
	} elsif ($first) {
		# Find something starting with this
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ?
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first);
		$word = $sth->fetchrow_hashref();
		my $start = $word;
		$sth->finish();

		$phrase  = $word->{'this'};

		# First work backwards
		$query = qq~
			SELECT *
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND()
		~;
		$db->prepare($query);

		while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__') {
			$sth    = $db->execute($word->{'prev'}, $word->{'this'});
			$word   = $sth->fetchrow_hashref();
			$phrase = "$word->{'this'} $phrase";
		}

		# Then forward
		$query = qq~
			SELECT *
			FROM words
			WHERE prev = ? AND this = ?
			ORDER BY RAND()
		~;
		$db->prepare($query);

		$word = $start;
		while ($word && $word->{'next'} && $word->{'next'} ne '__END__') {
			$sth = $db->execute($word->{'this'}, $word->{'next'});
			$word = $sth->fetchrow_hashref();
			$phrase = "$phrase $word->{'this'}";
		}
	} else {
		$phrase = &gen_output();
	}
	return $phrase;
}

#######
## OUTPUT FROM END
#######
sub output_from_end()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $first  = undef;
	my $second = undef;
	if ($data && $data =~ /^(.+?)\s+(.+?)$/) {
		$first  = $1;
		$second = $2;
	} elsif ($data && $data =~ /^(.+)$/) {
		$first = $1;
	}
	return &gen_output_from_end($first, $second);
}

sub gen_output_from_end()
{
	my ($first, $second) = @_;
	my $word;

	my $phrase = '';

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	my $query;

	if ($first && $second) {
		$query = qq~
			SELECT prev, this, next
			FROM words
			WHERE this = ? AND next = ?
			ORDER BY RAND() DESC
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first, $second);
		$word = $sth->fetchrow_hashref();
		$sth->finish();

		if ($word && $word->{'next'}) {
			$phrase .= "$word->{'next'} ";
		} else {
			return;
		}
	} elsif ($first) {
		# Find something ending with this
		$query = qq~
			SELECT prev, this
			FROM words
			WHERE this = ? AND next = '__END__'
			ORDER BY RAND() DESC
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute($first);
		$word = $sth->fetchrow_hashref();
		$sth->finish();

		unless ($word && $word->{'this'}) {
			return $first;
		}
	} else {
		# Pick random starting word
		$query = qq~
			SELECT prev, this
			FROM words
			WHERE next = '__END__'
			ORDER BY RAND()
			LIMIT 1
		~;
		$db->prepare($query);
		my $sth = $db->execute();
		$word = $sth->fetchrow_hashref();
		$sth->finish();
	}

	$phrase = "$word->{'this'} $phrase";
	if ($word->{'prev'} eq '__BEGIN__') {
		return $phrase;
	}

	$query = qq~
		SELECT prev, this
		FROM words
		WHERE this = ? AND next = ?
		ORDER BY RAND() DESC
		LIMIT 1
	~;
	$db->prepare($query);

	my $count = 0;
	do {
		# Get next word
		my $sth = $db->execute($word->{'prev'}, $word->{'this'});
		$word = $sth->fetchrow_hashref();
		unless ($word && $word->{'this'}) {
			last;
		}
		$sth->finish();

		$phrase = "$word->{'this'} $phrase";

	} while ($word && $word->{'prev'} && $word->{'prev'} ne '__BEGIN__' && $count++ <= 25);
	return $phrase;
}

#######
## LEARN
#######
sub learn()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	# Skip 'lrrr' and 'tumblr'
	return if ($user eq 'lrrr' || $user eq 'tumblr');

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	my @parts = split(/\s+/, $data);

	return if scalar(@parts) == 0;

	unshift @parts, '__BEGIN__';
	push @parts, '__END__';

	for (my $i = 1; $i < scalar(@parts) - 1; $i++) {
		# Check to see if we already have this combo
		my $query = qq~
			SELECT prev, this, next
			FROM words
			WHERE prev = LEFT(?, 255) AND this = LEFT(?, 255) AND next = LEFT(?, 255)
		~;
		$db->prepare($query);
		my $sth = $db->execute($parts[$i - 1], $parts[$i], $parts[$i + 1]);
		my $word = $sth->fetchrow_hashref();
		$sth->finish();

		unless ($word && ($word->{'prev'} || $word->{'this'} || $word->{'next'})) {
			$query = qq~
				INSERT INTO words
				(prev, this, next)
				VALUES
				(?, ?, ?)
			~;
		}
		$db->prepare($query);
		$sth = $db->execute($parts[$i - 1], $parts[$i], $parts[$i + 1]);
		$sth->finish();
	}
}

#######
## LEARN (USER)
#######
sub user_learn()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	my $db = new Database::MySQL;
	$db->init($Bot::config->{'db_user'}, $Bot::config->{'db_pass'}, $Bot::config->{'db_name'});

	my @parts = split(/\s+/, $data);

	next if scalar(@parts) == 0;

	unshift @parts, '__BEGIN__';
	push @parts, '__END__';

	for (my $i = 1; $i < scalar(@parts) - 1; $i++) {
		# Check to see if we already have this combo
		my $query = qq~
			SELECT prev, this, next
			FROM markov
			WHERE prev = LEFT(?, 255) AND this = LEFT(?, 255) AND next = LEFT(?, 255)
		~;
		$db->prepare($query);
		my $sth = $db->execute($parts[$i - 1], $parts[$i], $parts[$i + 1]);
		my $word = $sth->fetchrow_hashref();
		$sth->finish();

		if ($word && ($word->{'prev'} || $word->{'this'} || $word->{'next'})) {
			# Update count
			$query = qq~
				UPDATE markov SET
					count = count + 1
				WHERE prev = LEFT(?, 255) AND this = LEFT(?, 255) AND next = LEFT(?, 255) AND who = ?
			~;
			$db->prepare($query);
			$db->execute($parts[$i - 1], $parts[$i], $parts[$i + 1], $user);
		} else {
			$query = qq~
				INSERT INTO markov
				(prev, this, next, who)
				VALUES
				(?, ?, ?, ?)
			~;
			$db->prepare($query);
			$sth = $db->execute($parts[$i - 1], $parts[$i], $parts[$i + 1], $user);
			$sth->finish();
		}
	}
}

#######
## HELP
#######
sub help()
{
	my ($type, $user, $data, $where, $addressed) = @_;

	if ($data eq 'markov') {
		return "'markov [<word> [<word>]]': create and print a Markov chain starting with the given word(s). At most two words can be used to start the chain. See also 'markov2' and 'vokram'";
	} elsif ($data eq 'markov2') {
		return "'markov2 <word> [<word>]': create and print a Markov chain containing the given word(s). This can appear anywhere in the chain, not just at the beginning. See also 'markov' and 'vokram'";
	} elsif ($data eq 'vokram') {
		return "'vokram <word> [<word>]': create and print a Markov chain that ends with the given word(s). At most two words can be used as the basis for the chain. See also 'markov' and 'markov2'";
	}
}

1;
