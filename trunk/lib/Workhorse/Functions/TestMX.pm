package Workhorse::Functions::TestMX;

use strict;
use Carp;
use Net::DNS;
use Net::SMTP;
our $VERSION = "0.01";
our $AUTOLOAD;

=head1 NAME

Workhorse::Functions::TestMX

=head2 DESCRIPTION

Tests the ability to connect to a hosts MX records and replies

=head1 METHODS

=cut

=head2 new

  Constructor

=cut

our $NAME = 'testmx';
our $DESCRIPTION = 'Tests the ability to connect to a host\'s MX records and replies';

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
	$self->{chat} = \&_return_test;
	return $self;
}

sub _return_test {
	my ($connection,$message) = @_;
	return 0 unless ($connection && $message);

	if ($message->any_body =~ m/^testmx\s+([^\s\?]+)/i) {
		my $domain = $1;
		my $response = "Test Results For: ".$domain."\n\n";

		my @mx = mx($domain);

		my $good = 0;

		if (@mx) {
			foreach my $mx (@mx) {
				my $smtp = Net::SMTP->new($mx->exchange, Hello => 'localhost', Timeout => 10);
				$response .= $mx->exchange.' = ';
				if ($smtp) {
					$response .= "OK\n";
					$good = 1;
					if ($message->body =~ m/with\s+(?:banner|detail)/) {
						$response .= $smtp->banner."\n";
					}
				} else {
					$response .= "NOT OK\n";
				}
			}
		} else {
			$response .= "No MX Records found\n";
		}

		if ($good) {
			$response .= "\nDomain can receive mail\n";
		} else {
			$response .= "\nDomain CAN NOT receive mail\n";
		}

		my $reply = $message->make_reply;
		$reply->add_body($response);
		$reply->send;
		return 1;
	}

	return 0;
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
