package Gadwall::Dequeue::Mail;

use Mojo::Base 'Gadwall::Dequeue::Base';

use Gadwall::Util 'mail';

sub process {
    my ($self, $data, $job) = @_;
    my ($qid, $tag, $json) = @$job{qw/queue_id tag data/};

    eval {
        unless (mail(%$data)) {
            die $@;
        }
    } or do {
        $self->app->log->error("Mail job #$qid failed: $@");
    }
}

1;
