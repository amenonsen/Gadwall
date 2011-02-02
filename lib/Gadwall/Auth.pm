# This controller handles user authentication, and provides login/logout
# actions. The login form can be changed by overriding the built-in data
# template "auth/login.html.ep" with a real file.

package Gadwall::Auth;

use strict;
use warnings;

use base 'Gadwall::Controller';

# This function makes sure that there is an (already validated) session
# cookie that identifies a user. If so, that user is known to have made
# the request. If not, access to anything protected by this function is
# denied until the user logs in (see below).
#
# To require authentication to access /foo, you can do this:
#
# $auth = $r->bridge->to('auth#check')
# $auth->route('/foo')->to(...)

sub check {
    my $self = shift;

    my $user = $self->session('user');
    if ($user) {
        my $u = $self->new_controller('Users')->select_by_key($user);
        if ($u) {
            $self->stash(user => $u);
            return 1;
        }
    }

    my $source = $self->req->url;
    if ($source eq $self->url_for('logout')) {
        $source = "/";
    }

    $self->render(
        status => 403,
        template => "auth/login",
        login => "", source => $source,
        template_class => __PACKAGE__
    );

    return 0;
}

# This function takes a username and password and, if the password is
# valid for the named user, issues a signed cookie that will pass the
# check above. If not, it displays the login form and an error. This
# action itself must be reachable without authentication to avoid an
# infinite loop.
#
# $r->route('/login')->via('post')->to('auth#login')

sub login {
    my $self = shift;

    my ($login, $passwd);
    if ($self->req->method eq 'POST') {
        $login = $self->param("__login");
        $passwd = $self->param("__passwd");
    }
    my $source = $self->param("__source") || '/';

    if ($login && $passwd) {
        my $u = $self->new_controller('Users')->select_one(
            "select * from users where ".
            "coalesce(login,email)=? and is_active", $login
        );
        if ($u && $u->has_password($passwd)) {
            $self->session(user => $u->{user_id});
            $self->redirect_to($source)->render_text(
                "Redirecting to $source", format => 'txt'
            );
            return;
        }
    }

    $self->render(
        login => $login, source => $source,
        errmsg => "Incorrect username or password",
        template_class => __PACKAGE__
    );
}

# This function revokes the cookie issued by login.

sub logout {
    my $self = shift;

    $self->session(expires => 1);
    $self->render(
        template => "auth/login",
        login => "", source => "/",
        errmsg => "You have been logged out",
        template_class => __PACKAGE__
    );
}

1;

__DATA__

@@ auth/login.html.ep
% layout 'default', title => "Login";
<%= form_for login => (method => 'post', class => 'login') => begin %>
  <%= hidden_field '__source' => stash 'source' %>
  <label for="__login">Login:</label><br>
  <%= text_field '__login', value => stash 'login' %><br>
  <label for="__passwd">Password:</label><br>
  <%= password_field '__passwd' %><br>
  <%= submit_button 'Login', class => 'submit' %>
<% end %>
% if (stash 'errmsg') {
<p id=msg class=error>
<%= stash 'errmsg' %>
</p>
% }
