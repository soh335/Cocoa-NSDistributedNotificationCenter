package Cocoa::NSDistributedNotificationCenter;
use strict;
use warnings;
use XSLoader;
use Carp;

our $VERSION = '0.01';

XSLoader::load __PACKAGE__, $VERSION;

sub new {
    my ($class) = @_;
    my $self = bless { listener => {} }, $class;
    _set_up($self);
    $self;
}

sub listen {
    my ($self, $name, $cb) = @_;

    unless ( $self->{listener}->{$name} ) {
        _add_listener($self, $name);
    }

    $self->{listener}->{$name} = $cb;
}

sub _fire {
    my ($self, $name, $user_info) = @_;

    my $cb = $self->{listener}->{$name}
        or croak("$name is not listen");

    $cb->($user_info);
}

sub DESTROY {
    my ($self) = @_;
    _destroy($self);
    $self->SUPER::DESTROY;
}

1;

__END__

=head1 NAME

Cocoa::NSDistributedNotificationCenter - Perl interface for NSDistributedNotificationCenter

=head1 SYNOPSIS

  use Cocoa::NSDistributedNotificationCenter;
  use Cocoa::EventLoop;

  my $ns_center = Cocoa::NSDistributedNotificationCenter->new;
  $ns_center->listen('com.apple.iTunes.playerInfo', sub {
      my $info = shift;
      warn $info->{Artist};
  });

  Cocoa::EventLoop->run;
