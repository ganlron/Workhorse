package Workhorse::Functions::QSumm;

use strict;
use Carp;
our $VERSION = "0.01";
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::QSumm

=head2 DESCRIPTION

Allows queries to the queue summary

=head1 METHODS

=cut

=head2 new

  Constructor

=cut

our $NAME = 'qsumm';
our $DESCRIPTION = 'Allows queries to the queue summary';

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
	$self->{chat} = \&_return_info;
	return $self;
}

sub _return_info {
	my ($connection,$message) = @_;
	return 0 unless ($connection && $message);
	my $qsumm = `/usr/bin/mailq | /usr/local/sbin/exiqsumm`;
	my %queue_data = ();
	my %time_vals = (
		d => 'days',
		h => 'hours',
		m => 'minutes',
		s => 'seconds',
	);
	foreach my $line ((split(/\n/,$qsumm))) {
		if ($line =~ m/([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+TOTAL/) {
			$queue_data{total}{number} = $1;
			$queue_data{total}{size} = $2;
			$queue_data{total}{oldest} = $3;
			$queue_data{total}{newest} = $4;
		} elsif ($line =~ m/(\d+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(.+)$/) {
			$queue_data{lc($5)}{number} = $1;
			$queue_data{lc($5)}{size} = $2;
			$queue_data{lc($5)}{oldest} = $3;
			$queue_data{lc($5)}{newest} = $4;
		}
	}
	
	my $reply = $message->make_reply;
	my $response;
	if ($message->any_body =~ m/^qsumm$/i) {
		$response = $qsumm;
	} elsif ($message->any_body =~ m/^qsumm\s+([\w\.\-]+)$/i) {
		$response = 'There is no mail queued for '.lc($1);
		if ($queue_data{lc($1)}) {
			$response = 'Yes, there are '.$queue_data{lc($1)}{number}.' messages queued for '.lc($1).' totalling '.$queue_data{lc($1)}{size};
		}
	} elsif ($message->any_body =~ m/^qsumm total$/i) {
		$response = 'There is a total of '.$queue_data{total}{number}.' ('.$queue_data{total}{size}.') messages queued';
	} elsif ($message->any_body =~ m/^qsumm when\s+([^\s\?]+)/i) {
		my $dom = $1;
		$response = "Sorry, I can't answer that for $dom\n";
		if ($queue_data{lc($dom)}) {
			my $age = 0;
			my $oldest = $queue_data{lc($1)}{oldest};
			if ($oldest =~ m/^(\d+)(d|h|m|s)/i) {
				$age = $1.' '.$time_vals{$2};
			}
			$response = 'Mail for '.lc($dom).' has been queueing for '.$age;
		}
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
