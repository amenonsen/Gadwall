package Mojolicious::Plugin::GadwallHelpers;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::ByteStream 'b';
use Gadwall::Util;

sub register {
    my ($self, $app) = @_;

    $app->helper(
        post_form => sub {
            my $c = shift;
            my @url = (shift);
            push @url, shift if ref $_[0] eq 'HASH';

            my $token = $c->session('token');
            unless ($token) {
                $c->session(token => Gadwall::Util->csrf_token());
            }

            if (ref $_[-1] eq 'CODE') {
                my $cb = pop @_;
                push @_, sub {
                    return "\n" . $self->_tag(
                        'input', name => "__token", type => "hidden",
                        value => $c->session('token')
                    ).$cb->();
                };
            }

            return $self->_tag(
                'form', method => "post", action => $c->url_for(@url), @_
            );
        }
    );
}

# Copied verbatim from Mojolicious::Plugin::TagHelpers, because that
# is still marked EXPERIMENTAL. Otherwise I could have tried calling
# $c->app->renderer->helpers->{tag}->() myself.

sub _tag {
  my $self = shift;
  my $name = shift;

  # Callback
  my $cb = defined $_[-1] && ref($_[-1]) eq 'CODE' ? pop @_ : undef;
  pop if @_ % 2;

  # Tag
  my $tag = "<$name";

  # Attributes
  my %attrs = @_;
  for my $key (sort keys %attrs) {
    my $value = $attrs{$key};
    $tag .= qq/ $key="$value"/;
  }

  # Block
  if ($cb) {
    $tag .= '>';
    $tag .= $cb->();
    $tag .= "<\/$name>";
  }

  # Empty element
  else { $tag .= ' />' }

  # Prevent escaping
  return b($tag);
}

1;
