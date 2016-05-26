package Data::Sah::Params;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(compile Slurpy Optional Named);

sub Optional($) {
    bless [$_[0]], "_Optional";
}

sub Slurpy($) {
    bless [$_[0]], "_Slurpy";
}

sub Named {
    @_ or die "Need at least one pair for Named";
    @_ % 2 == 0 or die "Odd number of elements for Named";
    bless {@_}, "_Named";
}

sub compile {
    my $opts = ref($_[0]) eq 'HASH' ? shift : {};
    die "Please specify some params" unless @_;

    # we currently use Perinci::Sub::ValidateArgs to generate the validator, so
    # we create rinci metadata from params specification.
    my $meta = {v=>1.1, args=>{}, result_naked=>1};
    if (ref($_[0]) eq '_Named') {
        die "Cannot mixed Named and other params" unless @_ == 1;
        $meta->{args_as} = 'hash';
        for my $arg_name (keys %{$_[0]}) {
            my $arg_schema = $_[0]{$arg_name};
            my $req = 1;
            while (1) {
                my $ref = ref($arg_schema);
                if ($ref eq '_Optional') {
                    $req = 0;
                    $arg_schema = $arg_schema->[0];
                    next;
                }
                if ($ref eq '_Slurpy') {
                    # noop
                    $arg_schema = $arg_schema->[0];
                    next;
                }
                last;
            }
            $meta->{args}{$arg_name} = {
                schema => $arg_schema,
                req => $req,
            };
        }
    } else {
        $meta->{args_as} = 'array';
        for my $pos (0..$#_) {
            my $arg_name = "arg$pos";
            my $arg_schema = $_[$pos];
            my $req = 1;
            my $slurpy;
            while (1) {
                my $ref = ref($arg_schema);
                if ($ref eq '_Named') {
                    die "Cannot mixed Named and other params";
                }
                if ($ref eq '_Optional') {
                    $req = 0;
                    $arg_schema = $arg_schema->[0];
                    next;
                }
                if ($ref eq '_Slurpy') {
                    die "Slurpy parameter must be the last parameter"
                        unless $pos == $#_;
                    $slurpy = 1;
                    $arg_schema = $arg_schema->[0];
                    next;
                }
                last;
            }
            $meta->{args}{$arg_name} = {
                schema => $arg_schema,
                req => $req,
                pos => $pos,
                (greedy => $slurpy) x !!$slurpy,
            };
        }
    }

    require Perinci::Sub::ValidateArgs;
    my $src = Perinci::Sub::ValidateArgs::gen_args_validator(
        meta=>$meta, source=>1, die=>1);

    # do some munging
    if ($meta->{args_as} eq 'hash') {
        $src =~ s/^(\s*my \$args = )shift;/${1}{\@_};/m
            or die "BUG: Can't replace #1a";
        $src =~ s/(\A.+^\s*return )undef;/${1}\$args;/ms
            or die "BUG: Can't replace #2a";
    } else {
        $src =~ s/^(\s*my \$args = )shift;/${1}[\@_];/m
            or die "BUG: Can't replace #1b";
        $src =~ s/(\A.+^\s*return )undef;/${1}\@\$args;/ms
            or die "BUG: Can't replace #2b";
    }
    return $src if $opts->{want_source};

    my $code = eval $src;
    #use Eval::Closure; my $code = eval_closure(source => $src);
    die if $@;
    $code;
}

1;
# ABSTRACT: Validate function arguments using Sah schemas

=for Pod::Coverage ^(Optional|Slurpy|Named)$

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


=head1 FUNCTIONS

=head2 compile($schema, ...) => coderef

Create a validator. Accepts a list of schemas. Each schema can be prefixed with
C<Optional> or C<Slurpy>. Or, if your function will accept named arguments
(C<%args>) you can use: C<< Named(PARAM1=>$schema1, PARAM2=>$schema2, ...) >>
instead.


=head1 SEE ALSO

L<Sah> for the schema language.

Similar modules: L<Type::Params>, L<Params::Validate>, L<Params::CheckCompiler>.

If you put your schemas in L<Rinci> function metadata (I recommend it, for the
convenience of specifying other stuffs besides argument schemas), take a look at
L<Perinci::Sub::ValidateArgs>.
