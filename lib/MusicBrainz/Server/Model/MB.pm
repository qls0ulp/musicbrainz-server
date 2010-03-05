package MusicBrainz::Server::Model::MB;
use Moose;
extends 'Catalyst::Model';

use Module::Pluggable::Object;
use MusicBrainz::Server::Context;

has 'context' => (
    isa        => 'MusicBrainz::Server::Context',
    is         => 'rw',
    lazy_build => 1,
    handles    => [qw( cache dbh raw_dbh )] # XXX Hack - Model::Feeds should be in Data
);

sub _build_context {
    my $self = shift;


    if (DBDefs::_RUNNING_TESTS()) {
        require MusicBrainz::Server::Test;
        return MusicBrainz::Server::Test->create_test_context;
    }
    else {
        my $cache_opts = &DBDefs::CACHE_MANAGER_OPTIONS;
        return MusicBrainz::Server::Context->new(
            cache_manager => MusicBrainz::Server::CacheManager->new($cache_opts)
        );
    }
}

sub models {
    my @models;

    my @exclude = qw( Alias );
    my $searcher = Module::Pluggable::Object->new(
        search_path => 'MusicBrainz::Server::Data',
        except      => [ map { "MusicBrainz::Server::Data::$_" } @exclude ]
    );

    for my $model (sort $searcher->plugins) {
        my $model_name = $model;
        next if $model_name =~ /Data::Role/;
        $model_name =~ s/.*::Data:://;

        push @models, [ $model_name, "MusicBrainz::Server::Model::$model_name" ];
    }

    push @models, 'MusicBrainz::Server::Email';

    return @models;
}

sub BUILD {
    my ($self, $args) = @_;
    my $class = 'MusicBrainz::Server::Model';

    for my $model ($self->models) {
        Class::MOP::Class->create(
            $model->[1] =>
                methods => {
                    ACCEPT_CONTEXT => sub {
                        return $self->data_object($model->[0]);
                    }
                });
    }
}

sub expand_modules {
    my $self = shift;
    return map { $_->[1] } $self->models;
}

sub data_object {
    my ($self, $model) = @_;
    my $class = "MusicBrainz::Server::Data::$model";
    Class::MOP::load_class($class);

    return $class->new( c => $self->context );
}

1;
