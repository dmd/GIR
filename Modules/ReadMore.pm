package Modules::ReadMore;

use strict;

sub register
{
	GIR::Modules::register_listener(\&watch_for_readmore, 1);
	GIR::Modules::register_action('readmorestats', \&readmorestats);
}

sub watch_for_readmore
{
	my ($message) = @_;

	return unless $message->is_public;

	if ($message->message =~ /Read more( here)?:?\s*http/) {
		log_and_laugh($message);
	}
}

sub log_and_laugh
{
	my ($message) = @_;

	my $db = db();

	# Check for existing row
	my $sql = q(
		SELECT nick
		FROM readmore
		WHERE nick = LOWER(?)
	);
	if (defined $db->statement($sql)->execute($message->from)->fetch) {
		$sql = q(
			UPDATE readmore
			SET readmored = readmored + 1
			WHERE nick = LOWER(?)
		);
	} else {
		$sql = q(
			INSERT INTO readmore
			(nick, readmored)
			VALUES
			(LOWER(?), 1)
		);
	}
	$db->statement($sql)->execute($message->from);

	return sprintf("LOL %s got readmored", $message->from);
}

sub readmorestats
{
	my ($message) = @_;

	my $db = db();
	if ($message->message ne '') {
		my $who = $message->message;
		my $sql = q(
			SELECT readmored
			FROM readmore
			WHERE nick = LOWER(?)
		);
		my $statement = $db->statement($sql)->execute($message->message);
		my $count = $statement->fetch('readmored');
		if ($count) {
			return "${who} has been readmored ${count} time(s)";
		} else {
			return "${who} has never been readmored";
		}

	} else {
		my $sql = q(
			SELECT nick, readmored
			FROM readmore
			ORDER BY readmored DESC
			LIMIT 1
		);
		my $statement = $db->statement($sql)->execute;
		my $row = $statement->fetch;
		my $who = $row->{'nick'};
		my $count = $row->{'readmored'};

		return "${who} has been readmored the most (${count} times)";
	}

}

1;
