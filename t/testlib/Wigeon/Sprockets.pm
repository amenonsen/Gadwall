package Wigeon::Sprockets;

use Mojo::Base 'Gadwall::Table';

sub cache_rows { 1 }

sub columns {
    my $self = shift;
    return (
        sprocket_name => {
            required => 1,
            validate => qr/^[a-z]+$/
        },
        colour => {
            validate => qr/^(?:red|blue|green)$/i
        },
        teeth => {
            required => 1,
            validate => $self->valid('nznumber')
        }
    );
}

sub approximate_blueness {
    my $self = shift;
    my $s = $self->table->select_by_key($self->param("sprocket_id"));
    $self->render_plaintext(
        $s && $s->is_red ? "not blue" : "maybe blue"
    );
}

1;
