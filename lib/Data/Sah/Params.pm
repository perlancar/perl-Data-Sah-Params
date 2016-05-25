package Data::Sah::Params;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(compile Slurpy Optional Named);

sub Optional($) {
    bless [$_[0]], "Data::Sah::Params::_Optional";
}

sub Slurpy($) {
    bless [$_[0]], "Data::Sah::Params::_Slurpy";
}

sub Named {
    bless [$_[0]], "Data::Sah::Params::_Named";
}

sub compile {
}

1;
# ABSTRACT: Validate function arguments using Sah schemas

=head1 SYNOPSIS

 use Data::Sah::Params qw(compile Optional Slurpy Named);

 # positional parameters, some optional
 sub f1 {
     state $check = compile(
         ["str*"],
         ["int*", min=>1, max=>10, default=>5],
         Optional [array => of=>"int*"],
     );
     my ($foo, $bar, $baz) = $check->(@_);
     ...
 }
 f1();                # dies, missing required argument $foo
 f1(undef);           # dies, $foo must not be undef
 f1("a");             # dies, missing required argument $bar
 f1("a", undef);      # ok, $bar = 5, $baz = undef
 f1("a", 1);          # ok, $bar = 1, $baz = undef
 f1("a", "x");        # dies, $bar is not an int
 f1("a", 3, [1,2,3]); # ok

 # positional parameters, slurpy last parameter
 sub f2 {
     state $check = compile(
         ["str*"],
         ["int*", min=>1, max=>10, default=>5],
         Slurpy [array => of=>"int*"],
     );
     my ($foo, $bar, $baz) = $check->(@_);
     ...
 }
 f1("a", 3, 1,2,3);   # ok, $foo="a", $bar=3, $baz=[1,2,3]
 f1("a", 3, 1,2,"b"); # dies, third element of $baz not an integer

 # named parameters, some optional
 sub f3 {
     state $check = compile(Named
         foo => ["str*"],
         bar => ["int*", min=>1, max=>10, default=>5],
         baz => Optional [array => of=>"int*"],
     );
     my $args = $check->(@_);
     ...
 }
 f1(foo => "a");                 # dies, missing argument 'bar'
 f1(foo => "a", bar=>1);         # ok
 f1(foo => "a", bar=>1, baz=>2); # dies, baz not an array


=head1 DESCRIPTION

Experimental.

Currently mixing positional and named parameters not yet supported.


=head1 SEE ALSO

L<Sah> for the schema language.

Similar modules: L<Type::Params>, L<Params::Validate>, L<Params::CheckCompiler>.

If you put your schemas in L<Rinci> function metadata (I recommend it), take a
look at L<Perinci::Sub::ValidateArgs>.
