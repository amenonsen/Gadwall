package Gadwall::Db::Table;

use strict;
use warnings;

# Takes a db handle and a class name and returns an object of the
# relevant Db subclass to handle it.

sub new_table {
    my $t = shift;
    my $c = ref $t ? $t->controller() : shift;
    my $n = shift;

    my $class = $c->class_name("Db::$n");

    return bless sub { $c }, $class;
}

# An object of any Gadwall::Db::Table subclass is a blessed reference to
# a closure that returns the controller the object was created with (by
# the new_table method above). These helper functions hide the slightly
# odd calling convention.

sub controller { shift->() }
sub dbh { shift->controller->db() }
sub stash { shift->controller->stash(@_) }
sub param { shift->controller->param(@_) }
sub cache { shift->controller->app->cache() }

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

# This function returns a query string and a list of bind values based
# on the request parameters. By default, it assembles a query to fetch
# all columns from the represented table. If an id is given, the query
# fetches only the matching row; otherwise, it fetches everything. Any
# or all of these decisions may be overriden by subclasses.

sub query {
    my $self = shift;

    my $query =
        "select ". join(",", $self->query_columns).
        " from ". $self->query_tables;

    my ($where, @values) = $self->query_conditions(@_);
    if ($where) {
        $query .= " where $where";
    }

    return ($query, @values);
}

sub query_columns { qw(*) }

sub query_tables { shift->table_name }

sub query_conditions {
    my $self = shift;
    my $key = $self->primary_key;

    # We can be called in any of four different ways. With no arguments,
    # we use the primary key value from the request parameters, if any.
    # A single argument may be either a primary key value, or a hashref
    # of column names and values to be ANDed together to form the WHERE
    # clause. To accommodate more complicated queries, we also accept a
    # string and a list of bind values and pass them through unchanged.

    if (@_ > 1) {
        return @_;
    }
    elsif (@_ == 1 && ref $_[0] eq 'HASH') {
        my %columns = %{+shift};
        return (
            join(" AND ", map { "$_=?" } keys %columns),
            values %columns
        );
    }
    elsif (@_ == 1) {
        return ("$key=?", shift);
    }
    elsif (my $id = $self->param($key)) {
        return ("$key=?", $id);
    }

    return;
}

# This function applies ORDER BY and LIMIT/OFFSET clauses to the query
# returned by query(). The resulting query returns one page of results
# (or all results, if pages weren't requested).

sub query_page {
    my $self = shift;

    my ($query, @values) = $self->query(@_);

    if (my $o = $self->order) {
        $query .= " ORDER BY $o";
    }

    if (my $n = $self->limit) {
        $query .= " LIMIT $n";
        if ((my $p = $self->page) > 1) {
            $query .= " OFFSET " . ($p-1)*$n;
        }
    }

    return ($query, @values);
}

sub order { shift->primary_key ." DESC" }
sub limit { int(shift->param('n') || 0) }
sub page { int(shift->param('p') || 1) }

# This function returns the number of rows that would be matched by a
# given query. If anything goes wrong, it returns undef. This is a bit
# of a hack.

sub count_rows {
    my $self = shift;

    my $q = "select count(*) from ". $self->query_tables;
    my ($where, @v) = $self->query_conditions(@_);
    if ($where) {
        $q .= " where $where";
    }

    my $row = $self->dbh->selectrow_arrayref($q, {}, @v);
    return $row && $row->[0];
}

# This function takes a query string and an array of bind parameters and
# executes the query, returning the results as a reference to an array
# of hashrefs, each representing a single row with named columns. Each
# row is blessed into the class name returned by rowclass(), if any.

sub select {
    my $self = shift;
    my $rows = $self->dbh->selectall_arrayref(
        shift, { Slice => {} }, @_
    );

    my $class = $self->rowclass;
    if ($rows && $class) {
        $rows = [ map { bless $_, $class } @$rows ];
    }

    return $rows;
}

# This is just a convenience. It passes its arguments to query(), and
# returns a single row as a (blessed) hashref directly, rather than
# wrapping it in an array.

sub select_one {
    my $self = shift;
    my ($q, @v) = $self->query(@_);
    my $row = $self->dbh->selectrow_hashref(
        $q, {}, @v
    );

    my $class = $self->rowclass;
    if ($row && $class) {
        $row = bless $row, $class;
    }

    return $row;
}

# This function fetches a single row by its primary key. If the subclass
# has defined cache_rows to be true, the selected row is memcached under
# "table/key/value", and future requests will return the cached row.
# Rows are blessed into rowclass() as usual.

sub select_by_key {
    my ($self, $id) = @_;

    my $row = $self->_cache_get($id);
    unless ($row) {
        my ($q, @v) = $self->query($id);
        $row = $self->dbh->selectrow_hashref(
            $q, {}, @v
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

# Two convenient ways to fetch results: as an arrayref of blessed rows
# and as an arrayref of unblessed rows for display (plus a utility
# function to convert one to the other).

sub rows {
    my $self = shift;
    return $self->select($self->query_page(@_));
}

sub display_rows {
    my $self = shift;
    return $self->for_display($self->rows(@_));
}

sub for_display {
    my ($self, $rows) = @_;

    return $rows && [
        map { ref eq 'HASH' ? $_ : $_->display_hash } @$rows
    ];
}

# This function must return the name of a package into which rows from
# the database are blessed. By default, it looks for a package with the
# singular form of the table's name.

sub rowclass {
    my $self = shift;
    return $self->controller->class_name($self->singular);
}

# This function is meant to return a user-friendly version of the given
# db error message. By default, it just passes the error through. It's
# up to subclasses to change that.

sub db_error {
    my $self = shift;
    return shift;
}

# This function wraps a transaction around a create/update/delete
# operation, which is performed by the relevant _method using the
# supplied arguments.

sub transaction {
    my $self = shift;
    my $dbh = $self->dbh;
    my $op = "_" . shift;
    my $rv;

    $dbh->begin_work;
    eval {
        local $dbh->{RaiseError} = 1;
        $rv = $self->$op(@_);
        $dbh->commit;
    };
    if ($@) {
        $self->stash(error => $self->db_error($@));
        eval { $dbh->rollback };
    }

    return $rv;
}

# These functions can be overriden by subclasses that want to do
# something other than the default INSERT/UPDATE/DELETE queries
# (e.g. use an SQL function). They're run inside an eval {}, so
# if anything goes wrong they can just die().

sub _create {
    my ($self, %set) = @_;

    my $table = $self->table_name;
    my $fields = join ",", keys %set;
    my $values = join ",", map { "?" } keys %set;
    my @values = values %set;

    return $self->dbh->do(
        "insert into $table ($fields) values ($values)", {}, @values
    );
}

sub _update {
    my ($self, $id, %set) = @_;

    my $table = $self->table_name;
    my $key = $self->primary_key;
    my $fields = join ",", map { "$_=?" } keys %set;
    my @values = values %set;

    $self->_cache_delete($id);
    return $self->dbh->do(
        "update $table set $fields where $key=?", {}, @values, $id
    );
}

sub _delete {
    my ($self, $id) = @_;

    my $table = $self->table_name;
    my $key = $self->primary_key;

    $self->_cache_delete($id);
    return $self->dbh->do(
        "delete from $table where $key=?", {}, $id
    );
}

# Low-level cache access functions: get, set, delete
#
# These functions act only if a cache is configured and the subclass has
# defined cache_rows to be true. Otherwise they act as if the cache were
# a bottomless pit.

sub _cache_get {
    my ($self, $id) = @_;

    if ($self->cache_rows) {
        return $self->cache->get(
            join("/", $self->table_name, $self->primary_key, $id)
        );
    }
    return undef;
}

sub _cache_set {
    my ($self, $id, $row) = @_;

    if ($self->cache_rows) {
        $self->cache->set(
            join("/", $self->table_name, $self->primary_key, $id), $row
        );
    }
}

sub _cache_delete {
    my ($self, $id) = @_;

    if ($self->cache_rows) {
        $self->cache->delete(
            join("/", $self->table_name, $self->primary_key, $id)
        );
    }
}

1;
