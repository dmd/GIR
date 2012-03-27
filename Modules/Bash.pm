package Modules::Bash;

#######
## PERL SETUP
#######
use strict;

#######
## INCLUDES
#######
use HTML::Entities;
use LWP::UserAgent;

##############
sub new()
{
	my $pkg = shift;
	my $obj = { };
	bless $obj, $pkg;
	return $obj;
}

my $bash_url_expr = qr[http://bash.org/\?(\d+)$];

sub register()
{
	my $this = shift;

	Modules::register_action('bash', \&Modules::Bash::process_from_text);
	Modules::register_action($bash_url_expr, \&Modules::Bash::process_from_url);

	Modules::register_help('bash', \&Modules::Bash::help);
}

sub process_from_url($)
{
	my ($message) = @_;

	if ($message->message() =~ $bash_url_expr) {
		return _get_quote($1);
	}

	return undef;
}

sub process_from_text($)
{
	my ($message) = @_;

	if ($message->message() =~ /(\d+)/) {
		return _get_quote($1);
	}

	return undef;
}

sub _get_quote($)
{
	my ($id) = @_;

	# Look for quote in DB cache
	my $db = new Database::MySQL();
	$db->init($Bot::config->{'database'}->{'user'}, $Bot::config->{'database'}->{'password'}, $Bot::config->{'database'}->{'name'});

	my $sql = qq(
		SELECT quote
		FROM bashquotes
		WHERE id = ?
	);
	$db->prepare($sql);
	my $sth = $db->execute($id);
	my $row = $sth->fetchrow_hashref();

	my $quote = $row ? $row->{'quote'} : undef;

	if ($quote) {
		return $quote;
	}

	# Fetch from bash.org
	my $ua = new LWP::UserAgent;
#	if (my $proxy = Bot::getparam('httpproxy')) {
#		$ua->proxy('http', $proxy)
#	};

	$ua->timeout(10);
	my $request = new HTTP::Request('GET', "http://bash.org/?${id}");
	my $response = $ua->request($request); 

	if (!$response->is_success) {
		return "Something failed in connecting to bash.org. Try again later.";
	}

	my $content = $response->content();

	if ($content =~ /Quote #${id} was rejected/ || $content =~ /Quote #${id} does not exist/ || $content =~ /Quote #${id} is pending moderation/) {
		return "Couldn't get quote ${id}. It probably doesn't exist";
	}

	if ($content =~ /\<p class=\"qt\"\>(.+?)\<\/p\>/s) {
		my $quote = HTML::Entities::decode_entities($1);
		$quote =~ s/\<br \/\>/\n/g;

		$sql = qq(
			INSERT INTO bashquotes
			(id, quote)
			VALUES
			(?, ?)
		);
		$db->prepare($sql);
		$db->execute($id, $quote);

		return $quote;
	} else {
		return "Couldn't get quote ${id}. It probably doesn't exist.";
	}
}

sub help($)
{
	my $message = shift;

	return "'bash <id>': retrieves quote <id> from bash.org and displays it.";
}

1;
