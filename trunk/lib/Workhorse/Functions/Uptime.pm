package Workhorse::Functions::Uptime;

use strict;
use Carp;
our $VERSION = "0.01";
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::Uptime

=head2 DESCRIPTION

Replies to 'uptime' with system uptime

=head1 METHODS

=cut

=head2 new

  Constructor

=cut

our $NAME = 'uptime';
our $DESCRIPTION = 'Replies with system uptime';

my %fields = (
	name => $NAME,
	groupchat => undef,
	chat => undef,
);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {_permitted => \%fields, %fields};
	bless ($self, $class);
	$self->{chat} = \&_return_uptime;
	$self->{groupchat} = \&_return_uptime;
	return $self;
}

sub _return_uptime {
	my ($connection,$message) = @_;
	return 0 unless ($connection && $message);
	return 0 unless ($message->any_body =~ m/^uptime$/i);
	my $reply = $message->make_reply;
	my $uptime = `uptime`;
	$reply->add_body($uptime);
	$reply->send;
	return 1;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) or croak "$self is not an object";
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    unless (exists $self->{_permitted}->{$name} ) {
        croak "Can't access `$name' field in class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    } else {
        return $self->{$name};
    }
}

sub DESTROY {
	
}

=head1 AUTHOR

Created by Derek on 2007-08-07.
Copyright (c) 2007 Compu-SOLVE Technologies, Inc. All rights reserved.

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;