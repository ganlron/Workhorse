package Workhorse::Functions::QCommand;

use strict;
use Carp;
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::QCommand

=head2 DESCRIPTION

Allows commands on the mail queue

=head1 METHODS

=cut

=head2 new

  Constructor

=cut

my %fields = (
	name => 'qcommand',
	groupchat => undef,
	chat => undef,
);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {_permitted => \%fields, %fields};
	bless ($self, $class);
	$self->{chat} = \&_do_qcommand;
	return $self;
}

sub _do_qcommand {
	my ($connection,$message) = @_;
	return 0 unless ($connection && $message);

	my $reply = $message->make_reply;
	my $response;
	#system('exiqgrep -i -r '.$domain.' | xargs -L 10 exim -M &');
	if ($message->any_body =~ m/\bretry\s+delivery\s+for\s+([^\s]+)/i) {
		my $dom = lc($1);
		$response = 'Attempting resend of queued messages to '.$dom.".  This may take some time.";
		system('/usr/local/sbin/exiqgrep -i -r '.$dom.' | /usr/bin/xargs -L 10 /usr/local/sbin/exim -M &');
	} elsif ($message->any_body =~ m/\bpurge\s+queued\s+mail\s+for\s+([^\s]+)/i) {
		my $dom = lc($1);
		$response = 'Purging queued mail for '.$dom.'.  This may take a minute.';
		system('/usr/local/sbin/exiqgrep -i -r '.$dom.' | /usr/bin/xargs -L 10 sudo /usr/local/sbin/exim -Mrm &');
	}
	if ($response) {
		$reply->add_body($response);
		$reply->send;
		return 1;
	}

	return 0
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
