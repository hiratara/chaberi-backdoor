use utf8;
use strict;
use warnings;
use Amon2::Lite;

__PACKAGE__->load_plugins('Web::JSON');

sub members() {
    my @members = map { {
        is_owner => '',
        status => (rand() < .2 ? 'なんか中' : ''),
        name => 'テスト' . int(rand(100) + 1),
    } } 1 .. int(rand(20) + 1);

    $members[rand() * @members]{is_owner} = 1;
    return \@members;
}

get '/' => sub {
    my $c = shift;

    my @rooms = map { {
        room_status => {
            members => members,
            advertising => (rand() < .2 ? '広告あり' : undef),
        },
        room_id => $_,
    } } $c->request->param('room');

    $c->render_json(\@rooms);
};

__PACKAGE__->to_app();
