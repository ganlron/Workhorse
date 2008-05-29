package Workhorse;

use strict;
use Carp;
use utf8;
our $AUTOLOAD;

use Module::Find;
use Config::Merge;
use AnyEvent;
use Net::XMPP2::IM::Connection;
use Net::XMPP2::Ext::Disco;
use Net::XMPP2::Ext::MUC;
use Net::XMPP2::Ext::Version;
use Sys::Syslog qw(:DEFAULT setlogsock);
our $Config = Config::Merge->new('/usr/local/workhorse/config');
my @Loaded = usesub Workhorse;

my %fields = (
    config        => $Config,
	connection	  => undef,
	type		  => 'client',
);

my $j = AnyEvent->condvar;

=head1 NAME

Workhorse

=head1 DESCRIPTION

Worker daemon, initializes methods to access classes.

=head1 METHODS

=cut

=head2 new

 Creation Method

=cut

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $self  = {_permitted => \%fields, %fields};
        bless ($self, $class);
        return $self;
}

=head2 start_connection

	Starts connection and registers it to the library.

=cut

sub start_connection {
	my $self = shift;
	my $users = $self->{config}->('users');
	
	setlogsock('unix');
	openlog('workhorse', 'pid', $self->{config}->('global.daemon.client_syslog_facility'));
	$self->{connection} = Net::XMPP2::IM::Connection->new(
		jid => $self->{config}->('global.jabber.jid'),
		resource => $self->{config}->('global.jabber.resource'),
		password => $self->{config}->('global.jabber.password'),
		initial_presence => 1,
	);
	my $disco = Net::XMPP2::Ext::Disco->new;
	$self->{connection}->add_extension( $disco );
	
	$self->{connection}->reg_cb (
		session_ready => sub {
			my ($con) = @_;
			syslog('notice', 'Connected as ' . $con->jid);
			$self->_join_muc($disco);
		},
		error => sub {
			my ($con, $error) = @_;
			syslog('error', $error->string);
		},
		disconnect => sub {
			my ($con, $h, $p, $reason) = @_;
			syslog('notice', "Disconnected from $h:$p: $reason");
			$j->broadcast;
		},
		contact_request_subscribe => sub {
			my ($con, $roster, $contact) = @_;
			if (defined $users->{$self->_get_user_from_jid($contact->jid)}->{allowed}) {
				syslog('notice', 'Subscribe request from '.$contact->jid);
				$contact->send_subscribed;
				$contact->send_subscribe;
			}
		},
		contact_did_unsubscribe => sub {
			my ($con, $roster, $contact) = @_;
			$contact->send_unsubscribe;
		},
		contact_unsubscribed => sub {
			my ($con, $roster, $contact) = @_;
			$contact->send_unsubscribed;
		},
		message => sub {
			my ($con, $msg) = @_;
			if ($msg->any_body) {
				if (defined $users->{$self->_get_user_from_jid($msg->from)}->{allowed}) {
						$self->_handle_message($con, $msg);
				}
			}
		}
	);
	$self->{connection}->connect();
	$j->wait(1);
	closelog();
}

sub _join_muc {
	my ($self,$disco) = @_;
	
	my $muc = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $self->{connection});
	$self->{connection}->add_extension( $muc );
	
	my $channels = $self->{config}->('global.jabber.channels');
	setlogsock('unix');
	openlog('workhorse', 'pid', $self->{config}->('global.daemon.client_syslog_facility'));
	for my $channel (keys %{$channels}) {
		syslog('notice','Joining channel: '.$channel);
		$muc->join_room ($channel, $channels->{$channel}->{nick}, sub {
			my ($rhdl, $me, $err) = @_;
			if ($err) {
				syslog('error','Could not join '.$channel.': '.$err->string);
			} else {
				syslog('notice','Successfully joined channel: '.$channel);
				$rhdl->reg_cb (
					message => sub {
						my ($rhdl, $msg, $is_echo) = @_;
						return if $is_echo;
						return if $msg->is_delayed;
						$self->_handle_group_message($msg);
					}
				);
			}
		}, password => $channels->{$channel}->{password} );
	}
	closelog();
}

sub _handle_message {
	my ($self,$con,$msg) = @_;
	return 0 unless $msg->any_body;
	# Log that we've received a message
	setlogsock('unix');
	openlog('workhorse', 'pid', $self->{config}->('global.daemon.client_syslog_facility'));
	syslog('notice','Direct message received from '.$msg->from.': '.$msg->any_body);
	my $handler = Workhorse::Handlers->new($con,$msg);
	if ($handler->handle_message()) {
		syslog('notice','Message handled');
	} else {
		syslog('notice','Message ignored');
	}
	closelog();
}

sub _handle_group_message {
	my ($self,$msg) = @_;
	return 0 unless $msg->any_body;
	setlogsock('unix');
	openlog('workhorse', 'pid', $self->{config}->('global.daemon.client_syslog_facility'));
	syslog('notice','Group '.$msg->room->jid.' message received from '.$msg->from.': '.$msg->any_body);
	my $handler = Workhorse::Handlers->new($self->{connection},$msg);
	if ($handler->handle_group_message()) {
		syslog('notice','Message handled');
	} else {
		syslog('notice','Message ignored');
	}
	closelog();
}

sub _get_user_from_jid {
	my ($self, $jid) = @_;
	return 'anonymous' unless $jid;
	my $domain = $self->{config}->('global.jabber.domain');
	if ($jid =~ m/^([^\@]+)\@$domain/i) {
		return lc($1);
	} else {
		return 'anonymous';
	}
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
