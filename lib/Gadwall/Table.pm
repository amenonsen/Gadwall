package Gadwall::Table;

use Mojo::Base 'Gadwall::Controller';

use Gadwall::Validator;

# These functions (are Mojolicious "actions" that) act on the table and
# return a suitable JSON response. They validate parameters, but do not
# know anything about users and authorization.
#
# create() takes a set of values and creates a new row. update() takes a
# set of values and updates one row identified by its id. delete() takes
# an id and deletes the row. The row id must be in the stash rather than
# a parameter; it can be set by the router as follows:
#
# $r->route('/widgets/:widget_id/delete')->to('widgets#delete')

sub create {
    my $self = shift;

    my $table = $self->table;
    my %set = $self->column_values(all => 1);
    unless (%set && $table->transaction(create => %set)) {
        return $self->json_error;
    }

    $self->after_create() if $self->can('after_create');
    return $self->json_ok($self->message('created'));
}

sub update {
    my $self = shift;

    my $table = $self->table;
    my $id = $self->stash($table->primary_key);
    my %set = $self->column_values();
    unless ($id && %set && $table->transaction(update => $id, %set)) {
        return $self->json_error;
    }

    $self->after_update() if $self->can('after_update');
    return $self->json_ok($self->message('updated'));
}

sub delete {
    my $self = shift;

    my $table = $self->table;
    my $id = $self->stash($table->primary_key);
    unless ($id && $table->transaction(delete => $id)) {
        return $self->json_error;
    }

    $self->after_delete() if $self->can('after_delete');
    return $self->json_ok($self->message('deleted'));
}

# This action returns a JSON response containing rows of data from the
# table which match a(n optional) search expression. A lot of work goes
# on behind the scenes to produce the response. First, query() assembles
# a query based on the request parameters and the columns and conditions
# defined by the subclass. Then select() executes the query and returns
# a list of rows, which are then formatted for display and incorporated
# into the response. Somewhere along the way, we also have to fetch and
# return the total number of rows, to help the client paginate the list.

sub list {
    my $self = shift;
    $self->render_text(
        $self->list_json, format => 'json'
    );
}

sub list_json {
    my $self = shift;

    my $table = $self->table;
    my $name = $table->table_name;

    my $res = {
        table => {
            name => $name,
            key => $table->primary_key,
            page => $table->page,
            limit => $table->limit,
        }
    };

    if (my $rows = $table->rows(@_)) {
        $res->{status} = "ok";
        $res->{$name} = $table->for_display($rows);
        $res->{table}{total} = $table->count_rows(@_);
    }
    else {
        $res = {
            status => "error",
            message => $self->db->errstr || "Unknown error"
        };
    }

    return $self->render(json => $res, partial => 1);
}

# Subclasses should return a hash of column names and specifications
# from columns(), which can be used to validate request parameters.

sub columns {
    return ();
}

sub column_values {
    my ($self, %opts) = @_;

    return $self->_validate(
        { $self->columns }, $self->req->params->to_hash, %opts
    );
}

sub _validate {
    my ($self, $columns, $values, %opts) = @_;

    my $v = Gadwall::Validator->new($columns);
    my $r = $v->validate($values, %opts);
    unless ($r eq 'ok') {
        $self->stash(error => {
            message => $self->message($r),
            errors => $v->errors
        });
        return ();
    }

    return $v->values;
}

# Generic success and failure messages, can be overriden.

sub messages {
    my $self = shift;
    my $singular = $self->table->singular;

    return (
        $self->SUPER::messages,
        created => "$singular created",
        updated => "$singular updated",
        deleted => "$singular deleted",
        missing => "Please supply all required values",
        invalid => "Please correct the following errors",
        none => "No validated column values available"
    );
}

# A shortcut to import named patterns for validation.

sub valid {
    my $self = shift;

    return Gadwall::Validator->patterns(@_);
}

1;
