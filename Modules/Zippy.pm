package Modules::Zippy;

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

	&Modules::register_action('yow', \&Modules::Zippy::zippy);
	&Modules::register_help('yow', \&Modules::Zippy::help);
}

sub zippy($)
{
	my $message = shift;

	open(ZIPPY, "/usr/games/fortune zippy |");
	my $yow;
	while (<ZIPPY>) {
		$yow .= $_;
	}
	close(ZIPPY);
	$yow =~ s/\n/ /g;

	return $yow;	
}

sub help($)
{
	my $message = shift;

	return "yow: prints a random Zippy the Pinhead message";
}

1;
