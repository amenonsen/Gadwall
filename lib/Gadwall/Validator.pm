package Gadwall::Validator;

use strict;
use warnings;

# This function takes a column specification as a hashref and creates a
# new validator.

sub new {
    my $class = shift;
    return bless {
        columns => shift || {}, errors => {}, values => {}
    }, $class;
}

# This function takes a set of values and validates them according to
# the column specification given above. If it returns 'ok', values()
# returns a hash of column names and values. Otherwise errors() will
# return a hashref of column names and errors.

sub validate {
    my ($self, $values, %opts) = @_;

    my %known = %{$self->{columns}};
    my %given = %$values;
    my $status;

    # Start by removing undefined or empty parameter values.

    foreach my $k (keys %given) {
        my $v = $given{$k};
        my @v =
            grep { $_ ne "" }
                map { s/^\s+//; s/\s+$//; $_ }
                    grep { defined }
                        (ref $v eq 'ARRAY' ? @$v : $v);
        if (@v) {
            $given{$k} = @v == 1 ? $v[0] : [@v];
        }
        else {
            delete $given{$k};
        }
    }

    # Validate values of known columns against their specification.

    COLUMN:
    foreach my $c (keys %known) {
        my $col = $known{$c};

        my $missing = $col->{missing} || "$c is required";
        my $invalid = $col->{invalid} || "$c is invalid";
        my $required = $opts{all} && $col->{required};

        # By default, a column name corresponds to an eponymous form
        # parameter, but multiple fields may be specified either as an
        # array or a pattern that matches parameter names. It's an error
        # to specify an empty set of fields.

        my @fields = ($c);

        my $f = $col->{fields};
        if (ref $f) {
            if (ref $f eq 'ARRAY') {
                @fields = @$f;
            }
            elsif (ref $f eq 'Regexp') {
                @fields = grep { m/$f/ } keys %given;
                if ($required && !@fields) {
                    $self->{errors}->{$c} = $missing;
                    $status ||= 'missing';
                    next COLUMN;
                }
            }
        }

        unless (@fields) {
            $self->{errors}->{$c} = "Invalid field specification (#A)";
            $status = 'invalid';
            next COLUMN;
        }

        # If (we're checking that) this column is required, we have to
        # make sure that all given fields have values.

        if ($required && grep {!exists $given{$_}} @fields) {
            $self->{errors}->{$c} = $missing;
            $status ||= 'missing';
            next COLUMN;
        }

        # We won't accept multiple values unless they're expected.

        if (grep {ref $given{$_} eq 'ARRAY'} @fields && !$col->{multiple}) {
            $self->{errors}->{$c} = $invalid;
            $status = 'invalid';
            next COLUMN;
        }

        # Finally, we validate the supplied value(s).
        #
        # The validator may be a callback, in which case it can accept
        # any combination of arguments and do anything it wants; if it
        # is happy, it can return a hash of column names and values.

        my $V = $col->{validate};

        if (ref $V eq 'CODE') {
            my %set = $V->(map {($_ => $given{$_})} @fields);
            unless (%set) {
                $self->{errors}->{$c} = $invalid;
                $status = 'invalid';
                next COLUMN;
            }
            @{$self->{values}}{keys %set} = values %set;
            next COLUMN;
        }

        # Otherwise the validator may be a regex (which all the given
        # values must match), or nothing at all. In these cases, we do
        # the best we can to reduce the fields to a scalar value or an
        # arrayref. If that isn't possible, it's an error.

        my $value;

        if (!$col->{multiple}) {
            $value = [ @given{@fields} ]; # now an array of scalars
        }
        elsif (@fields == 1) {
            $value = @given{@fields}; # either a scalar or an array
            $value = [ $value ] unless ref $value;
        }
        else {
            $self->{errors}->{$c} = "Invalid field specification (#B)";
            $status = 'invalid';
            next COLUMN;
        }

        # If a column has multiple fields but is not required, the
        # slices above will give us undefs if any of the fields are
        # missing. If we end up with no value, we ignore the column.

        $value = [grep defined, @$value];
        $value = shift @$value unless @$value > 1;
        next COLUMN unless $value;

        if (ref $V eq 'Regexp') {
            if (grep !m/$V/, map {ref $_ eq 'ARRAY' ? @$_ : $_} $value) {
                $self->{errors}->{$c} = $invalid;
                $status = 'invalid';
                next COLUMN;
            }
        }
        elsif ($V) {
            $self->{errors}->{$c} = "Invalid field specification (#C)";
            $status = 'invalid';
            next COLUMN;
        }

        $self->{values}->{$c} = $value;
    }

    unless (%{$self->{errors}} || %{$self->{values}}) {
        $status = 'none';
    }

    if (%{$self->{values}} && !%{$self->{errors}}) {
        $status = 'ok';
    }

    return $status;
}

sub errors {
    return shift->{errors};
}

sub values {
    return %{shift->{values}};
}

1;
