package Gadwall::Db::Users;

use Mojo::Base 'Gadwall::Db::Table';

sub query_columns {(
    "*",

    "roles::int",

    "to_char(last_login, 'yyyy-mm-dd hh:mm:ss') as last_login",
    "to_char(second_last_login, 'yyyy-mm-dd hh:mm:ss') as second_last_login",
    "to_char(last_failed_login, 'yyyy-mm-dd hh:mm:ss') as last_failed_login",

    "current_timestamp - coalesce(last_password_change,".
    " current_timestamp-(round(random()*35)::text||' days')::interval) > ".
    "'30 days'::interval as password_expired"
)}

sub _passwd {
    my ($self, $id, %set) = @_;

    return $self->dbh->do(
        "update users set password=?, ".
        "last_password_change=current_timestamp ".
        "where user_id=?", {}, $set{password}, $id
    );
}

1;
