package StockQuote::Google;

use strict;
use warnings;

use HTTP::Request;
use LWP::UserAgent;
use Web::Query;

use constant {
	URL_FORMAT => 'http://www.google.com/finance?q=%s',
};

sub new
{
	my $class = shift;
	my ($symbol) = @_;

	my $self = {
		'symbol' => $symbol,
	};

	return bless $self, $class;
}

sub fetch
{
	my $self = shift;
	my ($symbol) = @_;

	if ($symbol) {
		$self->{'symbol'} = $symbol;
	} else {
		$symbol = $self->{'symbol'};
	}

	# Get Google Finance page
	my $url = sprintf(URL_FORMAT, $symbol);

	my $userAgent = LWP::UserAgent->new;
	$userAgent->agent(qq[Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.186 Safari/537.36]);
	$userAgent->timeout(10);

	my $request = HTTP::Request->new('GET', $url);

	my $response = $userAgent->request($request);

	if (!$response->is_success) {
		return undef;
	}

	my $query = Web::Query->new($response->content);

	my $symbolThing = $query->find('div._EGr')->first->text;
	if ($symbolThing !~ /^(.+?):\s*(.+?)\s*$/) {
		return undef;
	}
	my $canonicalSymbol = $2;

	my ($change, $pctChange) = split(/\s+/, $query->find('span._yHo')->first->text);

	my $price = $query->find('g-card-section._tSo div span')->first->text;
	$price =~ s/(.+?) USD/\$$1/;

	my $infoTable = $query->find('._qco table');
	my $miscInfo = { };
	$infoTable->find('tr')->each(sub {
		my ($i, $elem) = @_;
		my $name = $elem->find('td._Aeo')->first->text;
		my $value = $elem->find('td._Beo')->first->text;

		$miscInfo->{ $name } = $value;
	});

	my $info = {
		'symbol'    => $canonicalSymbol,
		'name'      => $query->find('div._FGr')->first->text,
		'price'     => $price,
		'change'    => $change,
		'pctChange' => $pctChange,
		'extra'     => $query->find('div._cHp')->first->text,
		'open'      => $miscInfo->{'Open'},
		'dayRange'  => "$miscInfo->{'Low'}-$miscInfo->{'High'}",
		'yearRange' => "$miscInfo->{'52-wk low'}-$miscInfo->{'52-wk high'}",
	};

	foreach my $key (keys %$info) {
		# Trim leading/trailing whitespace characters
		$info->{ $key } =~ s/^\s*//;
		$info->{ $key } =~ s/\s*$//;
		# Convert any remaining whitespace into single space characters
		$info->{ $key } =~ s/\s+/ /g;

		# Replace Unicode minus sign with ASCII hyphen
		$info->{ $key } =~ s/−/-/g;
	}

	return $info;
}

sub AUTOLOAD
{
	my $self = shift;

	my $name = our $AUTOLOAD;
	$name =~ s/.*:://;

	return if ($name =~ /^(DESTROY)$/);

	if ($name =~ /^_/ || !exists $self->{ $name }) {
		die "Invalid method '$name'";
	}

	return $self->{ $name };
}

1;
