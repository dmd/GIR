package Modules::Convert;

#######
## PERL SETUP
#######
use strict;

use Graph;

my %aliases;

my $match_expr = qr/^\s*convert\s+(\d*(\.\d+)?)\s*(.+)\s+to\s+(.+)\s*$/;

my $conversions = {
	# Distance conversions
	'au' => {
		'km' => \&astronomical_units_to_kilometers,
	},
	'cm' => {
		'in' => \&centimeters_to_inches,
		'm'  => \&centimeters_to_meters,
		'mm' => \&centimeters_to_millimeters,
	},
	'ft' => {
		'in' => \&feet_to_inches,
		'mi' => \&feet_to_miles,
		'yd' => \&feet_to_yards,
	},
	'in' => {
		'cm' => \&inches_to_centimeters,
		'ft' => \&inches_to_feet,
	},
	'km' => {
		'au' => \&kilometers_to_astronomical_units,
		'ly' => \&kilometers_to_light_years,
		'm'  => \&kilometers_to_meters,
	},
	'ls' => {
		'ly' => \&light_seconds_to_light_years,
	},
	'ly' => {
		'ls' => \&light_years_to_light_seconds,
		'km' => \&light_years_to_kilometers,
		'pc' => \&light_years_to_parsecs,
	},
	'm'  => {
		'cm' => \&meters_to_centimeters,
		'km' => \&meters_to_kilometers,
	},
	'mi' => {
		'ft' => \&miles_to_feet,
		'nm' => \&miles_to_nautical_miles,
	},
	'mm' => {
		'cm' => \&millimeters_to_centimeters,
	},
	'nm' => {
		'mi' => \&nautical_miles_to_miles,
	},
	'pc' => {
		'ly' => \&parsecs_to_light_years,
	},
	'yd' => {
		'ft' => \&yards_to_feet,
	},

	# Temperature conversions
	'c' => {
		'f' => \&celcius_to_fahrenheit,
		'k' => \&celcius_to_kelvin,
	},
	'f' => {
		'c' => \&fahrenheit_to_celcius,
	},
	'k' => {
		'c' => \&kelvin_to_celcius,
	},

	# Time conversions
	'hr'  => {
		'min' => \&hours_to_minutes,
	},
	'min' => {
		'hr'  => \&minutes_to_hours,
		's'   => \&minutes_to_seconds,
	},
	's'   => {
		'min' => \&seconds_to_minutes,
	},

	# Weight/mass conversions
	'g' => {
		'kg' => \&grams_to_kilograms,
	},
	'kg' => {
		'lb' => \&kilograms_to_pounds,
		'g'  => \&kilograms_to_grams,
	},
	'lb' => {
		'kg' => \&pounds_to_kilograms,
		'oz' => \&pounds_to_ounces,
	},
	'oz' => {
		'lb' => \&ounces_to_pounds,
	},
};

##############
sub new()
{
	my $pkg = shift;
	my $obj = {	};
	bless $obj, $pkg;
	return $obj;
}

sub register()
{
	my $this = shift;

	# Initialize conversions
	%aliases = (
		'celcius'       => 'c',
		'centigrade'    => 'c',
		'centimeter'    => 'cm',
		'centimeters'   => 'cm',
		'centimetre'    => 'cm',
		'centimetres'   => 'cm',
		'fahrenheit'    => 'f',
		'feet'          => 'ft',
		'foot'          => 'ft',
		'fps'           => 'ft/s',
		'gram'          => 'g',
		'grams'         => 'g',
		'hour'          => 'hr',
		'hours'         => 'hr',
		'inch'          => 'in',
		'inches'        => 'in',
		'kelvin'        => 'k',
		'kilogram'      => 'kg',
		'kilograms'     => 'kg',
		'kilometer'     => 'km',
		'kilometers'    => 'km',
		'kilometre'     => 'km',
		'kilometres'    => 'km',
		'kph'           => 'km/hr',
		'light-second'  => 'ls',
		'light second'  => 'ls',
		'light-seconds' => 'ls',
		'light seconds' => 'ls',
		'light-year'    => 'ly',
		'light year'    => 'ly',
		'light-years'   => 'ly',
		'light years'   => 'ly',
		'meter'         => 'm',
		'meters'        => 'm',
		'metre'         => 'm',
		'metres'        => 'm',
		'mile'          => 'mi',
		'miles'         => 'mi',
		'minute'        => 'min',
		'minutes'       => 'min',
		'mph'           => 'mi/hr',
		'ounce'         => 'oz',
		'ounces'        => 'oz',
		'parsec'        => 'pc',
		'parsecs'       => 'pc',
		'pound'         => 'lb',
		'pounds'        => 'lb',
		'second'        => 's',
		'seconds'       => 's',
		'sm'            => 'mi',
		'ua'            => 'au',
		'yard'          => 'yd',
		'yards'         => 'yd'
	);

	Modules::register_action($match_expr, \&Modules::Convert::process);
}

sub process($)
{
	my $message = shift;

	if ($message->message() =~ $match_expr) {
		my $value    = $1;
		my $fromUnit = lc($3);
		my $toUnit   = lc($4);

		my $converted;

		if ($fromUnit =~ m|/|) {
			# compound unit
			my ($fromPer, $toPer);
			($fromUnit, $fromPer) = split(/\//, $fromUnit, 2);
			($toUnit,   $toPer)   = split(/\//, $toUnit,   2);

			$fromUnit = $aliases{ $fromUnit } || $fromUnit;
			$toUnit   = $aliases{ $toUnit }   || $toUnit;
			$fromPer  = $aliases{ $fromPer }  || $fromPer;
			$toPer    = $aliases{ $toPer }    || $toPer;

			if ($fromUnit eq $toUnit) {
				# same unit in numerator
				# switch the direction of the conversion to account for the fact that now we're converting from the denominator
				$converted = _convert($value, $toPer, $fromPer);
			} elsif ($fromPer eq $toPer) {
				# same unit in denominator
				$converted = _convert($value, $fromUnit, $toUnit);
			} else {
				# different units in numerator and denominator
				$converted = _convert(_convert($value, $fromUnit, $toUnit), $toPer, $fromPer);
			}

			# reassemble $fromUnit and $toUnit into complex unit for display
			$fromUnit = sprintf('%s/%s', $fromUnit, $fromPer);
			$toUnit   = sprintf('%s/%s', $toUnit,   $toPer);

		} else {
			$fromUnit = $aliases{ $fromUnit } || $fromUnit;
			$toUnit   = $aliases{ $toUnit }   || $toUnit;

			$converted = _convert($value, $fromUnit, $toUnit);
		}

		if (defined $converted) {
			return sprintf('%s %s is %s %s', $value, $fromUnit, $converted, $toUnit);
		} else {
			return sprintf("Can't convert between '%s' and '%s'!", $fromUnit, $toUnit);
		}
	}
}

sub _convert($$$)
{
	my ($value, $fromUnit, $toUnit) = @_;

	my $graph = _buildGraph();

	my @path = $graph->SP_Dijkstra($fromUnit, $toUnit);

	my $converted;
	if (scalar(@path) == 1) {
		$converted = $value;
	} elsif (scalar(@path) > 1) {
		$converted = $value;

		my $from = $path[0];
		foreach my $i (1..$#path) {
			my $to = $path[$i];

			$converted = $conversions->{ $from }->{ $to }->($converted);

			$from = $to;
		}
	}

	return $converted;
}

sub _buildGraph()
{
	my $graph = new Graph();

	foreach my $from (keys %$conversions) {
		foreach my $to (keys %{ $conversions->{ $from } }) {
			$graph->add_edge($from, $to);
		}
	}

	return $graph;
}

##############
## TEMPERATURE CONVERSION FUNCTIONS
##############
sub celcius_to_fahrenheit($)
{
	my ($celcius) = @_;

	return ((9.0 * $celcius) / 5.0) + 32;
}

sub celcius_to_kelvin($)
{
	my ($celcius) = @_;

	return $celcius + 273.15;
}

sub fahrenheit_to_celcius($)
{
	my ($fahrenheit) = @_;

	return (5.0 * ($fahrenheit - 32)) / 9.0;
}

sub kelvin_to_celcius($)
{
	my ($kelvin) = @_;

	return $kelvin - 273.15;
}

##############
## DISTANCE CONVERSION FUNCTIONS
##############

sub astronomical_units_to_kilometers($)
{
	my ($au) = @_;

	return $au * 149_597_870.7;
}

sub centimeters_to_inches($)
{
	my ($centimeters) = @_;

	return $centimeters * 0.393700787;
}

sub centimeters_to_meters($)
{
	my ($centimeters) = @_;

	return $centimeters / 100.0;
}

sub centimeters_to_millimeters($)
{
	my ($centimeters) = @_;

	return $centimeters * 10;
}

sub feet_to_inches($)
{
	my ($feet) = @_;

	return $feet * 12;
}

sub feet_to_miles($)
{
	my ($feet) = @_;

	return $feet / 5280;
}

sub feet_to_yards($)
{
	my ($feet) = @_;

	return $feet / 3;
}

sub inches_to_centimeters($)
{
	my ($inches) = @_;

	return $inches / 0.393700787;
}

sub inches_to_feet($)
{
	my ($inches) = @_;

	return $inches / 12.0;
}

sub kilometers_to_astronomical_units($)
{
	my ($kilometers) = @_;

	return $kilometers / 149_597_870.7;
}

sub kilometers_to_light_years($)
{
	my ($kilometers) = @_;

	return $kilometers / 9_460_730_472_580.8;
}

sub kilometers_to_meters($)
{
	my ($kilometers) = @_;

	return $kilometers * 1000;
}

sub light_seconds_to_light_years($)
{
	my ($lightSeconds) = @_;

	return $lightSeconds / 31_557_600.0;
}

sub light_years_to_light_seconds($)
{
	my ($lightYears) = @_;

	return $lightYears * 31_557_600;
}

sub light_years_to_kilometers($)
{
	my ($lightYears) = @_;

	return $lightYears * 9_460_730_472_580.8;
}

sub light_years_to_parsecs($)
{
	my ($lightYears) = @_;

	return $lightYears / 3.26156;
}

sub meters_to_centimeters($)
{
	my ($meters) = @_;

	return $meters * 100.0;
}

sub meters_to_kilometers($)
{
	my ($meters) = @_;

	return $meters / 1000.0;
}

sub miles_to_feet($)
{
	my ($miles) = @_;

	return $miles * 5280;
}

sub miles_to_nautical_miles($)
{
	my ($miles) = @_;

	return $miles * 0.868976242;
}

sub millimeters_to_centimeters()
{
	my ($millimeters) = @_;

	return $millimeters / 10.0;
}

sub nautical_miles_to_miles($)
{
	my ($nauticalMiles) = @_;

	return $nauticalMiles / 0.868976242;
}

sub parsecs_to_light_years($)
{
	my ($parsecs) = @_;

	return $parsecs * 3.26156;
}

sub yards_to_feet($)
{
	my ($yards) = @_;

	return $yards * 3;
}

##############
## TIME CONVERSION FUNCTIONS
##############
sub hours_to_minutes($)
{
	my ($hours) = @_;

	return $hours * 60;
}

sub minutes_to_hours($)
{
	my ($minutes) = @_;

	return $minutes / 60.0;
}

sub minutes_to_seconds($)
{
	my ($minutes) = @_;

	return $minutes * 60;
}

sub seconds_to_minutes($)
{
	my ($seconds) = @_;

	return $seconds / 60.0;
}

##############
## WEIGHT/MASS CONVERSION FUNCTIONS
##
## Assume standard earth gravity (9.8m/s^2)
## when converting between mass and weight.
##############

sub grams_to_kilgrams($)
{
	my ($grams) = @_;

	return $grams / 1000.0;
}

sub kilograms_to_grams($)
{
	my ($kilograms) = @_;

	return $kilograms * 1000.0;
}

sub kilograms_to_pounds($)
{
	my ($kilograms) = @_;

	return $kilograms * 2.20462262;
}

sub ounces_to_pounds($)
{
	my ($ounces) = @_;

	return $ounces / 16.0;
}

sub pounds_to_kilograms($)
{
	my ($pounds) = @_;

	return $pounds / 2.20462262;
}

sub pounds_to_ounces($)
{
	my ($pounds) = @_;

	return $pounds * 16.0;
}

1;
