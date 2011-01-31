package Gadwall::Table;

use strict;
use warnings;

use base 'Gadwall::Controller';

# These functions (are Mojolicious "actions" that) act on the table and
# return a suitable JSON response. They validate parameters, but do not
# know anything about users and authorization.
#
# list() returns rows matching a query. create() takes a set of values
# and creates a new row. update() takes a set of values and updates one
# row identified by its id. delete() takes an id and deletes the row.
# The row id must be a stash value rather than a parameter; it can be
# set by the router as follows:
#
# $r->route('/widgets/:widget_id/delete')->to('widgets#delete')

sub list {
    my $self = shift;
    return $self->render(
        json => {
            rows => [
                map { $_->display_hash } @{
                    $self->select($self->rows)
                }
            ]
        }
    );
}

sub create {
    my $self = shift;

    my %set = $self->column_values(all => 1);
    unless (%set && $self->_create(%set)) {
        return $self->json_error;
    }

    return $self->json_ok($self->message('created'));
}

sub update {
    my $self = shift;

    my $id = $self->stash($self->primary_key);
    my %set = $self->column_values();
    unless ($id && %set && $self->_update($id, %set)) {
        return $self->json_error;
    }

    return $self->json_ok($self->message('updated'));
}

sub delete {
    my $self = shift;

    my $id = $self->stash($self->primary_key);
    unless ($id && $self->_delete($id)) {
        return $self->json_error;
    }

    return $self->json_ok($self->message('deleted'));
}

# This function must generate a SELECT query to retrieve rows based on
# the request parameters. It must return a query string and a list of
# bind values. The default version knows how to retrieve all rows, an
# individual row identified by primary key value. rows() then applies
# ORDER BY and LIMIT/OFFSET clauses to this query.

sub query {
    my $self = shift;
    my $query = "select * from " . $self->table_name;

    my @values;
    if (my $id = $self->param('id')) {
        $query .= " where ". $self->primary_key ."=?";
        push @values, $id;
    }

    return ($query, @values);
}

sub rows {
    my $self = shift;

    my ($query, @values) = $self->query(@_);

    if (my $o = $self->order) {
        $query .= " ORDER BY $o";
    }

    if (my $n = $self->limit) {
        $query .= " LIMIT $n";
        if (my $o = $self->param('start')) {
            $query .= " OFFSET $o";
        }
    }

    return ($query, @values);
}

sub order { shift->primary_key ." DESC" }
sub limit {}

# This function takes a query string and an array of bind parameters and
# executes the query, returning the results as a reference to an array
# of hashrefs, each representing a single row with named columns. If a
# subclass defines a rowclass(), each row is blessed into this class.

sub select {
    my $self = shift;
    my $rows = $self->app->db->selectall_arrayref(
        shift, { Slice => {} }, @_
    );

    my $class = $self->rowclass;
    if ($class) {
        $rows = [ map { bless $_, $class } @$rows ];
    }

    return $rows;
}

sub rowclass {}

# This function fetches a single row by its primary key. If the subclass
# has defined cache_rows to be true, the selected row is memcached under
# "table/key/value", and future requests will return the cached row.
# Rows are blessed into rowclass() as usual.

sub select_by_key {
    my ($self, $id) = @_;

    my $row = $self->_cache_get($id);
    unless ($row) {
        my $table = $self->table_name;
        my $key = $self->primary_key;

        $row = $self->app->db->selectrow_hashref(
            "select * from $table where $key=?", {}, $id
        );

        $self->_cache_set($id, $row) if $row;
    }

    my $class = $self->rowclass;
    if ($row && $class) {
        $row = bless $row, $class;
    }
    return $row;
}

sub cache_rows { 0 }

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

# These functions can be overriden by subclasses that want to do
# something other than the default INSERT/UPDATE/DELETE queries
# (e.g. use an SQL function, or a transaction).

sub _create {
    my ($self, %set) = @_;

    my $table = $self->table_name;
    my $fields = join ",", keys %set;
    my $values = join ",", map { "?" } keys %set;
    my @values = values %set;

    my $dbh = $self->app->db;
    my $rv = $dbh->do(
        "insert into $table ($fields) values ($values)", {}, @values
    );
    unless ($rv) {
        $self->stash(error => $dbh->errstr);
    }
    return $rv;
}

sub _update {
    my ($self, $id, %set) = @_;

    my $dbh = $self->app->db;
    my $table = $self->table_name;
    my $key = $self->primary_key;
    my $fields = join ",", map { "$_=?" } keys %set;
    my @values = values %set;

    $self->_cache_delete($id);
    my $rv = $dbh->do(
        "update $table set $fields where $key=?", {}, @values, $id
    );
    unless ($rv) {
        $self->stash(error => $dbh->errstr);
    }
    return $rv;
}

sub _delete {
    my ($self, $id) = @_;

    my $dbh = $self->app->db;
    my $table = $self->table_name;
    my $key = $self->primary_key;

    $self->_cache_delete($id);
    my $rv = $dbh->do("delete from $table where $key=?", {}, $id);
    unless ($rv) {
        $self->stash(error => $dbh->errstr);
    }
    return $rv;
}

# Low-level cache access functions: get, set, delete
#
# These functions act only if a cache is configured and the subclass has
# defined cache_rows to be true. Otherwise they act as if the cache were
# a bottomless pit.

sub _cache_get {
    my ($self, $id) = @_;

    if ($self->cache_rows) {
        return $self->app->cache->get(
            join("/", $self->table_name, $self->primary_key, $id)
        );
    }
    return undef;
}

sub _cache_set {
    my ($self, $id, $row) = @_;

    if ($self->cache_rows) {
        $self->app->cache->set(
            join("/", $self->table_name, $self->primary_key, $id), $row
        );
    }
}

sub _cache_delete {
    my ($self, $id) = @_;

    if ($self->cache_rows) {
        $self->app->cache->delete(
            join("/", $self->table_name, $self->primary_key, $id)
        );
    }
}

# By default, entities of type Foo are represented by a subclass named
# Foos and stored in a table named foos with serial primary key foo_id.
# Any of these defaults may be overriden for individual subclasses.

sub table_name {
    (my $name = lc(ref shift)) =~ s/^.*:://;
    return $name;
}

sub primary_key {
    (my $name = shift->table_name) =~ s/s$/_id/;
    return $name;
}

sub singular {
    (my $name = ucfirst(shift->table_name)) =~ s/s$//;
    return $name;
}

# Generic success and failure messages, can be overriden.

sub messages {
    my $self = shift;
    my $singular = $self->singular;

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
